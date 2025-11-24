# Test Design: Story st.004 — Loop Detection (Contiguous Identical Pairs)

Date: 2025-11-23
Designer: Quinn (Test Architect)

Source Story: `docs/stories/story-004-loop-detection.md`
Related PRD Shards:
- FR-08 Loop Detection and Compression — `docs/prd/20-functional-requirements.md#fr-08-loop-detection-and-compression`
- FR-09 Per-Session Diagram Generation — `docs/prd/20-functional-requirements.md#fr-09-per-session-diagram-generation`
- AC-08 Loop Detection and Compression — `docs/prd/60-acceptance-criteria.md#ac-08-loop-detection-and-compression`
- AC-09 Per-Session Diagram Structure — `docs/prd/60-acceptance-criteria.md#ac-09-per-session-diagram-structure`
- Diagramming rules (loops) — `docs/prd/50-diagramming-rules.md#7-loop-compression`

---
## Test Strategy Overview

Scope of this test design is **ST-004 loop detection/compression** in the context of the DiagramTool pipeline:
- Input: correlated events produced by ST-003 (`MALIB.Util.DiagramTool.Correlation.CorrelateEvents`).
- Logic under test: loop grouping and compression implemented in `MALIB.Util.DiagramTool.Output.ApplyLoopCompression`, plus its interaction with `BuildDiagramForSession`.
- Output: Mermaid `sequenceDiagram` text with valid `loop N times ... end` blocks and correct surrounding structure.

Testing focus:
- **Correct grouping** of strictly contiguous identical request/response pairs (AC-08).
- **Proper non-grouping** when signatures differ or contiguity is broken.
- **Valid diagram structure** and participant ordering when loops are present (AC-09).
- **Determinism** of loop segmentation (NFR-02).

Planned coverage summary:
- **Total test scenarios:** 9
- **By level:**
  - Unit: 8
  - Integration: 1
  - E2E: 0 (end-to-end loop behavior will be validated primarily under ST-006 orchestration tests)
- **By priority:**
  - P0: 0 (no direct revenue/security/compliance impact)
  - P1: 5 (core correctness/readability of diagrams and loop behavior)
  - P2: 4 (edge cases and robustness/determinism)
  - P3: 0

Rationale:
- Loop grouping is **core to diagram readability** but not security/revenue critical → predominantly **P1**.
- Most behavior is **algorithmic and deterministic**, ideal for **unit tests** per test-levels framework.
- A single **integration test** validates the interaction between correlation (ST-003) and output (ST-004).

---
## Test Scenarios by Acceptance Criteria

### AC-08 — Loop Detection and Compression
> Given contiguous repeated pairs of identical request/response signatures, when generating the diagram, then repeated pairs are compressed into a loop block with count N and the request/response lines inside; loop compression only applies to strictly contiguous identical pairs; interruptions end the compression window.

#### Scenarios

| ID              | Level | Priority | Test                                                                 | Justification |
| --------------- | ----- | -------- | -------------------------------------------------------------------- | ------------- |
| st.004-UNIT-001 | Unit  | P1       | **Basic contiguous Inproc loop**: 3 identical Inproc request/response pairs with same Src/Dst/Label/Arrow should render as a single `loop 3 times <Label>` block containing one request + one response line. | Core happy-path loop behavior; pure algorithmic grouping; high business impact on readability; ideal unit test. |
| st.004-UNIT-002 | Unit  | P1       | **Interruption splits loops**: 2 identical pairs, then a different pair, then 2 more identical pairs. Expect two separate loop blocks of N=2, with the interrupting pair outside any loop. | Verifies strict contiguity rule (no spanning over interruptions); ensures implementation respects window boundaries. |
| st.004-UNIT-003 | Unit  | P2       | **Non-compressible singles**: sequences of single pairs or pairs that never repeat exactly (e.g., differing labels or endpoints). Expect **no** `loop` blocks; all pairs emitted as plain request/response lines. | Guards against over-aggressive compression; relatively low-risk but important for correctness in mixed flows. |
| st.004-UNIT-004 | Unit  | P2       | **Ambiguous/partial pairs**: include singletons (unpaired requests or responses) and mixed sequences where not all instances have both sides of the pair. Expect compression only for fully matched, repeated pairs; singletons remain as individual lines. | Ensures best-effort behavior: no compression when pairing is ambiguous; aligns with story’s non-fatal behavior policy. |
| st.004-UNIT-005 | Unit  | P2       | **Deterministic segmentation**: given a fixed correlated event list with multiple potential loop regions, repeated invocations of `BuildDiagramForSession`/`ApplyLoopCompression` produce identical `loop` boundaries and counts. | Directly validates NFR-02 (determinism) for loop segmentation; important for stable diagrams and test repeatability. |
| st.004-UNIT-006 | Unit  | P1       | **Queued loops**: multiple identical queued (async) request/response pairs with Arrow=`-->>` on both legs should be compressed into a `loop N times <Label>` block, preserving `-->>` inside the loop. | Ensures loop detection behaves correctly for queued interactions and respects async arrow semantics. |
| st.004-UNIT-007 | Unit  | P2       | **Mixed Inproc/Queue signatures not compressed**: same Src/Dst/Label but different Invocation/Arrow (e.g., first pair Inproc `->>`, second pair Queue `-->>`). Expect **no** loop compression across these pairs. | Confirms that signature comparison includes arrow semantics (per story guidance) and avoids incorrectly mixing sync/async interactions in one loop. |

Implementation notes (for dev, not test level decision):
- These unit tests should **inject correlated events directly** (via %DynamicObject arrays) into `ApplyLoopCompression` or into `BuildDiagramForSession` with a stubbed/simple correlation step, to keep them at **unit level** and avoid DB/SQL.

---
### AC-09 — Per-Session Diagram Structure (loop-related aspects)
> Participants declared before message lines; compressed loops render as valid Mermaid blocks with correct arrows and labels.

#### Scenarios

| ID              | Level      | Priority | Test                                                                                              | Justification |
| --------------- | ---------- | -------- | ------------------------------------------------------------------------------------------------- | ------------- |
| st.004-UNIT-008 | Unit       | P1       | **Loop within valid session structure**: for a session with participants A/B and a 3× loop, verify output structure: `sequenceDiagram`, `%% Session <id>`, participant lines, then `loop 3 times <Label>` with correct indented message lines and `end`. | Ensures AC-09 is preserved when loops are introduced; validates that loop blocks don’t break the required per-session structure. |
| st.004-INT-001  | Integration| P1       | **Correlation + loops integration**: construct pRows that, when passed through `Correlation.CorrelateEvents` and then `BuildDiagramForSession`, produce a diagram containing a loop and plain regions. Validate: correct participants, arrows, loop placement, and count. | Integration between ST-003 and ST-004; confirms loop grouping works correctly against real correlated events and not just synthetic events. |

Notes:
- No separate E2E scenario is defined specifically for ST-004; E2E verification of loops will be addressed under **ST-006 orchestration tests** (full pipeline including ST-001–ST-005).

---
## Risk Coverage

Primary risks addressed:
- **R1 – Incorrect loop grouping:** repeated pairs not compressed (diagram too noisy) or wrongly compressed (loss of detail / misrepresentation).
- **R2 – Broken diagram structure:** loops inserted in a way that breaks Mermaid syntax or participant ordering.
- **R3 – Non-deterministic segmentation:** same data yields different loop boundaries on different runs, undermining reproducibility.
- **R4 – Asymmetric handling of Inproc vs Queue:** loops correct for Inproc but mishandled for queued interactions.

Risk-to-test mapping (high level):
- R1 → st.004-UNIT-001/002/003/004/007, st.004-INT-001
- R2 → st.004-UNIT-008, st.004-INT-001
- R3 → st.004-UNIT-005
- R4 → st.004-UNIT-006/007, st.004-INT-001

No dedicated performance, security, or compliance risks are introduced by ST-004 beyond existing NFRs; loop detection is purely in-memory and deterministic.

---
## Recommended Execution Order

1. **Unit P1 tests (fail fast on core loop logic):**
   - st.004-UNIT-001 — Basic contiguous Inproc loop
   - st.004-UNIT-002 — Interruption splits loops
   - st.004-UNIT-006 — Queued loops
   - st.004-UNIT-008 — Loop within valid session structure
2. **Integration P1 test:**
   - st.004-INT-001 — Correlation + loops integration
3. **Unit P2 tests (edge cases & determinism):**
   - st.004-UNIT-003 — Non-compressible singles
   - st.004-UNIT-004 — Ambiguous/partial pairs
   - st.004-UNIT-005 — Deterministic segmentation
   - st.004-UNIT-007 — Mixed Inproc/Queue not compressed

This ordering ensures that fundamental loop behavior and structural validity are verified before edge cases and robustness.

---
## Gate YAML Block (Summary for QA Gate Use)

```yaml
test_design:
  scenarios_total: 9
  by_level:
    unit: 8
    integration: 1
    e2e: 0
  by_priority:
    p0: 0
    p1: 5
    p2: 4
    p3: 0
  coverage_gaps: []  # All ACs for ST-004 (AC-08, AC-09 partial) have at least one test scenario
```

---
## Trace References

For downstream QA tooling (e.g., trace-requirements):

```text
Test design matrix: docs/qa/assessments/st.004-test-design-20251123.md
P0 tests identified: 0
```

All scenarios above are **advisory**: implementation teams may refine/add scenarios based on actual code structure, but this design provides a complete, risk-aware starting point aligned with the PRD and Story ST-004.
