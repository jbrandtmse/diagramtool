# Dev Notes — Correlation Rules and Warnings (ST-003)

Status: Draft (supporting doc for Story ST-003)
Related: docs/stories/story-003-correlation-rules.md, docs/stories/story-002-data-load-and-ordering.md

Purpose
- Provide a developer-facing guide for implementing request/response correlation and warning strategy.
- Align implementation details with PRD shards and Acceptance Criteria.
- Reduce ambiguity by documenting algorithmic steps, event schema, and test guidance.

Policy Decisions (Chosen)
- Queue fallback requires reversed endpoints match on ReturnQueueName; otherwise treat as unpaired with warning.
- Unpaired Inproc responses are emitted as standalone Response events with a warning.

Dependencies and Inputs
- Requires deterministic, ordered rows from ST-002:
  - Primary ordering: TimeCreated, then ID
  - Fallback: ID only
- Input row fields: ID, Invocation, MessageBodyClassName, SessionId, SourceConfigName, TargetConfigName, ReturnQueueName, CorrespondingMessageId, TimeCreated, Type

Arrow Mapping (Invocation → Mermaid)
- Inproc (sync) → ->>
- Queue (async) → -->> (both request and response legs are async for queued pairs)
- Unknown Invocation → emit a “%%” warning and default to sync (->>) for that message

Event Schema (for downstream emission and tests)
- EventType: "Request" | "Response" | "Warning"
- Src: %String (SourceConfigName)
- Dst: %String (TargetConfigName)
- Label: %String (default = full MessageBodyClassName; builder may toggle later)
- Arrow: "->>" | "-->>"
- Invocation: %String (preserve original value)
- ID: %Integer
- PairWithID: %Integer or "" (Response references its Request ID)
- CorrespondingMessageId: %Integer or ""
- ReturnQueueName: %String or ""
- SessionId: %Integer
- Notes: %String (optional; inline “%%” warning text)
- PairId: %Integer or "" (optional; stable identifier for paired events, useful for loop detection)

Recommended Public Methods (in MALIB.Util.DiagramTool)
- ClassMethod CorrelateEvents(pRows As %DynamicArray, Output pEvents As %DynamicArray) As %Status
  - Forward-only scan; produce event list; attach “%%” warnings via Notes
- ClassMethod PairInproc(pRows As %DynamicArray, Output pPairs As %DynamicArray) As %Status
  - Reverse Src/Dst for Response; confirm with CorrMsgId; warn on conflicts
- ClassMethod PairQueued(pRows As %DynamicArray, Output pPairs As %DynamicArray) As %Status
  - Primary: CorrespondingMessageId; Fallback: ReturnQueueName only when reversed endpoints match request; warn if unpaired
- ClassMethod ArrowForInvocation(pInvocation As %String) As %String
  - Returns "->>" for Inproc, "-->>" for Queue, default "->>" with warning for unknown

Algorithm — Inproc Correlation (Synchronous)
- For each Request row r where Invocation ~ "Inproc" (case-insensitive) and Type="Request":
  1) Scan forward for the first candidate response c where:
     - c.Type = "Response"
     - c.SourceConfigName = r.TargetConfigName
     - c.TargetConfigName = r.SourceConfigName
  2) If r or c has CorrespondingMessageId:
     - If present and matches expected (commonly c.CorrespondingMessageId = r.ID), treat as confirmed
     - If present but conflicts (c.CorrespondingMessageId ≠ r.ID), emit warning but still use order-based reversed-endpoints pairing
  3) Emit two events:
     - Request: r.Src ->> r.Dst with Label from MessageBodyClassName
     - Response: c.Src ->> c.Dst with Arrow "->>"
  4) Unknown Invocation on r or c:
     - Map to "->>" and append a warning to Notes indicating defaulting behavior
- Notes:
  - Maintain forward-only scan; do not backtrack
  - Each response should be paired at most once

Algorithm — Queued Correlation (Asynchronous)
- For each Request row r where Invocation ~ "Queue" and Type="Request":
  1) Arrow for request is "-->>"
  2) Identify response c by (in order of preference):
     - Primary: c.CorrespondingMessageId = r.ID
     - Fallback: c.ReturnQueueName = r.ReturnQueueName (when CorrMsgId is missing) AND reversed endpoints (c.Source = r.Target AND c.Target = r.Source)
     - Ensure c.Type="Response"
  3) When paired:
     - Emit response event with Arrow "-->>" (both legs async)
  4) If neither CorrMsgId nor ReturnQueueName (with reversed endpoints) produces a match:
     - Leave request as unpaired; emit a warning indicating unpaired queued response
- Direction:
  - Response direction reverses Src/Dst relative to the request (same as sync) but arrow is always "-->>" for queued pairs

Unknown Invocation Handling
- If Invocation ∉ {"Inproc","Queue"} (case-insensitive):
  - Emit “%%” warning: Unknown Invocation '<value>' at ID=<ID>; defaulting to sync (->>)
  - Use "->>" for that message

Warning Emission Strategy (as inline comments downstream)
- Unknown Invocation value
- Inproc CorrMsgId conflict (present but mismatched) — still use order-based reversed-endpoints pairing
- Queued request with no matching response when both CorrMsgId and ReturnQueueName are null or unhelpful
- Minimal format suggestions (added to Notes; downstream builder can render as “%% …”):
  - Unknown Invocation: "Warning: Unknown Invocation '<val>' at ID=<ID>; defaulting to sync (->>)"
  - CorrMsgId conflict: "Warning: CorrMsgId conflict between ReqID=<rid> and RespID=<cid>; using order-based pairing"
  - Unpaired queued: "Warning: Unpaired queued request at ID=<rid>; missing CorrMsgId/ReturnQueueName"

Pseudocode Outline (CorrelateEvents)
- Initialize pEvents = []
- For i from 1 to pRows.Count():
  - r = pRows.GetAt(i)
  - If r.Type="Request":
    - arrowReq = ArrowForInvocation(r.Invocation)
    - Append Request event (EventType="Request", Arrow=arrowReq, etc.)
    - If r.Invocation ~ "Inproc":
      - Find next response c by reversed endpoints, Type="Response"
      - Check CorrMsgId: confirm or warn-on-conflict
      - Append Response event (Arrow="->>")
    - ElseIf r.Invocation ~ "Queue":
      - Try find c by CorrMsgId; else by ReturnQueueName when reversed endpoints match
      - If found: Append Response event (Arrow="-->>")
      - Else: Append warning via Notes on request (unpaired)
    - Else:
      - Append warning to Request event (unknown Invocation defaulted)
  - ElseIf r.Type="Response" and not already paired:
    - Optionally append as singleton Response (best-effort) or ignore based on design choice (ST-003 permits best-effort)
- Return $$$OK

Testing Guidance (maps to ACs)
- AC-05 (Invocation handling):
  - Variants "inproc", "QUEUE", and an unknown value (e.g., "ASYNCFAST")
  - Assert arrows and warnings per mapping
- AC-06 (Inproc correlation):
  - Request followed by correct reversed-endpoint response
  - CorrMsgId present and matching → confirmation case
  - CorrMsgId conflict → warning but still order-based pairing
- AC-07 (Queued correlation):
  - Response matched via CorrespondingMessageId
  - Response matched via ReturnQueueName when CorrMsgId missing AND reversed endpoints match
  - No CorrMsgId or ReturnQueueName → unpaired with warning
  - Both legs async "-->>"
- AC-09 (Per-session structure — partial for correlation):
  - Verify final event list aligns with directionality; warnings included in Notes
- NFR-02 Determinism:
  - Multiple runs produce identical pEvents given identical pRows

Examples (Conceptual)
- Inproc pair:
  - Req: A -> B (HS.Message.FooRequest) → ->>
  - Resp: B -> A (HS.Message.FooResponse) → ->>
- Queue pair:
  - Req: A -->> B (HS.Message.FooRequest)
  - Resp: B -->> A (HS.Message.FooResponse)
- Unknown Invocation:
  - Emit "%% Warning: Unknown Invocation 'ASYNCFAST' at ID=999; defaulting to sync (->>)" on the relevant event

Anchored References
- FR-06 Invocation → Arrow: docs/prd/20-functional-requirements.md#fr-06-invocation--arrow-semantics-strict-recognition
- FR-07 Request/Response Correlation: docs/prd/20-functional-requirements.md#fr-07-requestresponse-correlation
- Diagramming rules (arrows/direction/warnings): docs/prd/50-diagramming-rules.md#5-arrow-semantics-invocation--arrow
- AC-05: docs/prd/60-acceptance-criteria.md#ac-05-invocation-handling-strict-recognition
- AC-06: docs/prd/60-acceptance-criteria.md#ac-06-inproc-correlation-with-confirmation
- AC-07: docs/prd/60-acceptance-criteria.md#ac-07-queued-correlation-and-async-arrows
- AC-09: docs/prd/60-acceptance-criteria.md#ac-09-per-session-diagram-structure
- AC-13: docs/prd/60-acceptance-criteria.md#ac-13-error-handling-and-best-effort
