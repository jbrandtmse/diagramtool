# Sprint Change Proposal — ST-008 Episode-based Loop Compression

Status: Draft  
Owner: Scrum Master (@sm, Bob)  
Related Stories: ST-004 Loop Detection, ST-005 Output & Dedup, ST-006 Orchestration & Entrypoint, ST-007 Participant Ordering  
Proposed New Story: **ST-008 — Episode-based Loop Compression**

---

## 1. Change Context (Checklist Section 1)

### 1.1 Triggering Story / Area

- **Triggering Story:**  
  - ST-004 — Loop Detection (current simple contiguous pair compression).
- **New Capability Needed:**  
  - A new story, ST-008 — Episode-based Loop Compression, to introduce *advanced*, episode-level loop compression on top of ST-004.

### 1.2 Problem Description

- When generating diagrams for realistic, multi-hop, high-volume traces (example: **Session 6445**, XDS/XCPD flows), the current ST-004 implementation:
  - Only compresses **very simple**, contiguous `(Request, Response)` ping‑pong pairs.
  - Does **not** detect or compress longer, repeated multi-hop “episodes” (e.g., repeated AddUpdateDocumentRequest → Registry.Document.* → XMLMessage cycles, or repeated XCPD/Directory transactions).
- Result:
  - The generated diagrams remain **very long**, with many visually identical multi-hop patterns expanded line-by-line.
  - These diagrams are still technically correct but **less readable and less desirable** than they could be.
  - The user expected a **more aggressively compressed** diagram that captures the looping observed in the system at a higher abstraction level.

### 1.3 Issue Classification

- **Type of Issue:**
  - **Technical limitation** of the current ST-004 algorithm:
    - It only compresses contiguous identical Request/Response pairs with no intervening events.
  - **Newly discovered requirement**:
    - Need for **episode-based loop compression** that:
      - Groups multi-hop call flows into *episodes*.
      - Detects repeated episodes and compresses them into `loop N times` blocks.
      - Explicitly **ignores trace/log events** when deciding episode equality.

### 1.4 Impact & Scope

- **Impact Level:**
  - **Moderate**:
    - Does not make diagrams unusable,
    - But makes them **undesirable** for complex real-world flows where repetition is common.
- **Scope / Applicability:**
  - Expected to be broadly applicable:
    - XDS/XCPD traces (like Session 6445) are concrete examples,
    - But the **episode-based approach should generalize** across many productions and scenarios (not XDS-only).
- **Evidence:**
  - Real trace from Session 6445 shows:
    - Repeated, structurally identical AddUpdateDocumentRequest / XMLMessage cycles.
    - Repeated XCPD / Directory / remote-call transactions.
    - Yet the current diagram is a long, fully expanded sequence with no higher-level loops detected.

---

## 2. Epic Impact Assessment (Checklist Section 2)

### 2.1 Current Epic (DiagramTool Core)

- The DiagramTool epic remains viable:
  - ST-001..ST-007 are still coherent and achievable.
  - No need to abandon or fundamentally redefine the epic.
- ST-004 remains valid as:
  - “Simple, contiguous pair compression” for **basic loop detection**.
- **Change:** Introduce **ST-008 — Episode-based Loop Compression**:
  - A new story in the same epic.
  - Treat this as a **near-term, MVP requirement**, not a post-MVP enhancement.
  - ST-008 will **build on top of** ST-004’s output, not replace it.

### 2.2 Future Epics

- No epic is invalidated.
- Advanced looping:
  - Enhances existing diagrams’ readability,
  - Does not break the PRD’s functional requirements.
- Ordering:
  - ST-008 should be scheduled **after** ST-004, ST-005, ST-006, and ST-007, once the event pipeline and participant ordering are stable.
  - Still within the same MVP epic.

### 2.3 Epic Impact Summary

- **Net Effect:** Add a new MVP story **ST-008** that:
  - Extends loop detection from simple pairs to repeated **episodes**.
  - Keeps the existing ST-004 implementation intact as one phase, with ST-008 adding a second phase of compression.

---

## 3. Artifact Conflict & Impact Analysis (Checklist Section 3)

### 3.1 PRD

- PRD is not contradicted, but:
  - Current Diagramming Rules and Acceptance Criteria mention loop detection generically and may implicitly assume simpler behavior.
- Needed updates:
  - `docs/prd/50-diagramming-rules.md`:
    - Add a new subsection under loop-related rules describing **episode-based loop compression**:
      - Definition of “episode” at a high level (transactional call flow).
      - Behavior: repeated episodes may be rendered as `loop N times`, with inner body representing one canonical episode.
      - Clarify that **trace/log events are ignored for episode equality**, but may still appear inside loop bodies.
  - `docs/prd/60-acceptance-criteria.md`:
    - Add new ACs (e.g., AC-XX) for:
      - Episode-based loop detection and compression.
      - Determinism of episode grouping and loop counts.

### 3.2 Architecture Document

- `docs/architecture.md` and `docs/architecture/tech-stack.md`:
  - Should be augmented to describe:
    - The two-level loop strategy:
      - ST-004 pair-level compression (already in place).
      - ST-008 episode-level compression building on the event stream after correlation/looping.
    - The concept of **episodes**:
      - Grouping events into higher-level multi-hop flows.
      - Using correlation metadata (PairId, PairWithID, CorrespondingMessageId, ReturnQueueName, Invocation) to identify episode boundaries.
    - **Trace/log handling**:
      - Trace events (e.g., `HS.Util.Trace.Request`) are inside episodes for context,
      - But excluded from episode signatures, so they don’t block compression.

### 3.3 Stories & QA

- New Story:
  - `docs/stories/story-008-episode-based-loop-compression.md` (to be created) describing:
    - Episode grouping requirements.
    - Loop detection rules on episodes.
    - Determinism and ignoring of trace/log events in equality.
  - This story will explicitly reference:
    - ST-004 for input events,
    - ST-005/ST-006 for output pipeline and dedup,
    - ST-007 for participant ordering stability.
- QA:
  - New QA gate:
    - `docs/qa/gates/st.008-episode-loop-compression.yml` (to be added later):
      - Mapping tests to new ACs (loop compression correctness, determinism, interaction with warnings/dedup).
  - New QA assessment checklist for ST-008 under `docs/qa/assessments/`.

---

## 4. Path Forward Evaluation (Checklist Section 4)

### 4.1 Option 1: Direct Adjustment / Integration

- Approach:
  - Keep ST-004 as it is (pair-level).
  - Add ST-008 to:
    - Group events into episodes.
    - Compute canonical **episode signatures** (excluding trace/log events).
    - Detect repeated episodes and compress them into `loop N times` blocks.
- Pros:
  - Minimal risk to existing behavior; ST-004 and ST-005 tests remain valid.
  - Clear layering: correlation → pair loops (ST-004) → episode loops (ST-008) → output/dedup (ST-005/ST-006/ST-007).
  - Easy to gate episode-based compression with configuration if desired.
- Cons:
  - More complexity in the Output/loop pipeline.
  - Needs careful testing to ensure determinism and no over-compression.

### 4.2 Option 2: Rollback

- Rollback ST-004 to re-scope, then reimplement with episodes:
  - Not recommended:
    - ST-004 is already integrated and tested.
    - Rolling back would throw away good behavior for simple pairs.
    - Adds schedule risk with little benefit over option 1.

### 4.3 Option 3: PRD MVP Re-scope

- Remove advanced looping from MVP:
  - User explicitly wants **episode-based looping as part of MVP**.
  - Re-scoping it out would degrade the perceived usefulness of diagrams for complex flows.
- Conclusion: Not acceptable for desired MVP.

### 4.4 Recommended Path

- **Option 1: Direct Adjustment via new MVP story ST-008**:
  - Keep ST-004 as “simple contiguous pair loop compression”.
  - Introduce ST-008 for **episode-based loop compression**:
    - Built on top of ST-004’s event stream.
    - Ignoring trace/log events in episode signatures.
    - Applied as a second pass before rendering/participant ordering.

---

## 5. Proposed Edits & New Artifacts (Checklist Section 5)

### 5.1 New Story — ST-008 Episode-based Loop Compression (Outline)

**File to add:** `docs/stories/story-008-episode-based-loop-compression.md`

High-level outline (proposed content):

- Title: **Story ST-008 — Episode-based Loop Compression**
- Status: Approved (once PO agrees).
- Scope:
  - Define **episodes** as higher-level transactional call flows.
  - Add an episode-building phase on top of correlated/loop-compressed events:
    - Use correlation metadata and participants to group events.
  - Define canonical **episode signatures**:
    - Include only business-relevant lines (Src, Arrow, Dst, label, Invocation, EventType).
    - **Exclude trace/log events** from signatures.
  - Detect repeated episodes:
    - Compress contiguous runs of equal signatures into `loop N times` blocks.
    - Render inner body as one canonical episode (including trace/log events).
  - Preserve determinism:
    - For a fixed event stream, episode boundaries, signatures, and loop counts must be stable.
- Dependencies:
  - ST-004 (pair-level loops).
  - ST-005 (output & dedup).
  - ST-006 (orchestration).
  - ST-007 (participant ordering).
- ACs:
  - Episode definition, repeat detection, interaction with existing loops, determinism, and ignoring of trace/log in equality.

### 5.2 PRD Updates

- `docs/prd/50-diagramming-rules.md`:
  - Add an “Episode-based Loops” section under loop rules, specifying:
    - Episode-level grouping.
    - Signature rules (business-only, ignore trace/log).
    - Rendering rules for `loop N times`.
- `docs/prd/60-acceptance-criteria.md`:
  - Add new ACs for episode-based looping:
    - Clear conditions for when loops must be emitted.
    - Interaction with warnings and dedup (episode compression does not hide warnings or break dedup).

### 5.3 Architecture Updates

- `docs/architecture.md`:
  - Describe:
    - Multi-phase transformation pipeline:
      1. Correlation (ST-003).
      2. Pair-level loops (ST-004).
      3. Episode grouping + episode-based looping (ST-008).
      4. Output & dedup (ST-005/ST-006).
      5. Participant ordering (ST-007).
- `docs/architecture/tech-stack.md`:
  - Add notes that:
    - Loop behavior now includes an **episode-level pass**.
    - Trace/log events are excluded from structural equality but retained in emitted loops.

### 5.4 QA Artifacts

- New QA gate:
  - `docs/qa/gates/st.008-episode-loop-compression.yml`
    - Describing test coverage for:
      - Simple episodes with loops.
      - Multi-hop episodes (like XDS/XCPD, AddUpdateDocument) with repeated occurrences.
      - Interaction with trace/log events.
- New QA assessment:
  - `docs/qa/assessments/st.008-test-design-YYYYMMDD.md`
    - Listing unit and integration test scenarios for ST-008.

---

## 6. Final Recommendation & Next Steps (Checklist Section 6)

### 6.1 Recommended Path Forward

- **Add ST-008 — Episode-based Loop Compression** as a new MVP story in the current DiagramTool epic.
- Keep ST-004 intact, with ST-008 explicitly **building on top** of it.
- Update PRD, architecture, and QA artifacts as outlined.
- Implement episode-based loop compression with:
  - Episode building on correlated events.
  - Canonical signatures that **ignore trace/log messages**.
  - Detection of contiguous runs of identical episodes and emission of `loop N times` blocks.

### 6.2 Next Actions

- PO/SM:
  - Approve this Sprint Change Proposal.
  - Create `story-008-episode-based-loop-compression.md` based on the outline above.
  - Slot ST-008 into the current MVP backlog after ST-007.
- Dev Agent:
  - Implement ST-008 per the new story and PRD/architecture updates.
  - Add tests under `MALIB.Test.DiagramToolOutputTest` (and optionally `MALIB.Test.DiagramToolTest`) to cover:
    - Episode grouping.
    - Episode signatures ignoring trace/log.
    - Loop compression of repeated episodes.
- QA:
  - Add gate and assessment artifacts for ST-008.
  - Run and record `%UnitTest` results.

### 6.3 Approval

- This proposal awaits your explicit approval. Once approved:
  - ST-008 can be drafted as a full story.
  - The new story and artifact updates can be handed off to the Dev agent for implementation within the MVP scope.
