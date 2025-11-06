# PRD v4 Shard — 20 Functional Requirements: MALIB.Util.DiagramTool

Status: Draft v4
Owner: PM (BMad)
Related: ../prd.md, 00-overview.md, 30-non-functional-requirements.md, 40-data-sources-and-mapping.md, 50-diagramming-rules.md, 60-acceptance-criteria.md

FR-01 Session Spec Parsing
- Accept a session selector string supporting:
  - Single IDs: "1584253"
  - Ranges: "5-9"
  - Lists: "1,5-9,12"
- Whitespace-insensitive. Invalid tokens are ignored.
- Expanded into concrete SessionIds (integers).

FR-02 Data Source and Filtering (SQL-only)
- Source: Ens.MessageHeader (SQL only; CSV/demo mode is not supported in MVP).
- Required columns: ID, Invocation, MessageBodyClassName, SessionId, SourceConfigName, TargetConfigName, ReturnQueueName, CorrespondingMessageId, TimeCreated, Type
- Filter out rows with MessageBodyClassName = "HS.Util.Trace.Request".
- Scope limited to SessionId (SuperSession out-of-scope at MVP).

FR-03 Ordering and Determinism
- Order rows by TimeCreated, then ID for deterministic sequencing.
- If TimeCreated ordering isn’t available in target IRIS version, fallback to ORDER BY ID only.
- Downstream logic (correlation and loop detection) expects deterministic order.

FR-04 Actor/Participant Extraction
- Actors are derived from SourceConfigName and TargetConfigName.
- Declare each actor once per diagram in the order of first appearance.
- Participant identifiers must be Mermaid-safe; original names preserved as labels.
- Identifier collisions resolved by numeric suffix (_2, _3, …); no truncation applied.

FR-05 Message Labeling (Default = Full Class Name + Toggle)
- Default label: Full MessageBodyClassName including package (e.g., HS.Util.Trace.Request).
- Sanitize label for Mermaid if necessary (replace/remove invalid characters).
- Runtime toggle labelMode=full|short (default=full). Short = last segment after ".".

FR-06 Invocation → Arrow Semantics (Strict Recognition)
- Recognized values (case-insensitive): "Inproc" (sync), "Queue" (async).
- Unknown Invocation values: emit a warning (%% comment) and default to Sync behavior.
- Arrow mapping:
  - Inproc: ->>
  - Queue: both legs (request and response) always async -->> regardless of response row Invocation.

FR-07 Request/Response Correlation
- Inproc:
  - Response is implied by order; match reversed Source/Target with Type="Response".
  - If CorrespondingMessageId is present and matches, confirm pairing.
  - If CorrespondingMessageId conflicts, emit a warning and still use order-based pairing.
- Queue:
  - Prefer CorrespondingMessageId to correlate response to the original request.
  - Fallback to ReturnQueueName only when reversed Source/Target relative to the request (response direction Dst → Src).
  - If neither is available, or the reversed-endpoints check fails, leave unpaired and emit a warning.
- Correlation proceeds forward-only through the ordered list (no backtracking).

FR-08 Loop Detection and Compression
- Identify contiguous repeated request/response pairs with identical signature:
  - Signature includes Req(Src, Dst, Label) + Resp(Src, Dst, Label).
- When count > 1, compress into:
  - loop N times <Label>
    - Req message
    - Resp message
  - end
- Do not compress if pairs are interrupted by other messages.

FR-09 Per-Session Diagram Generation
- One Mermaid sequenceDiagram per SessionId.
- Each diagram includes:
  - Header: "sequenceDiagram"
  - Comment with SessionId (e.g., "%% Session 1584253")
  - Participant declarations (unique, ordered by first appearance)
  - Message lines emitted in sequence using arrow mapping
  - Loop blocks when applicable
  - Non-fatal issues are emitted as "%%" comments where feasible.

FR-10 Multi-Session Runs and Deduplication
- When multiple sessions are requested, generate diagrams for each SessionId.
- Deduplication: ON by default.
  - Compute stable hash per diagram; include unique diagrams only.
  - Silent deduplication (no summary of removed SessionIds).

FR-11 Output Contract (Append-Only)
- Return combined diagram text to the caller and echo to terminal/stdout.
- If an output file path is provided, append to the file (append-only).
- Always write a divider comment (e.g., "%% ---") between diagrams when appending.
- Maintain a blank line between diagrams in the combined text result.

FR-12 Error Handling and Warnings
- Best-effort by default; do not fail on unknown Invocation or correlation ambiguities.
- Emit non-fatal warnings as "%%" comments in the output where feasible.
- Return a %Status for programmatic callers (OK or error) without strict-mode failures.

FR-13 SuperSession Handling (Out of Scope)
- SuperSession roll-up is out of scope for MVP.
- Always one diagram per SessionId.

FR-14 Configuration (MVP-Level)
- labelMode runtime toggle (full|short), default=full.
- Deduplication default: ON.
- Append-only file output with divider comment.
- No CSV/alternate data modes in MVP.

User Flows

UF-01 Single Session (Inproc-dominant)
- Input: "1584253"
- Query and order rows; correlate Inproc pairs with reversed endpoints (confirm with CorrMsgId if present).
- Output: One valid Mermaid sequenceDiagram; warnings as %% comments if needed.

UF-02 Queued Correlation
- Input: "1593849"
- Correlate responses using CorrespondingMessageId primarily; fallback to ReturnQueueName; else leave unpaired and warn.
- Emit async arrows on both legs for queued pairs.

UF-03 Multi-Session with Dedup
- Input: "1584253,1593849"
- Build both diagrams; if identical, include only one (dedup ON by default, silent).
- Append to output file with divider comment if a file path is provided.

Out-of-Scope Confirmations (MVP)
- SuperSession composition
- UI/visualization layer
- CSV or non-SQL data modes
- Strict mode failures (warnings instead)

Traceability
- Supports Overview goals (00-overview.md §4) and is validated via Acceptance Criteria (60-acceptance-criteria.md).
