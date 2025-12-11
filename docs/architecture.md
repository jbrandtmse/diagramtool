# Architecture Overview — MALIB.Util.DiagramTool

Status: Draft v4  
Owner: Architecture  
Related: docs/prd.md (v4 shards), docs/stories/story-003-correlation-rules.md, docs/dev-notes-correlation.md, docs/stories/story-005-output-and-dedup.md, docs/stories/story-006-orchestration-and-entrypoint.md, docs/stories/story-007-participant-ordering-by-first-appearance.md, docs/stories/story-008-episode-based-loop-compression.md

## Purpose

- Document the system context and engineering standards used by the DiagramTool library.
- Provide stable references for developers and QA (testing standards, source tree conventions, coding standards, tech stack, and story-level behaviors).
- Clarify how ST-001..ST-008 fit together into a single, deterministic pipeline from trace data to Mermaid diagrams and append-only files.

## System Context

- A library (no UI) that generates Mermaid `sequenceDiagram` diagrams from IRIS Interoperability trace sessions (`Ens.MessageHeader`).
- Input: **Session selector string** (single IDs, ranges, lists) parsed to a set of `SessionId` values.
- Public orchestration entrypoint (ST-006):

  ```objectscript
  ClassMethod GenerateDiagrams(
      pSelector As %String,
      pOutFile As %String = "",
      pLabelMode As %String = "full",
      pDedupOn As %Boolean = 1,
      Output pText As %String
  ) As %Status
  ```

  This wires together parsing, loading, correlation, loop detection, and output/dedup according to the PRD.

### Processing Pipeline (stories ST-001..ST-008)

1. **ST-001 — Session Spec Parsing**
   - Class: `MALIB.Util.DiagramTool.SessionSpec`
   - Responsibility: Parse selector string into a `%List` of positive integer `SessionId` values.
   - Facade: `MALIB.Util.DiagramTool.ParseSessionSpec`.

2. **ST-002 — Data Load & Deterministic Ordering (SQL-only)**
   - Class: `MALIB.Util.DiagramTool.Loader`
   - Responsibility: Load `Ens.MessageHeader` rows for a single SessionId.
   - Contract:
     - Filter out `MessageBodyClassName = "HS.Util.Trace.Request"`.
     - Default ordering: `ORDER BY TimeCreated, ID`.
     - Fallback ordering: `ORDER BY ID` when requested or when primary ordering is unavailable.
   - Facade: `MALIB.Util.DiagramTool.LoadHeadersForSession`.

3. **ST-003 — Correlation Rules (Inproc vs Queue, Warnings)**
   - Class: `MALIB.Util.DiagramTool.Correlation`
   - Responsibility: Map ordered rows into a correlated **event list** with arrows and warnings.
   - Key points:
     - Forward-only scan over ordered rows from ST-002.
     - Inproc and Queue correlation rules, including `CorrespondingMessageId` and `ReturnQueueName` fallback.
     - Non-fatal anomalies recorded in `Notes` as human-readable warning text.

4. **ST-004 — Loop Detection (Contiguous Identical Pairs)**
   - Class: `MALIB.Util.DiagramTool.Output`
   - Responsibility: Compress contiguous identical request/response pairs into Mermaid `loop` blocks.
   - Input: Correlated events from ST-003.
   - Output: A new event sequence where repeated pairs are replaced by synthetic `Loop` events.

5. **ST-005 — Output (Append-only, Divider), Dedup (Default ON), Warnings, Label Toggle**
   - Class: `MALIB.Util.DiagramTool.Output` (and facades in `MALIB.Util.DiagramTool`)
   - Responsibilities:
     - Turn per-session events into Mermaid `sequenceDiagram` text.
     - Render warnings as inline `%%` comments near affected lines.
     - Support runtime label mode toggle (`full` vs `short`).
     - Manage append-only file output and cross-session deduplication.

6. **ST-006 — Orchestration & Entrypoint**
   - Class: `MALIB.Util.DiagramTool`
   - Responsibility: Orchestrate ST-001..ST-005 for one or more sessions and provide a single public API (`GenerateDiagrams`) for callers.

7. **ST-007 — Participant Ordering by First Appearance**
   - Class: `MALIB.Util.DiagramTool.Output`
   - Responsibility: Derive the set of participants from the correlated/loop-compressed event stream and declare them in **order of first appearance** per session.
   - Notes:
     - Participants are derived from event endpoints (Src/Dst or loop Req*/Resp* endpoints).
     - Order is per-session and independent across sessions.
     - LabelMode affects only message/loop labels, not participant identifiers/labels.

8. **ST-008 — Episode-Based Loop Compression**
   - Classes:
     - `MALIB.Util.DiagramTool.Output`
     - `MALIB.Util.DiagramTool.Episode`
     - `MALIB.Util.DiagramTool.EpisodeBlock`
   - Responsibility: Build higher-level **episodes** from the ST-004 loop-compressed event stream, compute **business-only episode signatures**, and compress contiguous identical episodes into episode-level Mermaid `loop N times` blocks.
   - Policy:
     - Episode signatures ignore trace/log events (e.g. `HS.Util.Trace.*`), which are still rendered inside the episode.
     - Only **contiguous** runs of identical episode signatures are compressed.
     - Episode-based loops are additive and layered on top of ST-004 pair-level loops.

## Key Decisions (aligned with PRD v4)

### Invocation and Arrows (ST-003)

- **Invocation handling (strict)**:
  - `Inproc` → synchronous arrow `->>`.
  - `Queue` → asynchronous arrow `-->>` on both legs of the pair.
  - Case-insensitive recognition; numeric Enum values (1=Queue, 2=Inproc) are normalized.
- **Queue fallback policy**:
  - `CorrespondingMessageId` is the primary correlation key.
  - `ReturnQueueName` fallback is used only when:
    - Endpoints are reversed (response direction Dst → Src), and
    - The `ReturnQueueName` matches between request and response.
  - Otherwise, the response remains unpaired and a warning is emitted.

### Warnings and Best-Effort Behavior (ST-003, ST-005)

- Best-effort philosophy:
  - Do **not** fail the run for ambiguous or missing data.
  - Instead, emit non-fatal warnings as `%%` comments where feasible.
- Warning sources:
  - Unknown Invocation → default to `->>` with `"Warning: Unknown Invocation ...; defaulting to sync (->>)"`.
  - Inproc CorrMsgId conflict → `"Warning: CorrMsgId conflict between ReqID=... and RespID=...; using order-based pairing"`.
  - Unpaired queued request → `"Warning: Unpaired queued request at ID=...; missing or unmatched CorrMsgId/ReturnQueueName"`.
- Rendering:
  - Warnings are stored on events as `Notes` and rendered by ST-005 as **Mermaid comments**:
    - `%% <warning text>`
  - Output places warnings **adjacent** to the related message lines, after participants but before the specific arrow.

### Loop Compression (ST-004)

- Loop signature:
  - Request: `(Src, Dst, Label, Arrow)`
  - Response: `(Src, Dst, Label, Arrow)`
- Detection:
  - Strictly contiguous regions of identical Request/Response pairs (same signature) with `N > 1`.
  - Interruption by a different event signature ends the region.
- Emission:
  - Compressed as:

    ```mermaid
    loop N times <Label>
      <Req line>
      <Resp line>
    end
    ```

  - Arrow semantics (Inproc vs Queue) preserved from correlation.

### Participants and Ordering (ST-007)

- Source of truth:
  - Participants are derived from the correlated/loop-compressed event stream (ST-003 + ST-004).
  - Endpoints used:
    - For non-loop events: `Src` and `Dst`.
    - For pair-level loop events: `ReqSrc`, `ReqDst`, `RespSrc`, `RespDst`.
- Ordering:
  - Per session, participants are declared **once** in order of first appearance in the final event stream.
  - Multi-session runs maintain independent participant ordering per session.
- Independence from labelMode:
  - Participant identifiers and labels are unaffected by labelMode; labelMode only influences message and loop labels.

### Episode-Based Loop Compression (ST-008)

- Episode model:
  - Episodes are represented by `MALIB.Util.DiagramTool.Episode` objects containing:
    - An ordered `%DynamicArray` of events.
    - Business-only `Signature` and `RepLabel` fields.
    - A `Compressible` flag indicating eligibility for episode-level loops.
- Signature semantics:
  - Episode signatures are computed only from **business events**:
    - Per-event fragments: `Src | Arrow | Dst | Label(full) | Invocation | EventType`.
    - Trace/log events (e.g. `HS.Util.Trace.*`) are excluded from the signature but kept in the episode body for rendering.
  - Two episodes are equal when their business-event fragment sequences are identical.
- Compression:
  - The ordered list of episodes is scanned for **contiguous runs** of episodes with:
    - Matching signatures.
    - `Compressible=1`.
  - For runs with `N > 1`, a `MALIB.Util.DiagramTool.EpisodeBlock` is created with:
    - `Type="LOOP"`, `LoopCount=N`, and a canonical `Episode`.
  - The canonical episode’s full body (including trace/log events) is rendered once inside a Mermaid `loop N times <label>` block.
- Relationship to pair-level loops:
  - Episode-based loops are applied **after** ST-004 pair-level loop compression.
  - Pair-level loops remain intact and are rendered inside episodes as needed.

### Labels and Label Mode (ST-005)

- Default label:
  - Full `MessageBodyClassName`, including package, sanitized for Mermaid.
- Runtime label modes:
  - `labelMode="full"` (default):
    - Labels use the full class name: e.g. `My.App.RequestClass`.
  - `labelMode="short"`:
    - Labels use only the trailing segment after the last `"."`: e.g. `RequestClass`.
- Implementation:
  - `MALIB.Util.DiagramTool.Output.NormalizeLabelForMode` and `LabelForEvent` centralize label-mode handling.
  - `GenerateDiagrams` normalizes `pLabelMode` to `"full"` or `"short"`.

### Output, Append-Only, and Dividers (ST-005, ST-006)

- Per-session output:
  - `BuildDiagramForSession` produces:

    ```text
    sequenceDiagram
    %% Session <id>
    participant ...
    ...
    ```

  - Participants are always declared before any message lines or warnings.
- Append-only semantics:
  - Files passed via `pOutFile` are **never** truncated.
  - ST-005’s `AppendDiagramsToFile`:
    - Detects if the target file is empty or not.
    - For a non-empty file:
      - Writes `%% ---` **before** the first appended diagram in the call.
    - For subsequent diagrams within the same call:
      - Writes `%% ---` between each diagram block.
    - Always writes a trailing newline after each diagram block to maintain at least one blank line in the combined text view.

### Deduplication (ST-005, ST-006)

- Default behavior:
  - Deduplication is **ON by default** for multi-session runs (`pDedupOn=1`).
  - Only **unique** diagrams should appear in the combined text result.
- Normalized dedup key:
  - Implemented by `MALIB.Util.DiagramTool.DiagramDedupKey`.
  - Logic:
    - Locate the header line `%% Session <id>` and normalize it to `%% Session <dedup>`.
    - Keep the rest of the diagram text unchanged.
  - Consequences:
    - Diagrams from different SessionIds that are otherwise identical are considered duplicates and kept once.
    - Near-duplicates (even small textual differences) produce different keys and are **not** collapsed.
- Collision protection:
  - Dedup uses a CRC-based hash over the normalized key but also **compares the normalized text** to guard against hash collisions before skipping diagrams.

### Determinism and Idempotence

- Determinism (NFR-02):
  - Given the same underlying data and selector, the pipeline (ST-001..ST-006) produces the same diagrams and normalized dedup keys.
- Idempotence:
  - With `pDedupOn=1`, re-running `GenerateDiagrams` with the same selectors and data will not create logically duplicate diagram content in `pText`.
  - File append behavior is deterministic: prior content is preserved and `%% ---` dividers clearly separate runs.

## Testing Standards (summary)

- Framework: InterSystems IRIS `%UnitTest` (tests live under `src/MALIB/Test/`).
- Assertions:
  - Use `$$$AssertEquals`, `$$$AssertTrue`, `$$$AssertStatusOK`, etc.
- `%OnNew` requirement:
  - Classes extending `%UnitTest.TestCase` implement:

    ```objectscript
    Method %OnNew(initvalue As %String = "") As %Status
    {
        Quit ##super(initvalue)
    }
    ```

- Determinism:
  - Tests must not depend on wall-clock time; data is seeded deterministically.
- Method names:
  - Test methods start with `Test` and are kept small and focused.

### Story-Level Test Coverage

- ST-001:
  - `MALIB.Test.DiagramToolSessionSpecTest` — selector parsing.
- ST-002:
  - `MALIB.Test.DiagramToolLoaderTest` — load/filter/order behavior.
- ST-003:
  - `MALIB.Test.DiagramToolCorrelationTest` — arrow mapping, pairing, and warnings.
- ST-004 / ST-005:
  - `MALIB.Test.DiagramToolOutputTest` — loop compression, output structure, warnings placement, dedup behavior, label modes.
- ST-006:
  - `MALIB.Test.DiagramToolTest` — orchestration (`GenerateDiagrams`) including:
    - Single-session diagrams.
    - Empty-session diagrams.
    - Multi-session dedup ON/OFF semantics.
    - Append-only file contract and divider insertion.
    - Short-label behavior via `pLabelMode`.
- ST-007:
  - `MALIB.Test.DiagramToolOutputTest` — participant ordering by first appearance (single- and multi-session) and independence from labelMode.
- ST-008:
  - `MALIB.Test.DiagramToolOutputTest` — episode grouping, trace-insensitive episode signatures, episode-based loop compression, and determinism of episode loops.

## Reference Documents

- Coding Standards: `docs/architecture/coding-standards.md`
- Tech Stack: `docs/architecture/tech-stack.md`
- Source Tree: `docs/architecture/source-tree.md`

## Traceability

- PRD Functional: `docs/prd/20-functional-requirements.md`
- Data Mapping: `docs/prd/40-data-sources-and-mapping.md`
- Diagramming Rules: `docs/prd/50-diagramming-rules.md`
- Acceptance Criteria: `docs/prd/60-acceptance-criteria.md`
- Story ST-003: `docs/stories/story-003-correlation-rules.md`  
  (IMPORTANT: Devs must also read `docs/dev-notes-correlation.md`.)
- Story ST-005: `docs/stories/story-005-output-and-dedup.md`  
  (Defines label modes, dedup defaults, warning placement, and append-only/divider contract.)
- Story ST-006: `docs/stories/story-006-orchestration-and-entrypoint.md`  
  (Defines `GenerateDiagrams` as the public API and wiring across all stories.)
- Story ST-007: `docs/stories/story-007-participant-ordering-by-first-appearance.md`  
  (Defines participant ordering semantics and independence across sessions and label modes.)
- Story ST-008: `docs/stories/story-008-episode-based-loop-compression.md`  
  (Defines episode grouping, business-only episode signatures, and episode-based loop compression layered on top of ST-004.)

## Change Log

- v0.2 Documented ST-004 loop compression and ST-005 output/dedup/label/warning behavior; aligned with ST-006 orchestration and tests.
- v0.1 Initial architecture overview aligning with PRD v4 and ST-003 policy selections.
