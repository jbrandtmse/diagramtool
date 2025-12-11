# Test Design: Story ST-008 — Episode-based Loop Compression

Date: 2025-12-10  
Designer: Quinn (Test Architect)  

## Test Strategy Overview

- Total test scenarios: 10  
- By level:
  - Unit: 7
  - Integration: 3
  - E2E: 0 (library-level feature, exercised via integration tests in IRIS)
- By priority:
  - P0: 0
  - P1: 6
  - P2: 4
  - P3: 0

Rationale:

- This is a core DiagramTool library feature, not a UI or external API surface.
- Focus is on:
  - Deterministic, correct **episode grouping and signatures** (unit).
  - Correct **loop compression of episodes** (unit).
  - Correct **interaction with existing pipeline** (integration).
- No separate E2E layer beyond IRIS `%UnitTest` integration tests is needed; integration tests in `MALIB.Test.DiagramToolTest` cover end-to-end flows for diagrams.

---

## Test Scenarios by Acceptance Criteria

### AC-08.1 — Episode Grouping and Signature (Business-Only)

> When the episode-building phase runs, events are grouped into episodes reflecting multi-hop transactional flows,  
> and episode signatures are computed from business-relevant events only, ignoring trace/log events.

#### Scenarios

| ID              | Level | Priority | Test                                                                 | Justification |
|-----------------|-------|----------|----------------------------------------------------------------------|--------------|
| ST-008-UNIT-001 | Unit  | P1       | Episode grouping: simple multi-hop flow forms a single episode      | Core grouping behavior; pure in-process logic in Output layer. |
| ST-008-UNIT-002 | Unit  | P1       | Business-only signature: identical business events, no trace        | Validates base signature computation for equality. |
| ST-008-UNIT-003 | Unit  | P1       | Trace-insensitivity: episodes differ only by trace/log events       | Ensures trace/log events are ignored for equality as required. |
| ST-008-INT-001  | Int   | P2       | Grouping in context: correlated trace (e.g., small XDS/XCPD sample) | Confirms episode grouping behavior in a realistic IRIS trace via `GenerateDiagrams`. |

**Notes / Hints for implementation:**

- **UNIT-001:** Construct a synthetic correlated event array representing a single transaction (A → B → C → B → A). Verify:
  - Episode builder returns exactly one episode.
  - All related events are inside that episode.
- **UNIT-002:** Build two episodes with identical sequences of business events; verify signatures are equal.
- **UNIT-003:** Add trace events (`HS.Util.Trace.Request` or similar) to one episode only; verify signatures remain equal.
- **INT-001:** Use a small Ens.MessageHeader fixture with one multi-hop flow and confirm the grouping logic via an exported debug or targeted test helper.

---

### AC-08.2 — Episode-Based Loop Compression for Repeated Flows

> When a specific episode repeats contiguously, diagrams must render a `loop N times` block with one canonical episode body (including trace/log events).

#### Scenarios

| ID              | Level | Priority | Test                                                                                      | Justification |
|-----------------|-------|----------|-------------------------------------------------------------------------------------------|--------------|
| ST-008-UNIT-004 | Unit  | P1       | Contiguous identical episodes compressed into `loop N times`                             | Core loop compression algorithm over episodes. |
| ST-008-UNIT-005 | Unit  | P1       | Episodes with different business structure **not** compressed together                    | Protects semantic correctness; avoids over-compression. |
| ST-008-INT-002  | Int   | P1       | XDS/XCPD-style or AddUpdateDocument repeated flows compressed at episode level in output | Validates end-to-end behavior on realistic traces. |

**Notes / Hints for implementation:**

- **UNIT-004:** Build three identical episodes in sequence; run episode-level compression and verify:
  - A single `loop 3 times <label>` block is emitted.
  - Inner body matches the canonical episode, including trace/log lines.
- **UNIT-005:** Build episodes where one differs in Dst or label; verify that:
  - Only truly identical episodes are compressed.
  - Mixed episodes stay separate.
- **INT-002:** Use a trace similar to Session 6445 (or a reduced subset) with repeated AddUpdateDocument or XCPD transactions; assert:
  - At least one high-level loop block appears where episodes repeat.
  - Trace/log comments and warnings remain present in the loop body.

---

### AC-08.3 — Interaction with Pair-Level Loops, Dedup, and LabelMode

> Episode-based loops must coexist correctly with ST-004 pair-level loops, ST-005 dedup/labeling/warnings, ST-006 orchestration, and ST-007 participant ordering.

#### Scenarios

| ID              | Level | Priority | Test                                                                                     | Justification |
|-----------------|-------|----------|------------------------------------------------------------------------------------------|--------------|
| ST-008-INT-003  | Int   | P1       | Pair-level loops from ST-004 remain correct with episode-based compression enabled      | Ensures ST-004 behavior is preserved. |
| ST-008-UNIT-006 | Unit  | P2       | Dedup keys unchanged for diagrams that are structurally identical with/without episodes | Protects ST-005 dedup semantics. |
| ST-008-UNIT-007 | Unit  | P2       | LabelMode full/short behavior unaffected by episode loops                                | Maintains label semantics (ST-005/ST-006). |

**Notes / Hints for implementation:**

- **INT-003:** Use an existing ST-004 loop scenario (e.g., repeated identical Request/Response pairs) combined with episodes:
  - Confirm that pair-level loops still appear as expected inside or alongside episode-based loops.
- **UNIT-006:** Compare dedup keys for:
  - Diagram A: with episode-based compression.
  - Diagram B: structurally equivalent diagram generated for another session (different SessionId).
  - Ensure dedup keys remain consistent with ST-005 behavior.
- **UNIT-007:** Reuse ST-005 labelMode tests (full vs short) with episode loops enabled:
  - Confirm that emitted labels inside loops respect labelMode in the same way as non-loop messages.

---

### AC-08.4 — Determinism and Stability

> For a fixed, correlated event stream, episode boundaries, signatures, and loop counts must be deterministic; trace/log noise must not change equality.

#### Scenarios

| ID              | Level | Priority | Test                                                            | Justification |
|-----------------|-------|----------|-----------------------------------------------------------------|--------------|
| ST-008-UNIT-008 | Unit  | P1       | Deterministic episode building and signatures across runs       | Ensures stable grouping and equality decisions. |
| ST-008-UNIT-009 | Unit  | P1       | Deterministic episode-based loops across runs (same loop blocks) | Ensures stable compressed diagrams for given inputs. |

**Notes / Hints for implementation:**

- **UNIT-008:** For a fixed synthetic correlated event array:
  - Run the episode-building + signature computation twice.
  - Assert that episodes and signatures are bit-identical across runs.
- **UNIT-009:** For a fixed trace that triggers episode loops:
  - Generate diagrams twice (same labelMode/config).
  - Assert the diagrams are bit-identical, including loop blocks and counts.

---

## Risk Coverage

(If a formal risk profile is later created, map IDs here such as `RISK-ST008-LOOP-OVERCOMPRESS`, `RISK-ST008-TRACE-EQUALITY`, etc.)

- Primary risks mitigated:
  - Over-compression hiding important differences between flows.
  - Non-deterministic loop behavior leading to flaky diagrams or dedup keys.
  - Incorrect grouping causing confusing or misleading diagrams for complex traces.

---

## Recommended Execution Order

1. **P1 Unit tests**:
   - ST-008-UNIT-001, ST-008-UNIT-002, ST-008-UNIT-003
   - ST-008-UNIT-004, ST-008-UNIT-005
   - ST-008-UNIT-008, ST-008-UNIT-009

2. **P1 Integration tests**:
   - ST-008-INT-002, ST-008-INT-003

3. **P2 Unit tests**:
   - ST-008-UNIT-006, ST-008-UNIT-007

Given the library nature of DiagramTool, this order provides fast feedback from core logic tests before running heavier integration scenarios with realistic traces.

---

## Gate YAML Block (for future QA gate use)

```yaml
test_design:
  scenarios_total: 10
  by_level:
    unit: 7
    integration: 3
    e2e: 0
  by_priority:
    p0: 0
    p1: 6
    p2: 4
    p3: 0
  coverage_gaps: []  # All AC-08.1–AC-08.4 have at least one scenario
```

## Trace References

- Test design matrix: `docs/qa/assessments/st.008-test-design-20251210.md`  
- P0 tests identified: 0 (no direct revenue/compliance/security impact; core quality focus is P1)
