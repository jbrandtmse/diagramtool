# PRD v4 Shard — 50 Diagramming Rules (Mermaid): MALIB.Util.DiagramTool

Status: Draft v4
Owner: PM (BMad)
Related: ../prd.md, 00-overview.md, 20-functional-requirements.md, 40-data-sources-and-mapping.md

1) Mermaid Primer (Sequence Diagrams)
- Each diagram starts with:
  sequenceDiagram
- Participants (actors) are declared once:
  participant <id> as "<label>"
- Messages are emitted in order with arrows
- Comments use:
  %% Comment here

Reference: https://mermaid.js.org/syntax/sequenceDiagram.html

2) Participants (Actors)
- Source of truth: first appearance of SourceConfigName and TargetConfigName in ordered rows
- Declaration order: order-of-first-appearance in the session
- Identifier vs Label:
  - Identifier (<id>): Mermaid-safe (see Sanitization)
  - Label: Original config name (quoted)
- Example:
  participant MA_CEN_IHE_XDSb_Query_Process as "MA.CEN.IHE.XDSb.Query.Process"

3) Sanitization Rules (Identifiers)
- Allowed: [A-Z][a-z][0-9] and underscore (_)
- Replace any other character with underscore (_)
- Identifiers must be unique. On collision, append numeric suffix: _2, _3, …
- Labels preserve original names (quoted). No truncation of identifiers or labels.

4) Message Labels (Default = Full Class Name, Toggle supported)
- Base format:
  <srcId> <arrow> <dstId>: <Label>
- Default label: full MessageBodyClassName (including package), sanitized for Mermaid if needed
  - Example: HS.Message.PatientSearchRequest → "HS.Message.PatientSearchRequest"
- Runtime toggle labelMode=full|short (default=full)
  - short = last segment after "." (e.g., PatientSearchRequest)

5) Arrow Semantics (Invocation → Arrow)
- Recognized (case-insensitive): Inproc (sync), Queue (async)
- Mapping:
  - Inproc: ->>
  - Queue: both request and response arrows are async -->> (response always async regardless of its row Invocation)
- Unknown Invocation values: emit a warning via "%%" and default to Inproc (sync) behavior for that message

6) Request/Response Direction
- Requests: Src → Dst using Invocation-mapped arrow
- Responses:
  - Inproc: Dst → Src (reverse of request direction), arrow ->>
  - Queue: Dst → Src (reverse), arrow always -->> for queued pairs

7) Loop Compression
- Definition: Contiguous pairs of request/response with identical signature
  Signature includes Req(Src, Dst, Label) and Resp(Src, Dst, Label)
- When repeated N>1 times, compress:
  loop N times <Label>
    <Req line>
    <Resp line>
  end
- Do not compress if pairs are interrupted by other messages

8) Comments, Warnings, and Session Header
- Optional header to annotate session:
  %% Session <SessionId>
- Non-fatal warnings (e.g., unknown Invocation, conflicting CorrespondingMessageId, unpaired queued response) should be emitted as "%%" comments near the relevant lines where feasible
- When writing multiple diagrams to a file, insert a divider:
  %% ---

9) Deduplication (Multi-Session Runs)
- When multiple sessions are requested, diagrams may be identical
- Compute stable hash of the full diagram text
- Deduplication is ON by default; only output unique diagrams
- Silent deduplication: do not emit a summary of removed SessionIds

10) Minimal Diagram on Empty Data
- If a session yields no rows after filtering, emit:
  sequenceDiagram
  %% Session <SessionId>
  %% No data available (filtered or empty)
- Rationale: valid Mermaid output is always produced

11) Examples

Example A — Synchronous (Inproc) with full class labels
sequenceDiagram
%% Session 1584253
participant MA_CEN_IHE_XDSb_Query_Process as "MA.CEN.IHE.XDSb.Query.Process"
participant MA_CEN_Registry_Patient_Manager_IG as "MA.CEN.Registry.Patient.Manager.IG"
MA_CEN_IHE_XDSb_Query_Process ->> MA_CEN_Registry_Patient_Manager_IG: HS.Message.PatientSearchRequest
MA_CEN_Registry_Patient_Manager_IG ->> MA_CEN_IHE_XDSb_Query_Process: MA.Message.PatientSearchResponse

Example B — Queued pair (both legs async -->>) correlated via CorrMsgId
sequenceDiagram
%% Session 1593849
participant MA_CEN_Registry_Patient_Manager_IG as "MA.CEN.Registry.Patient.Manager.IG"
participant MA_CEN_EMPI_ManagerV2 as "MA.CEN.EMPI.ManagerV2"
MA_CEN_Registry_Patient_Manager_IG -->> MA_CEN_EMPI_ManagerV2: HS.Message.AddUpdateHubRequest
MA_CEN_EMPI_ManagerV2 -->> MA_CEN_Registry_Patient_Manager_IG: HS.Message.AddUpdateHubResponse

Example C — Loop Compression (Contiguous Identical Pairs)
sequenceDiagram
%% Session 1584253
participant A as "MA.QHIN.IHE.XCPD.InitiatingGateway.Process"
participant B as "MA.QHIN.IHE.XCPD.InitiatingGateway.Operations"
loop 3 times HS.Message.PatientSearchRequest
A -->> B: HS.Message.PatientSearchRequest
B -->> A: HS.Message.PatientSearchResponse
end

Example D — Warning comment (unknown Invocation defaulted to sync)
sequenceDiagram
%% Session 123
participant X as "Service.X"
participant Y as "Process.Y"
%% Warning: Unknown Invocation 'ASYNCFAST' at ID=999; defaulting to sync (->>)
X ->> Y: HS.Message.SomeRequest

12) Edge Handling
- Non-ASCII in labels: allowed; only identifiers are sanitized
- Missing Source/Target:
  - If either side is blank, skip message or emit a "%%" note, preferring best-effort output over failure
- Ties on TimeCreated:
  - Break ties by ID to maintain determinism

13) Formatting Consistency and File Appends
- Maintain a blank line between diagrams in the combined text result
- On file output, use append-only and add "%% ---" divider between diagrams
- Keep comments concise; avoid flooding the diagram with metadata

Traceability
- FR-04 (Actors), FR-05 (Labels), FR-06 (Arrows), FR-08 (Loops), FR-09 (Per-session), FR-10 (Dedup), FR-11 (Append-only)
- Aligns with NFR-02 (Determinism) and NFR-03 (Resilience)
