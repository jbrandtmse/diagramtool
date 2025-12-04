# Test Design: Story st.005 — Output (Append-only, Divider), Dedup (Default ON), Warnings, Label Toggle

Date: 2025-12-03  
Designer: Quinn (Test Architect)

Source Story: `docs/stories/story-005-output-and-dedup.md`  

Related PRD Shards:
- FR-05, FR-10, FR-11, FR-12 — `docs/prd/20-functional-requirements.md`
- AC-04, AC-09, AC-10, AC-11, AC-13 — `docs/prd/60-acceptance-criteria.md`
- Diagramming rules (output/dedup/labels/warnings) — `docs/prd/50-diagramming-rules.md`

---

## Test Strategy Overview

Scope of this test design is **ST-005 output, deduplication, warnings, and label toggling** in the DiagramTool pipeline:

- **Input:**  
  - Per-session diagrams and correlated events produced after ST-001..ST-004:
    - ST-001: Session spec parsing
    - ST-002: SQL data loading and ordering
    - ST-003: correlation + warnings for ambiguous CorrMsgId / queues
    - ST-004: loop detection/compression
- **Logic under test (ST-005 responsibilities):**
  - Labeling and label mode toggle (`labelMode=full|short`).
  - Append-only file output semantics with divider `"%% ---"` and blank line separation.
  - Deduplication of identical per-session diagrams (default ON, silent).
  - Emission of non-fatal warnings as `%%` comments near relevant lines.
  - Best-effort behavior: warnings over failures, no strict-mode hard errors.
- **Output:**
  - Mermaid `sequenceDiagram` text, optionally written/append-only to a file path, with correct dividers, labeling, dedup behavior, and inline warnings.

Testing focus:
- Correct **label semantics** for full vs short modes (AC-04).
- Proper **placement and structure** of warnings as `%%` comments while preserving per-session diagram structure (AC-09).
- **Deduplication** of identical diagrams with stable hashing and no loss of genuinely distinct diagrams (AC-10).
- **Append-only file behavior** with stable dividers and text spacing (AC-11).
- **Best-effort error handling** where ambiguous correlation results in warnings but not hard failures, while maintaining determinism (AC-13, NFR-02, NFR-03, NFR-05).

Planned coverage summary:

- **Total test scenarios:** 9
- **By level:**
  - Unit: 8
  - Integration: 1
  - E2E: 0 (full pipeline E2E will be primarily exercised under ST-006 orchestration tests)
- **By priority:**
  - P0: 0 (no direct revenue/security/compliance risk)
  - P1: 5 (core behavior: labels, dedup ON default, append-only contract, primary warnings behavior)
  - P2: 4 (edge cases, robustness, determinism, and error/warning nuances)
  - P3: 0

Rationale:
- Behavior is mostly **pure logic + file I/O**, ideal for **unit tests** with one targeted **integration test**.
- These features are **core to readability and determinism** of artifacts but are not revenue/security critical → P1/P2 split.
- E2E coverage is deferred to **ST-006** where the orchestration entrypoint (`GenerateDiagrams`) will execute the full pipeline.

---

## Test Scenarios by Acceptance Criteria

### AC-04 — Labeling Defaults and Toggle

> **AC-04 Labeling Defaults and Toggle**  
> Given default settings, then labels are full class names; when `labelMode=short`, labels are the last segment after ".".

#### Scenarios

| ID              | Level | Priority | Test | Justification |
| --------------- | ----- | -------- | ---- | ------------- |
| st.005-UNIT-001 | Unit  | P1       | **Default label mode uses full class names**: With `labelMode` omitted or set to `full`, generate a diagram for messages with fully qualified body class names (e.g., `MALIB.Message.SomeRequest`). Assert that emitted labels for messages (and any derived labels) use the full class name, sanitized for Mermaid (e.g., replacing or escaping problematic characters) and that no short-form truncation occurs. | Core happy-path behavior for labeling; pure deterministic formatting logic; essential for readability and traceability in documentation pipelines. |
| st.005-UNIT-002 | Unit  | P1       | **Short label mode uses last segment**: With `labelMode=short`, generate a diagram for messages with fully qualified names and verify that all message labels use only the final segment after `"."` (e.g., `SomeRequest`), while preserving the same structure and participant declarations. Confirm that toggling between `full` and `short` only changes label text, not diagram structure. | Ensures switchable verbosity without structural side effects; directly tests the primary feature of `labelMode` and its impact on diagram readability. |

---

### AC-09 — Per-Session Structure (warnings as comments)

> **AC-09 Per-Session Structure (partial)**  
> Given a generated diagram, then participant declarations precede message lines; warnings appear as `"%%"` comments near relevant lines.

#### Scenarios

| ID              | Level | Priority | Test | Justification |
| --------------- | ----- | -------- | ---- | ------------- |
| st.005-UNIT-003 | Unit  | P1       | **Single warning near related message**: Construct a session that triggers a single non-fatal warning (e.g., unknown Invocation defaulted to sync). Generate the diagram and assert (1) that `sequenceDiagram` and participant lines appear first, (2) that a `%%` warning comment is emitted adjacent to the affected message (e.g., immediately before or after), and (3) that the overall session structure (participants, messages, optional loops from ST-004) remains valid Mermaid syntax. | Core requirement that warnings integrate cleanly into diagram structure without disrupting participant/message ordering; fundamental to AC-09. |
| st.005-UNIT-004 | Unit  | P2       | **Multiple warnings of different types**: Create a session exhibiting multiple warning conditions (e.g., Inproc CorrMsgId conflict, unpaired queued response, and unknown Invocation). Verify that each warning yields a distinct `%%` comment near the relevant lines and that the diagram remains syntactically valid and readable (no misplaced warnings before `sequenceDiagram`, no warnings splitting multi-line constructs like loops). | Covers robustness of warning placement in more complex scenarios; lower risk than basic single-warning behavior but important for resilience and readability. |

---

### AC-10 — Multi-Session Deduplication (Default ON)

> **AC-10 Multi-Session Deduplication (Default ON)**  
> Given two SessionIds that produce identical diagram text, when generating with default settings, then only one copy is included; no summary of removed SessionIds is emitted.

#### Scenarios

| ID              | Level | Priority | Test | Justification |
| --------------- | ----- | -------- | ---- | ------------- |
| st.005-UNIT-005 | Unit  | P1       | **Identical diagrams deduplicated**: Build two logical sessions (different SessionIds) that produce exactly the same diagram text after ST-001..ST-004 (same participants, messages, loops, warnings). Generate combined output with dedup **ON by default**. Assert that only one diagram block appears in the combined text (and, if writing to a file, only one diagram’s content per run), no explicit summary of removed SessionIds is present, and that the retained diagram is consistent across runs (stable hash determinism). | Directly tests core dedup requirement; ensures the default behavior is ON and that silent dedup removes redundant diagrams without affecting determinism. |
| st.005-UNIT-006 | Unit  | P2       | **Near-duplicates not deduplicated**: Build two sessions that differ minimally (e.g., a single additional message, different label, or different warning). Generate combined output and assert that **both** diagrams are present, and no unintended dedup occurs. | Guards against over-aggressive dedup that might collapse diagrams that are not strictly identical, preserving correctness of the documentation artifact. |

---

### AC-11 — Output Contract — Append-Only with Divider

> **AC-11 Output Contract — Append-Only with Divider**  
> Given a file path, when writing diagrams, then content is appended; a divider `"%% ---"` is written between diagrams; combined text has blank line separation.

#### Scenarios

| ID              | Level       | Priority | Test | Justification |
| --------------- | ----------- | -------- | ---- | ------------- |
| st.005-INT-001  | Integration | P1       | **Append-only, divider, and blank-line semantics**: Using a temporary file path, run the output pipeline twice (or more) with the same and/or different diagrams. Verify: (1) the file grows monotonically (no truncation), (2) between each appended diagram block there is exactly one `%% ---` divider line, (3) there is a blank line separation in the combined in-memory text result between diagrams, and (4) previously written content remains untouched. | Interacts with real file I/O and multi-diagram runs; validates the full contract of append-only and divider behavior as specified in AC-11 and Additional Test Cases (append-only idempotence). |

---

### AC-13 — Error Handling and Best-Effort

> **AC-13 Error Handling and Best-Effort**  
> Given ambiguous or missing correlation information, when generating output, then generation does not fail; warnings are emitted as `"%%"` comments; `%Status` indicates success or error without strict-mode failures.

#### Scenarios

| ID              | Level | Priority | Test | Justification |
| --------------- | ----- | -------- | ---- | ------------- |
| st.005-UNIT-007 | Unit  | P2       | **Ambiguous correlation best-effort behavior**: Create input that simulates ambiguous or missing correlation info (e.g., unpaired queued responses, missing CorrMsgId/ReturnQueueName) as surfaced from ST-003. Generate output and assert that: (1) the method returns a non-error %Status (or clearly non-fatal result), (2) diagrams are still generated for the affected sessions, and (3) corresponding `%%` warning comments appear, consistent with story assumptions and prior correlation behavior. | Confirms that ST-005 honors the best-effort, non-strict policy: ambiguous correlation issues result in warnings, not hard failures, supporting resilience (NFR-03). |
| st.005-UNIT-008 | Unit  | P2       | **Deterministic output with warnings and dedup**: For a multi-session input that includes both deduplicated and non-deduplicated diagrams plus warning conditions, run the generator multiple times and assert that combined text (and optional file contents) are bit-identical across runs, including warning placements and dedup decisions. | Validates determinism (NFR-02) even in the presence of warnings and dedup, ensuring diagrams are stable over time and tests remain reliable/repeatable. |

---

## Risk Coverage

Primary risks addressed:

- **R1 – Incorrect label semantics:**  
  - Labels not matching full vs short modes; sanitized incorrectly or inconsistently.
- **R2 – Warning placement breaks diagrams:**  
  - `%%` comments emitted in places that break Mermaid syntax or disrupt participant/message ordering.
- **R3 – Dedup removes non-identical diagrams or fails to remove true duplicates:**  
  - Incorrect hashing/equals semantics leading to loss of required diagrams or redundant duplication.
- **R4 – Output contract violations:**  
  - File content truncated/overwritten instead of appended, missing `%% ---` dividers, or incorrect blank line separation.
- **R5 – Non-deterministic or brittle behavior under warnings/ambiguity:**  
  - Same input yielding different output; ambiguous correlation causing errors instead of warnings.

Risk-to-test mapping (high level):

- **R1 →** st.005-UNIT-001, st.005-UNIT-002  
- **R2 →** st.005-UNIT-003, st.005-UNIT-004, st.005-UNIT-007  
- **R3 →** st.005-UNIT-005, st.005-UNIT-006  
- **R4 →** st.005-INT-001  
- **R5 →** st.005-UNIT-007, st.005-UNIT-008, st.005-UNIT-005 (dedup determinism aspect)

NFR alignment:
- **NFR-02 Determinism:** st.005-UNIT-005, st.005-UNIT-008  
- **NFR-03 Resilience:** st.005-UNIT-003, st.005-UNIT-004, st.005-UNIT-007  
- **NFR-05 Testability:** Overall strategy favors unit-level coverage with a single, focused integration test.

---

## Recommended Execution Order

1. **Unit P1 tests (fail fast on core behavior):**
   - st.005-UNIT-001 — Default label mode uses full class names  
   - st.005-UNIT-002 — Short label mode uses last segment  
   - st.005-UNIT-003 — Single warning near related message  
   - st.005-UNIT-005 — Identical diagrams deduplicated

2. **Integration P1 test:**
   - st.005-INT-001 — Append-only, divider, and blank-line semantics

3. **Unit P2 tests (edge cases, robustness, determinism):**
   - st.005-UNIT-004 — Multiple warnings of different types  
   - st.005-UNIT-006 — Near-duplicates not deduplicated  
   - st.005-UNIT-007 — Ambiguous correlation best-effort behavior  
   - st.005-UNIT-008 — Deterministic output with warnings and dedup

This ordering ensures that fundamental labeling, dedup, and output contract behavior is validated first, followed by more complex warning/ambiguity and determinism scenarios.

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
  coverage_gaps: []  # All ACs for ST-005 (AC-04, AC-09 partial, AC-10, AC-11, AC-13) have at least one scenario
```

---

## Trace References

For downstream QA tooling (e.g., trace-requirements):

```text
Test design matrix: docs/qa/assessments/st.005-test-design-20251203.md
P0 tests identified: 0
```

All scenarios above are **advisory but strongly recommended**: implementation teams may refine/add scenarios based on actual code structure, but this design provides a complete, risk-aware starting point aligned with PRD shards and Story ST-005.
