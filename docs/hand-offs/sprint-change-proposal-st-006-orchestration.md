# Sprint Change Proposal — Missing Orchestration Entrypoint for DiagramTool

## 1. Identified Issue Summary

**Trigger**  
- A **post–ST-003 code review** of `MALIB.Util.DiagramTool` compared against the PRD and existing stories.

**Observed Problem**  
- The PRD v4 promises an end-to-end flow:
  - Input: **session selector string** (single IDs, ranges, lists), and
  - Output: **one Mermaid `sequenceDiagram` per SessionId**, combined text returned, echoed to terminal, and optionally **appended to a file with a divider** and deduplication.
- Current implementation and stories provide strong **internal capabilities**:
  - ST-001: `ParseSessionSpec` — parses the selector string into SessionIds (Done).
  - ST-002: `LoadHeadersForSession` — per-session SQL loader with deterministic ordering (Done).
  - ST-003: `CorrelateEvents` + helpers — request/response correlation and arrow semantics (Done).
  - ST-004: Loop detection (Draft; algorithmic grouping only).
  - ST-005: Output/dedup/labeling/warnings (Draft; output semantics only).
- **Gap:** There is **no public entrypoint / orchestration method** that:
  - Accepts the session selector and runtime options (labelMode, dedup, optional output file path),
  - Iterates SessionIds, calls ST-001..ST-003 (and later ST-004/ST-005),
  - Assembles per-session diagrams, applies dedup, and enforces the append-only output contract,
  - Returns combined text and %Status for callers.

**Classification**  
- Primarily a **planning/decomposition gap**:
  - A PRD-level requirement (“generate diagrams from a session selector string with dedup + append-only output”) was **not captured as an explicit story**.
  - Not a technical dead-end; existing components are aligned with the PRD.

**Impact (initial)**  
- If left unaddressed:
  - The MVP could ship with **all internal pieces present** but **no usable API** for consumers to actually generate diagrams.
  - FR-09, FR-10, and FR-11 would be only **partially fulfilled** in practice.
- Risk level:
  - **Medium** to MVP completeness (feature gap),
  - **Low** to existing code (no need for rollback; we are adding orchestration rather than undoing internals).

---

## 2. Epic Impact Summary

**Current Epic Shape**  
- Epic goal (implicit from PRD): `MALIB.Util.DiagramTool` should be a **library that takes a session selector string and produces Mermaid diagrams** with dedup + append‑only output.
- Stories:
  - ST-001 — Session Spec Parsing (Done): input parsing only.
  - ST-002 — Data Load & Deterministic Ordering (Done): per-session loader.
  - ST-003 — Correlation Rules (Done): pairing and arrow semantics.
  - ST-004 — Loop Detection (Draft): compress contiguous identical request/response pairs.
  - ST-005 — Output & Dedup (Draft): labeling, warnings as `%%`, dedup, append-only/divider.

**Epic Viability**  
- All existing stories remain **valid and useful slices** of the epic.
- However, **none of them explicitly own** the orchestration/public entrypoint described in the PRD.
- The epic **does not need to be abandoned or fundamentally redefined**; it requires a **refinement**:
  - Add a dedicated story for orchestration and public API.

**Decision on Handling Within the Epic**  
- We considered:
  - **Option A:** Expand ST-005 to own orchestration + public entrypoint.
  - **Option B:** Add a new story, **ST-006 — Orchestration & Public Entry API**, keeping ST-004 and ST-005 focused on their algorithmic/output concerns.
- **Chosen path:** **Option B — new ST-006**, with the intent that:
  - ST-006 defines a stable, public API (e.g. `GenerateDiagrams(...)`) and wires ST-001..ST-005 together.
  - ST-006 can be implemented **before ST-004 and ST-005** to de‑risk the end‑to‑end shape, with those later stories enriching behavior without changing the signature.

**Epic Impact Summary (one‑liner)**  
> The DiagramTool MVP epic remains valid, but it is missing an explicit orchestration/public entrypoint slice. All existing stories (ST-001..ST-005) stay in place; we will add ST-006 to provide the promised end‑to‑end API, scheduled ahead of ST-004 and ST-005.

---

## 3. Artifact Adjustment Needs

**New Artifact**  
1. **New story:** `docs/stories/story-006-orchestration-and-entrypoint.md` (name tentative)
   - Purpose: Define **ST-006 — Orchestration & Public Entry API**.
   - Core contract (for the dev agent):
     ```objectscript
     ClassMethod GenerateDiagrams(
       pSelector  As %String,              // session spec: "1,5-9,12"
       pOutFile   As %String = "",        // optional file path (append-only)
       pLabelMode As %String = "full",    // "full" | "short"
       pDedupOn   As %Boolean = 1,         // default ON
       Output pText As %String
     ) As %Status
     ```
   - Responsibilities:
     - Orchestrate ST-001..ST-003 immediately (parse → load → correlate).
     - Define hooks/flow points where ST-004 (loop detection) and ST-005 (output/dedup/labels/warnings) plug in as they are implemented.
     - Ensure behavior aligns with FR-09, FR-10, FR-11 and related ACs.

**Updated Artifacts (light edits)**  
2. **Architecture overview:** `docs/architecture.md`
   - Add a brief note in the System Context or Key Decisions sections:
     - That `MALIB.Util.DiagramTool` exposes a **single primary orchestration method** (`GenerateDiagrams(...)`) that:
       - Accepts a session selector string + runtime options, and
       - Produces per-session diagrams with append-only file output and dedup as per PRD.
   - Optionally include a small sequence or flow description for this entrypoint.

3. **Story ST-005 — Output & Dedup:** `docs/stories/story-005-output-and-dedup.md`
   - Optional but recommended clarifications:
     - Under **Dependencies** or **Scope**, reference that ST-005’s behavior is **invoked from the ST-006 orchestration method**, rather than acting as the public API itself.
     - This keeps ST-005 scoped to **output semantics** while ST-006 owns **orchestration**.

**Artifacts Not Requiring Change (for this proposal)**  
- **PRD main and shards** (`docs/prd.md`, `docs/prd/20-functional-requirements.md`, etc.):
  - Already describe the end-to-end behavior (selector → diagrams, append-only output, dedup) but do not conflict with adding ST-006.
  - We may later add a short note referencing `GenerateDiagrams(...)`, but this is **optional polish**, not required for correctness.
- **Existing Done stories** (ST-001, ST-002, ST-003):
  - Contracts and QA gates remain correct; no edits required.

---

## 4. Recommended Path Forward

**Preferred Option:** Direct adjustment via new story ST-006 (no rollback, no PRD v2)

- Adopt **Option B** from the epic analysis: introduce **ST-006 — Orchestration & Public Entry API** as a new story in the existing DiagramTool MVP epic.
- Treat ST-006 as the **single orchestration slice** that exposes a stable public API and wires together ST-001..ST-005.
- Schedule ST-006 **before ST-004 and ST-005** so that:
  - The end-to-end flow shape (selector → diagrams → output) is validated early.
  - Loop detection (ST-004) and output/dedup specifics (ST-005) enrich a solid pipeline rather than define it.

**Non-Selected Options (for record)**

- **Option A — Expand ST-005 to own orchestration + public entrypoint:**
  - Rejected to avoid overloading ST-005 with both orchestration and output semantics.
  - Keeping orchestration in a separate ST-006 improves clarity and testability.
- **Option C — Re-scope MVP / PRD v2:**
  - Rejected as unnecessary; the PRD’s expectations remain achievable with a small story addition.

**Risk and Trade-off Summary**

- **Pros:**
  - Minimal change footprint in existing artifacts.
  - Clear, documented public contract for consumers and for dev/QA.
  - Allows earlier discovery of integration issues between ST-001..ST-003.
- **Cons:**
  - Adds one more story (ST-006) to manage and track.
  - Requires coordination so ST-004/ST-005 do not attempt to redefine the public API.

---

## 5. PRD MVP Impact & High-Level Action Plan

### 5.1 PRD MVP Impact

- **Scope:**
  - The PRD’s functional scope (FR-09 Per-Session Diagram Generation, FR-10 Multi-Session Deduplication, FR-11 Output Contract) remains unchanged.
  - ST-006 exists primarily to **explicitly realize** the already-documented behavior via a concrete public method.
- **Documentation:**
  - No mandatory changes to PRD text. Optional enhancement:
    - Add a short implementation note or reference in PRD shards (e.g., in 20-functional-requirements.md or 40-data-sources-and-mapping.md) naming `GenerateDiagrams(...)` as the primary entrypoint.
- **Timeline & Risk:**
  - Slight increase in documentation and story-writing work.
  - Net reduction in delivery risk by clarifying orchestration responsibilities early.

### 5.2 High-Level Action Plan

**Step 1 — Story Creation (PO/SM)**
- Create and approve **ST-006 — Orchestration & Public Entry API** in `docs/stories/story-006-orchestration-and-entrypoint.md`.
- Define:
  - Story narrative, business value, and scope.
  - Explicit method contract for `GenerateDiagrams(...)`.
  - Dependencies on ST-001..ST-005.
  - Acceptance criteria aligned with FR-09, FR-10, FR-11 and key ACs (per-session structure, dedup behavior, append-only output, warnings surfaced).

**Step 2 — Architecture & Story Cross-References (Arch/SM)**
- Update `docs/architecture.md` to reference the orchestration entrypoint.
- Optionally update ST-005 to mention that its behavior is invoked by ST-006.

**Step 3 — Implementation (Dev)**
- Implement `GenerateDiagrams(...)` in `MALIB.Util.DiagramTool` with the agreed signature:
  ```objectscript
  ClassMethod GenerateDiagrams(
    pSelector  As %String,
    pOutFile   As %String = "",
    pLabelMode As %String = "full",
    pDedupOn   As %Boolean = 1,
    Output pText As %String
  ) As %Status
  ```
- Responsibilities for this method:
  - Parse the selector using `ParseSessionSpec` (ST-001).
  - For each SessionId:
    - Load rows via `LoadHeadersForSession` (ST-002).
    - Correlate events via `CorrelateEvents` (ST-003).
    - Call internal hooks for loop detection (ST-004) and output/dedup/labeling/warnings (ST-005) when available.
  - Assemble per-session diagrams, apply multi-session dedup according to PRD defaults, and honor append-only file output.
  - Return combined text in `pText` and a %Status suitable for programmatic callers.
- Initially, ST-006 may:
  - Implement a **minimal, working pipeline** using ST-001..ST-003 and simple per-session output (even before full loop/dedup behavior is present).
  - Provide stable extension points for ST-004/ST-005 without changing the public signature.

**Step 4 — Testing & QA (Dev/QA)**
- Add %UnitTest coverage for ST-006:
  - End-to-end tests for simple single-session and multi-session scenarios.
  - Verify that `GenerateDiagrams(...)` wires together parsing, loading, and correlation correctly.
  - Once ST-004/ST-005 are implemented, extend tests to cover loops, dedup, and append-only file behavior.
- Create a QA gate file for ST-006 (e.g., `docs/qa/gates/st.006-orchestration-entrypoint.yml`) mapping tests back to PRD ACs.

---

## 6. Agent Handoff Plan & Next Steps

### 6.1 Handoff to Product Owner / Scrum Master

- **Owner:** PO/SM
- **Actions:**
  - Finalize the wording and scope of **ST-006** in a new story document.
  - Prioritize ST-006 **ahead of ST-004 and ST-005** in the backlog.
  - Ensure ST-004 and ST-005 explicitly reference ST-006 as the caller/orchestrator where appropriate.

### 6.2 Handoff to Architecture

- **Owner:** Architect
- **Actions:**
  - Update `docs/architecture.md` to:
    - Include `GenerateDiagrams(...)` in the system context description as the primary orchestration method.
    - Optionally, add a short call-flow diagram or bullet list showing how ST-001..ST-005 are wired together.

### 6.3 Handoff to Development

- **Owner:** Dev Agent
- **Actions:**
  - Implement `GenerateDiagrams(...)` according to the ST-006 contract.
  - Ensure no changes are required to the public signature when ST-004/ST-005 are implemented; use internal helper methods for loop detection and output/dedup logic.
  - Add or extend unit tests in `src/MALIB/Test/DiagramToolTest.cls` to cover the orchestration path.

### 6.4 Handoff to QA

- **Owner:** QA
- **Actions:**
  - Define a QA gate for ST-006 and ensure traceability to PRD ACs (especially FR-09/10/11-related ACs).
  - Validate end-to-end behavior once ST-006 is implemented and again after ST-004/ST-005 land.

### 6.5 Validation & Rollback Considerations

- If ST-006 implementation reveals deeper design problems (e.g., orchestration signature needs adjustment), preferred approach is:
  - Iterate on ST-006 story and architecture docs first.
  - Avoid rolling back ST-001..ST-003 unless a fundamental requirement change is discovered (not currently anticipated).
- Success criteria for this change:
  - A clearly documented and implemented `GenerateDiagrams(...)` method.
  - Stories and architecture updated to reflect that orchestration exists as a first-class slice.
  - PRD FR-09/10/11 can be traced directly to tests and behavior in ST-006.
