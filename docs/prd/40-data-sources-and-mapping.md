# PRD v4 Shard — 40 Data Sources and Mapping: MALIB.Util.DiagramTool

Status: Draft v4
Owner: PM (BMad)
Related: ../prd.md, 00-overview.md, 20-functional-requirements.md

1) Primary Data Source (SQL-only)
- InterSystems IRIS Interoperability trace metadata:
  - Table: Ens.MessageHeader
  - Classes: Ens.MessageHeader.cls / Ens.MessageHeaderBase.cls
- Access pattern: Read-only SQL (CSV or alternate data modes are out of scope for MVP)
- Session scoping: SessionId (one sequence diagram per SessionId)
- Exclusions: Filter out HS.Util.Trace.Request rows only

2) Canonical SQL
- Example pattern (ordering by TimeCreated then ID preferred):
  SELECT
    ID, Invocation, MessageBodyClassName, SessionId,
    SourceConfigName, TargetConfigName,
    ReturnQueueName, CorrespondingMessageId,
    TimeCreated, Type
  FROM Ens.MessageHeader
  WHERE SessionId = ?
    AND MessageBodyClassName <> 'HS.Util.Trace.Request'
  ORDER BY TimeCreated, ID;

- Fallback ordering (when TimeCreated sort not available): ORDER BY ID

3) Column Semantics
- ID (int)
  - Unique ID per message header row; used for deterministic tie-break ordering and queued correlation
- Invocation (string)
  - Recognized values: 'Inproc' (synchronous), 'Queue' (queued/async), case-insensitive
  - Unknown values: warn and default to synchronous semantics
- MessageBodyClassName (string)
  - Fully qualified class of the message body (e.g., HS.Message.PatientSearchRequest)
  - Default message label is the full class name; a runtime toggle can select short name (last segment)
- SessionId (int)
  - Trace session identifier; one diagram per SessionId
- SourceConfigName (string)
  - Ens actor on the source side (BusinessService/BusinessProcess/BusinessOperation)
- TargetConfigName (string)
  - Ens actor on the destination side
- ReturnQueueName (string or null)
  - Queue name for responses in queued flows; used as a correlation fallback
- CorrespondingMessageId (int or null)
  - Correlates a response to the original request (esp. queued flows)
- TimeCreated (date/time or string)
  - Event creation time; used for primary ordering and implied response sequencing in Inproc flows
- Type (string)
  - Typically 'Request' or 'Response'
  - Guides correlation and loop signature construction

4) Actor Mapping
- Mermaid participants:
  - Derived from SourceConfigName and TargetConfigName
  - First appearance order defines declaration order
- Sanitization:
  - Participant identifiers must be Mermaid-safe (alphanumeric + underscore)
  - Preserve original names as labels (quoted)
- Collision handling:
  - If sanitization collides, append numeric suffix (_2, _3, …); no truncation

5) Message Mapping
- Label:
  - Default: full MessageBodyClassName (including package), sanitized for Mermaid if necessary
  - Runtime toggle (labelMode=full|short, default=full): short = last segment of the class name
- Arrows (Invocation → Mermaid):
  - Inproc → '->>'
  - Queue → both legs (request and response) are async '-->>' regardless of the response row Invocation
- Type:
  - 'Request': drives outward leg
  - 'Response': drives return leg; direction reversed from request

6) Correlation Rules
- Inproc (synchronous)
  - Response is implied by order (TimeCreated, then ID) and reversing Source/Target with Type='Response'
  - If CorrespondingMessageId is present and matches, confirm the pairing
  - If CorrespondingMessageId conflicts, emit a warning and still use order-based pairing
- Queue (asynchronous/queued)
  - Prefer CorrespondingMessageId to match response to request
  - Fallback: ReturnQueueName equality when CorrespondingMessageId is missing
  - If neither present, leave unpaired and emit a warning
  - Maintain directionality and timing: response may arrive later; continue forward scan

7) Loop Detection Inputs
- Loop signature for contiguous repeated pairs:
  - Req: (Src, Dst, Label)
  - Resp: (Src, Dst, Label)
- When multiple adjacent pairs share the same signature, compress into:
  loop N times <Label>
    Req line
    Resp line
  end

8) Ordering and Determinism
- Primary ordering: TimeCreated, then ID
- Fallback: ORDER BY ID when TimeCreated cannot be used
- The ordered event list drives:
  - Inproc correlation (implied response)
  - Loop detection (contiguity check)
- Determinism:
  - Identical inputs must produce identical outputs (stable participant order, stable message emission)

9) Output and Warnings
- Multi-session: produce one diagram per SessionId; deduplication ON by default and silent
- File writes: append-only; always insert a divider comment between diagrams (e.g., '%% ---')
- Warnings (non-fatal conditions like unknown Invocation, CorrMsgId conflicts, or unpaired queued responses) are emitted as Mermaid '%%' comments inline where feasible

10) Edge Cases and Variants
- Invocation variants: only 'Inproc' and 'Queue' are recognized (case-insensitive); unknown values warn and default to sync
- Missing correlation fields (CorrespondingMessageId/ReturnQueueName): proceed best-effort and warn if queued response cannot be paired
- Empty sessions (after filter): emit a minimal Mermaid diagram with a helpful note
- SuperSession:
  - Out-of-scope for MVP; ignore unless scope changes
- Non-ASCII participant labels:
  - Preserve in label; sanitize only the participant identifier

11) Data Volume Considerations
- No explicit MVP targets; aim for practical performance
- Memory: linear to number of rows in session
- One forward scan for correlation and loop detection

12) Data Quality and Validation
- Validate essential fields (ID, SessionId, Source/Target, MessageBodyClassName, Type) where feasible
- Emit '%%' warnings when correlation falls back or is skipped
- Avoid throwing on partial data; return best-effort diagrams

Traceability
- Maps to FR-02 (Data Source), FR-03 (Ordering), FR-04 (Actors), FR-05 (Labels), FR-06 (Arrows), FR-07 (Correlation), FR-08 (Loops), FR-09 (Per-session), FR-10/11 (Dedup + append-only)
- Aligns with NFR-02 (Determinism), NFR-03 (Resilience), NFR-05 (Testability)
