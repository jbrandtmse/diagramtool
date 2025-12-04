# Story ST-004 — Loop Detection (Contiguous Identical Pairs)

Status: Done
Epic/PRD: docs/prd.md (v4)
Shards:
- 20-functional-requirements.md (FR-08, FR-09)
- 50-diagramming-rules.md
- 60-acceptance-criteria.md (AC-08, AC-09)

## Story
**As an** IRIS developer generating sequence diagrams,
**I want** repeated request/response exchanges with identical signatures to be compressed into Mermaid loop blocks,
**so that** long repeated patterns remain readable without losing essential information.

## Business Value
- Improves readability of chatty flows.
- Keeps diagrams compact and consumable for stakeholders.

## Scope (Decisions-aligned)
- Loop signature:
  - Request: (Src, Dst, Label)
  - Response: (Src, Dst, Label)
- Detection policy:
  - Identify strictly contiguous repeated pairs with identical signatures
  - N > 1 compresses into:
    loop N times <Label>
      <Req line>
      <Resp line>
    end
  - Interruption by a different message signature ends the compression window
- Emission details:
  - Use current label policy (default full MessageBodyClassName, labelMode runtime toggle supports short)
  - Use arrow semantics from correlation (Inproc ->>, Queue -->> both legs)
  - Ensure participants are declared once before messages
- Non-fatal behavior:
  - Best-effort; do not compress if pairing is ambiguous
  - Emit warnings via "%%" comments for relevant anomalies if encountered during grouping (rare)

## Out of Scope (MVP)
- Non-contiguous repeats or fuzzy matching
- Multi-pair grouping across different labels or endpoints
- Any CSV-based operation (SQL-only project)

## Assumptions
- Correlated event list is available from ST-003 as produced by `MALIB.Util.DiagramTool.Correlation.CorrelateEvents` for a given SessionId (pairs and singletons with arrows).
- Participants have already been derived from ordered rows per ST-002 and are emitted once per diagram by the output stage.

## Dependencies
- ST-003 must provide correlated request/response pairs and singletons with a stable event schema.
- ST-005 will build the final output with deduplication, append-only behavior, divider, warnings, and label toggle, assuming loop compression from ST-004 has already been applied.
- ST-006 orchestration and public entry API (`GenerateDiagrams`) will invoke `MALIB.Util.DiagramTool.Output.BuildDiagramForSession`, which delegates loop behavior to `ApplyLoopCompression` as part of the main pipeline.

## Acceptance Criteria (mapped from PRD 60-acceptance-criteria.md)
AC-08 Loop Detection and Compression
- Given contiguous repeated pairs of identical request/response signatures
- When generating the diagram
- Then repeated pairs are compressed into a loop block with count N and the request/response lines inside
- And loop compression only applies to strictly contiguous identical pairs
- And when an interruption occurs (different signature), compression ends

AC-09 Per-Session Diagram Structure (partial)
- Given a single SessionId
- When emitting the diagram
- Then participant declarations precede message lines
- And compressed loops render as valid Mermaid blocks with correct arrows and labels

## Additional Test Cases
- 3 identical pairs contiguous → loop 3 times with 1 req + 1 resp lines
- 2 identical pairs, interruption, then 2 identical pairs → two separate loop blocks
- Queued loops: both legs use -->> arrows
- Mixed Inproc/Queue loops should only compress when the pair signature (including arrows derived from Invocation) is identical

## Non-Functional References
- Determinism (NFR-02): same inputs yield the same loop segmentation and output text.
- Resilience (NFR-03): anomalies lead to best-effort emission and optional warnings rather than failures.
- Testability (NFR-05): unit tests exercise contiguous grouping semantics and loop emission.

## Tasks / Subtasks
- [x] T1. Implement loop grouping
  - Scan correlated events; group contiguous identical pair signatures
  - Emit loop blocks for N>1; otherwise emit single pair lines

- [x] T2. Edge conditions
  - Handle singletons and mixed sequences robustly
  - Ensure correct indentation and newline handling for Mermaid validity

- [x] T3. Unit Tests (%UnitTest)
  - Validate examples above and edge cases
  - Confirm deterministic behavior

- [x] T4. Documentation
  - Explain loop signature and why contiguity matters
  - Provide examples with Inproc and Queue variants

## Implementation Target and Contract
- Class: `MALIB.Util.DiagramTool.Output`
- Methods:
  - `ClassMethod BuildDiagramForSession(pSessionId As %Integer, pRows As %DynamicArray, pLabelMode As %String, Output pDiagram As %String) As %Status`
    - Existing ST-006 helper that:
      - Loads ordered rows for a single SessionId.
      - Calls `MALIB.Util.DiagramTool.Correlation.CorrelateEvents` to produce the correlated event list.
      - Calls `ApplyLoopCompression` to apply loop detection/compression.
      - Emits Mermaid sequenceDiagram text, including participants and message/loop lines.
    - ST-004 must ensure that the combination of `ApplyLoopCompression` + rendering satisfies AC-08 and AC-09 for loop blocks.
  - `ClassMethod ApplyLoopCompression(pEvents As %DynamicArray, Output pOutEvents As %DynamicArray) As %Status`
    - Implementation target for ST-004 (currently a pass-through stub).
    - Input: correlated event list for a single SessionId as described below.
    - Behavior (logical view):
      - Scan events in order, identifying strictly contiguous regions of repeated request/response pairs with identical signature (Req(Src, Dst, Label), Resp(Src, Dst, Label) and matching arrow semantics from ST-003/PRD).
      - For contiguous regions where N > 1, drive `BuildDiagramForSession` to emit a single Mermaid loop block:
        - `loop N times <Label>`
        - the request/response lines inside the loop
        - `end`
      - For regions where N = 1 or pairing is ambiguous, emit single request/response lines without loop compression.
      - Implementation may use synthetic events or other internal representation as long as the final Mermaid output meets AC-08/AC-09.

## Correlated Event Input (from ST-003)
Loop detection operates on the correlated event list produced by ST-003. For this story, the following fields are most relevant (see ST-003 “Correlated Event Schema” for full details):
- `EventType`: "Request" | "Response" | "Warning" (loops operate on Request/Response pairs only).
- `Src`: participant identifier / config name used as the Mermaid source.
- `Dst`: participant identifier / config name used as the Mermaid target.
- `Label`: message label (default = full MessageBodyClassName; labelMode may shorten this later).
- `Arrow`: "->>" or "-->>" per Invocation → arrow semantics (Inproc vs Queue) from ST-003 / PRD.
- `ID`: original Ens.MessageHeader ID, used for traceability and fallback lookups.
- `PairWithID`: for Response events, the ID of the corresponding Request when correlated.
- `SessionId`: session key for scoping events to a single diagram.
- `Notes`: optional warning text to be emitted as `%%` comments near affected lines.
- `PairId`: optional stable identifier for paired events, useful for tests.

Loop grouping MUST respect:
- Event ordering as produced by ST-003 (forward-only; no reordering across non-identical pairs).
- Pairing information (`PairWithID`, `PairId`) to distinguish true request/response pairs from standalone events.
- Arrow semantics when deciding whether two pairs are “identical” for loop purposes, especially for mixed Inproc/Queue scenarios.

## Key Files to Modify
- `src/MALIB/Util/DiagramTool/Output.cls`
  - Implement real loop grouping logic inside `ApplyLoopCompression`.
  - Adjust `BuildDiagramForSession` as needed to render Mermaid `loop ... end` blocks while still satisfying ST-005 output/dedup behaviors.
- `src/MALIB/Test/DiagramToolOutputTest.cls`
  - Add %UnitTest methods that cover:
    - AC-08 examples (contiguous identical pairs, interruptions).
    - AC-09 structure aspects related to loop placement and validity.
    - Additional Test Cases listed above, including queued vs inproc loops and mixed Invocation scenarios.

## Testing
- Framework: IRIS %UnitTest under `src/MALIB/Test/` (extend `MALIB.Test.DiagramToolOutputTest`).
- AC coverage:
  - AC-08 Loop Detection and Compression: contiguous identical pairs compressed into `loop N times` blocks with correct N and inner lines.
  - AC-09 Per-Session Diagram Structure (partial): participants before message lines; loop blocks rendered as valid Mermaid syntax with correct arrows and labels.
- Suggested scenarios (non-exhaustive):
  - Exact matches of the Additional Test Cases in this story.
  - Mixed sequences of:
    - Singletons (no loop)
    - Single pairs (no loop)
    - Multi-pair loops
    - Interleaved non-identical pairs that break loop regions.
  - Determinism: repeated runs over the same correlated events produce identical loop segmentation and output.

## Anchored References
- FR-08 Loop Detection and Compression: `docs/prd/20-functional-requirements.md#fr-08-loop-detection-and-compression`
- FR-09 Per-Session Diagram Generation: `docs/prd/20-functional-requirements.md#fr-09-per-session-diagram-generation`
- AC-08 Loop Detection and Compression: `docs/prd/60-acceptance-criteria.md#ac-08-loop-detection-and-compression`
- AC-09 Per-Session Diagram Structure: `docs/prd/60-acceptance-criteria.md#ac-09-per-session-diagram-structure`
- Diagramming rules (loops): `docs/prd/50-diagramming-rules.md#7-loop-compression`

## Definition of Ready
- Correlated pairs and singletons from ST-003 are available and stable.
- `MALIB.Util.DiagramTool.Output.BuildDiagramForSession` and `ApplyLoopCompression` are the agreed implementation targets for loop behavior.

## Definition of Done
- All ACs met with passing %UnitTest.
- Correct Mermaid output for compressed and non-compressed regions, including valid `loop ... end` blocks.
- Story marked Ready for PO review and QA design.

## Change Log
- v1.0 Implemented typed Event-based loop compression; tests passing; status set to Ready for Review.
- v0.3 Marked Ready for Development; reformatted Story and Tasks sections to match template style.
- v0.2 Clarified implementation target, correlated event input, key files, testing guidance, and anchored references.
- v0.1 Draft created and aligned with finalized decisions.

## QA Results

### Review Date: 2025-12-03

### Reviewed By: Quinn (Test Architect)

### Code Quality Assessment

Implementation of loop detection is localized in `MALIB.Util.DiagramTool.Output.ApplyLoopCompression`, with dedicated tests validating core Inproc and Queue loop behaviors plus mixed-arrow cases. The design respects the correlated event schema from ST-003, uses forward-only scanning, and maintains deterministic behavior for a given input. No blocking issues or major maintainability concerns were identified for ST-004.

### Refactoring Performed

- **None during this QA review**
  - **Change**: No code refactoring performed; review relied on existing implementation and unit tests.
  - **Why**: Current implementation already meets AC-08 and the loop-related aspects of AC-09 based on available tests.
  - **How**: Future improvements are captured below as recommendations rather than in-place refactors.

### Compliance Check

- Coding Standards: ✓ — Implementation and tests align with existing DiagramTool style and ObjectScript testing conventions.
- Project Structure: ✓ — Loop logic and tests are in the expected `MALIB.Util.DiagramTool.Output` and `MALIB.Test.DiagramToolOutputTest` locations.
- Testing Strategy: ✓ — Behavior is primarily covered by unit tests with clear scenario naming, plus future integration coverage planned in the test design.
- All ACs Met: ✓ — AC-08 and loop-related aspects of AC-09 are satisfied for implemented scenarios; remaining P2 scenarios are tracked as non-blocking enhancements.

### Improvements Checklist

- [ ] Implement remaining P2 unit scenarios from `docs/qa/assessments/st.004-test-design-20251123.md` (non-compressible singles, ambiguous/partial pairs, deterministic segmentation).
- [ ] Add integration test `st.004-INT-001` to exercise correlation + loop compression end-to-end using real correlated events.
- [ ] Consider additional diagnostics or logging around ambiguous loop regions or skipped compression decisions if future debugging requires more insight.

### Security Review

Loop detection operates only on correlated in-memory event lists and emits Mermaid text; no new I/O, persistence, or external calls were introduced. No security concerns were identified for this story.

### Performance Considerations

Loop grouping uses a forward-only scan over the correlated events and is expected to be O(n) with negligible overhead relative to correlation and SQL stages. No performance issues were observed in the current unit-test scope; future large-session profiling can be considered if needed.

### Files Modified During Review

- Documentation/QA artifacts only:
  - `docs/qa/gates/st.004-loop-detection.yml`
  - `docs/stories/story-004-loop-detection.md` (this QA Results section)

_No code or test files were modified during this QA review; no updates to the story File List are required._

### Gate Status

Gate: PASS → `docs/qa/gates/st.004-loop-detection.yml`  
Risk profile: not yet generated (see `docs/qa/assessments/st.004-test-design-20251123.md` for test design).  
NFR assessment: not yet generated; NFR-02/NFR-03/NFR-05 are partially validated via current unit tests.

### Recommended Status

[✓ Ready for Done] / [✗ Changes Required - See unchecked items above]

Given the passing unit tests and absence of blocking issues, this review recommends **Ready for Done**, with remaining items tracked as follow-up improvements rather than blockers.
