# diagramtool

A library for generating Mermaid `sequenceDiagram` text from InterSystems IRIS Interoperability traces (`Ens.MessageHeader`) and writing the results to append-only files.  

The core implementation lives under `src/MALIB/Util/DiagramTool*` with tests under `src/MALIB/Test/`.

---

## What the project does

Given one or more IRIS trace sessions:

1. Parse a **session selector string** (single IDs, ranges, lists).
2. Load ordered `Ens.MessageHeader` rows for each SessionId (SQL-only, read-only).
3. Correlate request/response pairs for **Inproc** and **Queue** interactions, emitting warnings for ambiguous cases.
4. Apply **loop compression** for contiguous identical request/response pairs.
5. Build per-session **Mermaid sequence diagrams** with participants, message arrows, and inline `%%` warnings.
6. Optionally **deduplicate identical diagrams** across sessions and **append** them to a file with `%% ---` dividers.

There is no UI; this is a backend library designed to feed documentation pipelines and automated tooling.

---

## Core ObjectScript API

### Orchestration entrypoint (ST-006)

```objectscript
ClassMethod GenerateDiagrams(
    pSelector As %String,
    pOutFile As %String = "",
    pLabelMode As %String = "full",
    pDedupOn As %Boolean = 1,
    Output pText As %String
) As %Status
```

- `pSelector`  
  Session selector string (e.g. `"9100003"`, `"9100003,9100004"`, `"9100001-9100005"`).  
  Parsed by `MALIB.Util.DiagramTool.ParseSessionSpec`.

- `pOutFile`  
  Optional file path. When non-empty:
  - Output is **appended** (never truncated).
  - Diagrams are separated with `%% ---` divider lines.
  - Prior content in the file is preserved.

- `pLabelMode`  
  - `"full"` (default): labels use the full `MessageBodyClassName` (including package).
  - `"short"`: labels use only the trailing segment after the last `"."` (e.g. `My.App.RequestClass` → `RequestClass`).

- `pDedupOn`  
  - `1` (default): multi-session runs **deduplicate** identical diagrams.
  - `0`: deduplication disabled; all diagrams are emitted.

- `pText`  
  Combined in-memory Mermaid text for all (deduplicated) diagrams, with a blank line between diagrams.

---

## Key behaviors by story

### ST-002 — Data Load & Deterministic Ordering (SQL-only)

Implements ordered, filtered reads from `Ens.MessageHeader` for a single SessionId.

- Class: `MALIB.Util.DiagramTool.Loader`
- Facade: `MALIB.Util.DiagramTool.LoadHeadersForSession(pSessionId, .pRows, pForceIdOnlyOrder)`
- Highlights:
  - Filters out `MessageBodyClassName = "HS.Util.Trace.Request"`.
  - Default ordering: `ORDER BY TimeCreated, ID`.
  - Fallback ordering: `ORDER BY ID` (deterministic) when requested or when primary ordering is unavailable.
  - Output: `%DynamicArray` of normalized row objects:
    - `ID, Invocation, MessageBodyClassName, SessionId, SourceConfigName, TargetConfigName, ReturnQueueName, CorrespondingMessageId, TimeCreated, Type`.

Usage example:

```objectscript
Set sid = 1584253
Set rows = ""

// Default ordering (TimeCreated, ID)
Set tSC = ##class(MALIB.Util.DiagramTool).LoadHeadersForSession(sid, .rows)

// Force ID-only ordering
Set tSC = ##class(MALIB.Util.DiagramTool).LoadHeadersForSession(sid, .rows, 1)

If $IsObject(rows) {
    Set n = rows.%Size()
    For i=0:1:n-1 {
        Set obj = rows.%Get(i)
        Write obj.%Get("ID"), " ", obj.%Get("TimeCreated"), !
    }
}
```

### ST-003 — Correlation Rules (Inproc vs Queue, Warnings)

Correlates request/response interactions for Inproc and Queue traces, producing an ordered **event list** for diagram emission.

- Class: `MALIB.Util.DiagramTool.Correlation`
- Facade methods:
  - `CorrelateEvents(pRows, .pEvents)`
  - `PairInproc(pRows, .pPairs)`
  - `PairQueued(pRows, .pPairs)`
  - `ArrowForInvocation(pInvocation)`

Key rules:
- Forward-only scan across ordered rows from ST-002.
- **Inproc**:
  - Response identified by reversed endpoints (`Src`/`Dst`) and `Type="Response"`.
  - `CorrespondingMessageId` confirms; conflicts emit `%%` warnings but still pair by order.
- **Queue**:
  - `CorrespondingMessageId` is primary correlation key.
  - `ReturnQueueName` is fallback only when reversed endpoints match the request (response direction Dst → Src).
  - Both legs of a queued pair use async arrow `-->>`.
- **Unknown Invocation**:
  - Emits `%%` warning and defaults to sync arrow `->>`.

Warnings are stored in the event `Notes` field and later rendered by the output layer as `%%` comments near the related lines.

### ST-004 — Loop Detection (Contiguous Identical Pairs)

Compresses contiguous sequences of identical request/response pairs into Mermaid `loop` blocks.

- Class: `MALIB.Util.DiagramTool.Output`
- Method: `ApplyLoopCompression(pEvents, .pOutEvents)`

Behavior:
- Works over the correlated events from ST-003.
- Signature per pair:
  - Request: `(Src, Dst, Label, Arrow)`
  - Response: `(Src, Dst, Label, Arrow)`
- Contiguous repeated identical pairs with N>1 become:

```mermaid
loop N times <Label>
  <Req line>
  <Resp line>
end
```

- Interruption by a different signature ends the loop region.
- Inproc vs Queue semantics preserved by arrow choice (`->>` vs `-->>`).

### ST-005 — Output (Append-only, Divider), Dedup (Default ON), Warnings, Label Toggle

Responsible for final diagram text, warning placement, deduplication, and file append behavior.

Core pieces:

- `MALIB.Util.DiagramTool.Output.BuildDiagramForSession(pSessionId, pRows, pLabelMode, .pDiagram)`
  - Builds a single-session Mermaid `sequenceDiagram`:
    - Adds header and `%% Session <id>` comment.
    - Emits participants first.
    - Renders events and loops (from ST-004) as Mermaid lines.
    - Emits warnings as `%%` comments immediately before the related message line (using `Event.Notes`).

- `MALIB.Util.DiagramTool.Output.EmitEventLine(...)`
  - When `Notes` is set, writes a `%%` comment line (warning) and then the arrow line.

- `MALIB.Util.DiagramTool.Output.AppendDiagramsToFile(pOutFile, .pDiagMap)`
  - Opens/links to `pOutFile`.
  - Detects if the file already has content.
  - Appends diagrams from `pDiagMap` with:
    - `%% ---` divider before the first appended diagram **if the file is non-empty**.
    - `%% ---` divider between each subsequent diagram in the same call.
    - Trailing newline after each diagram block to maintain at least one blank line in the combined text.

- `MALIB.Util.DiagramTool.GenerateDiagrams(...)` (ST-006) + `DiagramDedupKey(...)`
  - Builds per-session diagrams and then:
    - If `pDedupOn=1` (default), computes a **normalized key** for each diagram via `DiagramDedupKey`:
      - Replaces the `%% Session <id>` header with `%% Session <dedup>`.
      - Leaves the rest of the text unchanged.
    - Uses the normalized key to deduplicate diagrams across sessions:
      - Only drops a diagram when an identical normalized key has already been seen.
      - Guards against hash collisions by comparing text before skipping.
    - Builds `pText` by concatenating diagrams with a **blank line** between them.
    - Calls `AppendDiagramsToFile` when `pOutFile` is non-empty.

Effects:
- **Labels**:
  - `pLabelMode="full"` → full `MessageBodyClassName` (including package).
  - `pLabelMode="short"` → final segment after `"."`.
- **Warnings**:
  - Rendered inline as `%%` comments adjacent to affected lines (from ST-003 correlation decisions).
- **Dedup**:
  - Default ON; only **unique diagrams** (normalized apart from session header) are emitted.
  - Near-duplicates (even slight differences) are preserved.
- **Append-only**:
  - Files are never truncated; new diagrams are appended with clear dividers.

### ST-006 — Orchestration and Entrypoint

`GenerateDiagrams` is the public entry that ties everything together:

1. Parse `pSelector` into SessionIds.
2. For each SessionId:
   - Load rows (`LoadHeadersForSession`).
   - Build per-session diagram (`BuildDiagramForSession`).
3. Deduplicate diagrams (if `pDedupOn=1`).
4. Build combined text with blank line separation.
5. Append to `pOutFile` (if provided) using ST-005’s append + divider semantics.
6. Echo combined text to the terminal (best-effort).

---

## Usage examples

### 1. Generate diagrams to the terminal only

```objectscript
Set selector = "9100001,9100002"
Set tText = ""
Set tSC = ##class(MALIB.Util.DiagramTool).GenerateDiagrams(selector, "", "full", 1, .tText)

If $$$ISERR(tSC) {
    Write "Error: "_$System.Status.GetErrorText(tSC), !
} Else {
    Write "Generated diagrams:", !!
    Write tText, !
}
```

### 2. Append diagrams to a file (short labels, dedup ON)

```objectscript
Set selector = "9100003-9100005"
Set outFile = "/tmp/diagramtool-output.mmd"
Set tText = ""

Set tSC = ##class(MALIB.Util.DiagramTool).GenerateDiagrams(selector, outFile, "short", 1, .tText)
If $$$ISERR(tSC) {
    Write "Error: "_$System.Status.GetErrorText(tSC), !
} Else {
    Write "Diagrams appended to: ", outFile, !
}
```

Notes:
- Re-running with the same inputs and `pDedupOn=1` will not duplicate identical diagrams; dedup is based on normalized text (session header ignored).
- Each run that appends content to an existing file will insert `%% ---` between old and new diagrams.

---

## Running tests

All tests use IRIS `%UnitTest` and live under `src/MALIB/Test/`.

Key test classes:

- `MALIB.Test.DiagramToolSessionSpecTest` — ST-001 (session selection parsing).
- `MALIB.Test.DiagramToolLoaderTest` — ST-002 (data load & ordering).
- `MALIB.Test.DiagramToolCorrelationTest` — ST-003 (correlation rules, arrows, warnings).
- `MALIB.Test.DiagramToolOutputTest` — ST-004 (loops) + ST-005 (output, dedup, labels, warnings).
- `MALIB.Test.DiagramToolTest` — ST-006 (orchestration end-to-end).

Example: run tests in an IRIS terminal:

```objectscript
Do ##class(%UnitTest.Manager).RunTest("MALIB.Test.DiagramToolOutputTest")
Do ##class(%UnitTest.Manager).RunTest("MALIB.Test.DiagramToolTest")
```

(If you are using MCP-based tooling, map these specs into your test runner configuration as shown in your environment.)

---

## Further documentation

- Architecture overview: `docs/architecture.md`
- Coding standards: `docs/architecture/coding-standards.md`
- Tech stack: `docs/architecture/tech-stack.md`
- Source tree: `docs/architecture/source-tree.md`
- Stories:
  - ST-001: `docs/stories/story-001-session-spec-parsing.md`
  - ST-002: `docs/stories/story-002-data-load-and-ordering.md`
  - ST-003: `docs/stories/story-003-correlation-rules.md`
  - ST-004: `docs/stories/story-004-loop-detection.md`
  - ST-005: `docs/stories/story-005-output-and-dedup.md`
  - ST-006: `docs/stories/story-006-orchestration-and-entrypoint.md`
