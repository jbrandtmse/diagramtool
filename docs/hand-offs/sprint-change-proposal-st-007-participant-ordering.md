# Sprint Change Proposal — Participant Ordering by First Appearance

## 1. Identified Issue Summary

**Trigger**  
- After **ST-005 — Output & Dedup** was implemented and marked Done (with tests passing), the DiagramTool was manually run on another IRIS server and the rendered diagrams were inspected.

**Observed Problem**  
- In the generated diagrams, **participant declarations are sorted alphabetically**.
- However, PRD v4 shard **50 Diagramming Rules** already states:
  - “Source of truth: first appearance of `SourceConfigName` and `TargetConfigName` in ordered rows”
  - “Declaration order: order-of-first-appearance in the session”
- The current implementation and tests for ST-005 **do not enforce or validate** this rule; participant ordering is effectively alphabetical rather than **order-of-first-appearance**.

**Classification**  
- The user has explicitly classified this as:
  - **Newly discovered requirement (B)** from a process perspective — this behavior was not previously called out as an explicit AC or story requirement for ST-005.
- From a documentation perspective:
  - The PRD already contains the rule; the gap is that **ST-005 did not elevate it into its story scope and test plan**.

**Impact (initial)**  
- **Scope:** Localized to **diagram output semantics**, specifically:
  - The order in which `participant` lines are declared at the top of the diagram.
  - Any consumer (including the upcoming ST-006 orchestration) that relies on intuitive, temporal participant ordering.
- **Consequences if unaddressed:**
  - Diagrams remain mostly correct for **messages, arrows, warnings, and dedup**, but participants will not reflect **temporal order-of-first-use**.
  - This can make diagrams **harder to read and reason about**, especially when visually tracking flows as they appear in real execution.
- **Evidence:**
  - Manual inspection of sample diagrams on a second server; no explicit failing %UnitTest because **participant ordering rules were not encoded** in ST-005 test cases.

---

## 2. Epic Impact Summary

**Current Epic Shape (DiagramTool MVP)**  
- Epic intent: `MALIB.Util.DiagramTool` provides a **library that takes a session selector string and produces one Mermaid `sequenceDiagram` per session**, with:
  - Correct **participant declarations** and labels,
  - Proper **arrows, loops, warnings**,
  - **Deduplication** of identical diagrams,
  - **Append-only** output contract.
- Existing stories (simplified):
  - **ST-001** — Session Spec Parsing: parse selector string into SessionIds.
  - **ST-002** — Data Load & Deterministic Ordering: ordered per-session events.
  - **ST-003** — Correlation Rules: request/response pairing, arrows, warnings.
  - **ST-004** — Loop Detection: compress contiguous identical request/response pairs.
  - **ST-005** — Output & Dedup: labels, warnings as `%%`, dedup, append-only.
  - **ST-006** — Orchestration & Public Entry API: `GenerateDiagrams(...)` (added via prior sprint change proposal).

**Epic Viability**  
- The epic **remains valid**:
  - PRD 50 Diagramming Rules already specifies the desired participant ordering.
  - Existing stories cover parsing, loading, correlation, loop detection, and output/dedup/orchestration.
- The gap:
  - **Participant declaration ordering** (order-of-first-appearance) is **not treated as a first-class, testable requirement** in ST-005 (and not yet in any subsequent story).
- Required adjustment:
  - Add a **small, focused follow-on story** that:
    - Explicitly encodes the PRD participant-ordering rule.
    - Adds acceptance criteria and tests around **order-of-first-appearance**.
    - Minimizes churn on already-gated ST-005.

**Decision on Handling Within the Epic**  
- Evaluated options:
  - **Option A:** Re-open ST-005 and extend its ACs for participant ordering.
  - **Option B:** Add a new follow-on story, ST-007, specifically for participant ordering.
- **Chosen path (user decision):**
  - **Option B — New follow-on story (ST-007) for participant-ordering.**
  - Rationale:
    - Keep ST-005 as Delivered against its then-current scope and QA gate.
    - Cleanly track “turning on” the PRD participant-ordering rule as a discrete, incremental enhancement.
    - Maintain clear traceability from this behavior back to PRD 50.

**Epic Impact Summary (one-liner)**  
> The DiagramTool MVP epic remains valid, but participant declaration ordering (order-of-first-appearance) must be elevated from a PRD rule into a tested, story-level requirement via a new ST-007, without re-opening ST-005.

---

## 3. Artifact Conflict & Impact Analysis

### 3.1 PRD

- **docs/prd/50-diagramming-rules.md** (PRD v4 shard — Diagramming Rules):
  - Already defines:
    - Source of truth: first appearance of `SourceConfigName` / `TargetConfigName`.
    - Declaration order: **order-of-first-appearance** in the session.
  - **No conflict**, but:
    - This rule is currently **under-enforced**; it is not present in story-level ACs/tests.
- **Change need:**
  - No mandatory PRD wording change.
  - Optional: later add a short **“Implementation Note”** referencing the specific story ST-007 that enforces this behavior.

### 3.2 Stories

- **ST-005 — Output & Dedup** (`docs/stories/story-005-output-and-dedup.md`):
  - Focuses on:
    - Labeling defaults and toggle,
    - Dedup behavior,
    - Append-only output with divider,
    - Warning emission and best-effort semantics.
  - It **does not explicitly state participant order-of-first-appearance** as an AC.
  - For clarity:
    - ST-005 can remain **unchanged** and treated as having delivered its scope.
    - ST-007 will **reference both ST-005 and PRD 50** as dependencies and refine the participant-declaration behavior.
- **New Story Required: ST-007 — Participant Ordering by First Appearance**
  - New story under `docs/stories/`, e.g.:
    - `docs/stories/story-007-participant-ordering-by-first-appearance.md`

### 3.3 Architecture

- **docs/architecture.md**:
  - Describes DiagramTool responsibilities and, with ST-006, the orchestration entrypoint.
  - It may already implicitly assume that participant declarations follow PRD 50 rules.
  - **Change need (optional/minimal):**
    - Add a short bullet under DiagramTool behavior noting that:
      - “Participants are declared in **order-of-first-appearance** in the ordered event stream (per PRD 50), enforced via ST-007.”

### 3.4 QA Artifacts

- **Existing QA gates:**
  - ST-005 already has a QA gate (`docs/qa/gates/st.005-output-and-dedup.yml`) that does **not** cover participant-ordering rules.
- **New QA gate recommended:**
  - `docs/qa/gates/st.007-participant-ordering.yml`
    - Will map new tests to PRD 50 participant rules and any added ACs in ST-007.
- **QA assessment:**
  - New QA assessment file is optional at creation time; can be added when designing test plan (e.g., `docs/qa/assessments/st.007-test-design-<date>.md`).

**Artifact Impact Summary**  
- **New artifacts:** ST-007 story, ST-007 QA gate (and optionally a QA assessment).
- **Light-touch updates:** Optional clarifications in `docs/architecture.md` and/or a short note in PRD 50 linking to ST-007.
- **No changes** required to ST-005’s story text or QA gate to treat it as Delivered.

---

## 4. Path Forward Evaluation

### Option 1 — Direct Adjustment via New Story (Chosen)

- **Approach:**
  - Add **ST-007 — Participant Ordering by First Appearance** as a small, focused story in the DiagramTool epic.
  - Implement participant declaration ordering in the core output pipeline (likely in `MALIB.Util.DiagramTool.Output` and/or the data structures that feed it).
  - Add unit tests asserting:
    - Participant declarations appear in **order-of-first-appearance** across multiple event patterns.
    - Determinism is maintained (same input rows → same participant order).
- **Effort & Risk:**
  - Effort: small-to-moderate (implementation + tests + QA gate).
  - Risk: low; the change is local to ordering logic and should be compatible with existing output semantics and ST-005 behavior.

### Option 2 — Rollback/Re-scope ST-005

- **Approach:**
  - Re-open ST-005, update its scope, and gate it on participant ordering.
- **Status: Not chosen.**
  - Would blur historical traceability; ST-005 already passed a well-documented QA gate.
  - Increases risk of re-litigating prior Done story scope.

### Option 3 — PRD MVP Re-scope

- **Approach:**
  - Downgrade participant-ordering to a “nice-to-have” in PRD, effectively allowing alphabetical ordering.
- **Status: Rejected.**
  - PRD 50 already treats order-of-first-appearance as part of the core diagramming rules.
  - From a UX/readability standpoint, this is a regression relative to intended behavior.

**Selected Recommended Path**  
> Proceed with **Option 1**: add ST-007 as a small, targeted enhancement story that explicitly encodes the PRD participant-ordering rule, leaving ST-005 as Delivered and avoiding any rollback.

---

## 5. PRD MVP Impact & High-Level Action Plan

### 5.1 PRD MVP Impact

- **Scope:**
  - No change to MVP feature set; this is an **alignment step** between implementation and an existing PRD rule.
- **Quality & UX:**
  - Once ST-007 is delivered, diagrams become more **intuitively readable**, matching temporal flows.
  - This strengthens NFR-02 (Determinism) and general usability of generated diagrams.
- **Timeline:**
  - Incremental impact; the change can be scheduled as a **short, focused follow-on** after ST-005 and ST-006.
  - Does not block other work unless downstream stakeholders require participant ordering before consuming diagrams.

### 5.2 High-Level Action Plan

#### Step 1 — Story Creation (PO/SM)

Create a new story, for example:

- **File:** `docs/stories/story-007-participant-ordering-by-first-appearance.md`  
- **Summary (suggested):**  
  - *As an IRIS developer reading sequence diagrams, I want participant declarations to follow the order of first appearance in the event stream, so that the diagrams reflect temporal flow and are easier to interpret.*
- **Business Value:**
  - Improves readability and correctness of diagrams relative to PRD 50.
- **Dependencies:**
  - ST-002 (ordered data),
  - ST-003 (correlated events),
  - ST-005 (output & dedup),
  - ST-006 (GenerateDiagrams orchestration).
- **Scope Highlights (suggested):**
  - Participant order:
    - Use **order-of-first-appearance** over the final correlated, ordered events within each session.
    - Maintain determinism across runs.
  - No changes to:
    - Message ordering,
    - LabelMode behavior,
    - Dedup semantics.
- **Acceptance Criteria (examples):**
  - Given a session with events that introduce participants A, B, C in that order:
    - Then the `participant` lines are declared in `[A, B, C]`, regardless of their lexicographic order.
  - Given multiple sessions with different first-use orders, each session’s participants are **independently ordered** by first appearance.
  - Participant order is deterministic even when there are ties in TimeCreated (tie-break rules as per PRD apply).

#### Step 2 — QA Gate and Test Design (QA/SM)

- Add a new gate: `docs/qa/gates/st.007-participant-ordering.yml` with:
  - Traceability to PRD 50 participant rules (section 2).
  - References to specific test IDs (e.g., `st.007-UNIT-001`..).
- Optional: Create a test design doc:
  - `docs/qa/assessments/st.007-test-design-YYYYMMDD.md` outlining:
    - Core unit test scenarios (single session, multiple sessions, ties, near-duplicates, interactions with loops/dedup).

#### Step 3 — Implementation Guidance (Dev)

- Implement the logic in the DiagramTool output pipeline so that:
  - For each session:
    - As correlated events are iterated in deterministic order, **track the first time each participant (SourceConfigName/TargetConfigName) appears**.
    - Construct the participant list in that observed order.
    - Emit `participant` lines respecting that order before messages, as required by Mermaid syntax and PRD 50.
  - Ensure this is compatible with:
    - Existing identifier sanitization rules,
    - Deduplication logic (diagram content should remain stable & deterministic).
- Likely touchpoints (for dev’s reference, not decided here):
  - `src/MALIB/Util/DiagramTool/Output.cls` (participant declaration logic),
  - Possibly supporting structures in `Event.cls` or correlation helpers.

#### Step 4 — Testing & QA Execution (Dev/QA)

- Add unit tests (probably in `MALIB.Test.DiagramToolOutputTest.cls` or a sibling test class) to explicitly verify:
  - Participant declarations follow order-of-first-appearance for:
    - Simple sequences,
    - Sequences with loops,
    - Multi-session runs.
  - No regression in:
    - LabelMode behavior,
    - Dedup keys and diagram equality semantics,
    - Warning placement.
- Run tests and record results against the ST-007 QA gate.

---

## 6. Agent Handoff Plan & Next Steps

### 6.1 Handoff to Product Owner / Scrum Master

- **Actions:**
  - Author and approve **ST-007 — Participant Ordering by First Appearance** using the above guidance.
  - Create a matching QA gate file under `docs/qa/gates/`.
  - Ensure ST-007 is **linked as dependent on** ST-005 and ST-006 in planning discussions.

### 6.2 Handoff to Architecture

- **Actions:**
  - Optionally update `docs/architecture.md` to:
    - Mention that participant declarations follow order-of-first-appearance per PRD 50, enforced by ST-007.
  - Confirm there are no architectural conflicts with this behavior (none expected).

### 6.3 Handoff to Development

- **Actions:**
  - Implement participant ordering logic per ST-007 story contract.
  - Add/extend unit tests to validate ordering and determinism.
  - Ensure no breaking changes to the public orchestration signature from ST-006.

### 6.4 Handoff to QA

- **Actions:**
  - Finalize test design for ST-007 and implement coverage.
  - Execute tests, update the ST-007 gate with pass/fail status and evidence.
  - Confirm that participant ordering behavior is validated in at least one end-to-end scenario through `GenerateDiagrams(...)`.

### 6.5 Validation & Success Criteria

- **Success looks like:**
  - A new ST-007 story and QA gate exist and are implemented.
  - For given input events, the generated diagrams:
    - Maintain correct message ordering, labels, warnings, and dedup behavior, and
    - Declare participants in **order-of-first-appearance**, matching PRD 50.
  - Stakeholders confirm that diagrams are easier to read and reason about in real field usage.

With this proposal, we avoid reopening ST-005 while **closing the gap** between PRD 50’s participant rules and the current implementation, via a clean, incremental ST-007 story.
