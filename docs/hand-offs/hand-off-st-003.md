# Developer Handoff — ST-003 Correlation Rules (Inproc vs Queue, Warnings)

Status: Ready for Development
Owner (handoff): Bob (Scrum Master)
Related Artifacts:
- Story: docs/stories/story-003-correlation-rules.md
- Dev Notes: docs/dev-notes-correlation.md
- PRD shards: 
  - docs/prd/20-functional-requirements.md#fr-06-invocation--arrow-semantics-strict-recognition
  - docs/prd/20-functional-requirements.md#fr-07-requestresponse-correlation
  - docs/prd/50-diagramming-rules.md#5-arrow-semantics-invocation--arrow
  - docs/prd/60-acceptance-criteria.md#ac-05-invocation-handling-strict-recognition
  - docs/prd/60-acceptance-criteria.md#ac-06-inproc-correlation-with-confirmation
  - docs/prd/60-acceptance-criteria.md#ac-07-queued-correlation-and-async-arrows
  - docs/prd/60-acceptance-criteria.md#ac-09-per-session-diagram-structure
  - docs/prd/60-acceptance-criteria.md#ac-13-error-handling-and-best-effort
- QA Gate: docs/qa/gates/st.003-correlation-rules.yml

IMPORTANT
- SM agent made no code changes. Code implementation is to be performed by the dev agent exclusively.
- ST-002 (loader) is Done and is the deterministic input for this story.

## 1) Goals and Scope

Implement reliable request/response correlation for:
- Inproc (sync) interactions
- Queue (async) interactions

With:
- Forward-only scan
- Arrow semantics per Invocation
- Best-effort non-fatal warnings (“%%” comments downstream) for ambiguities
- Deterministic behavior assuming ST-002 ordering

Out of scope (for this story):
- Loop detection (ST-004)
- Output file append/dedup/divider (ST-005)
- SuperSession roll-up
- CSV/alternate data modes

## 2) Inputs and Outputs

Input
- %DynamicArray pRows of row objects from ST-002 with fields:
  ID, Invocation, MessageBodyClassName, SessionId,
  SourceConfigName, TargetConfigName,
  ReturnQueueName, CorrespondingMessageId,
  TimeCreated, Type

Output
- %DynamicArray pEvents of “event” objects for downstream diagram emission

## 3) Implementation Target and Contract

Class: MALIB.Util.DiagramTool

Methods (implement or adjust per final design):
- ClassMethod ArrowForInvocation(pInvocation As %String = "") As %String
  - Returns "->>" for Inproc, "-->>" for Queue, default "->>" when unknown
- ClassMethod CorrelateEvents(pRows As %DynamicArray, Output pEvents As %DynamicArray) As %Status
  - Forward-only scan across requests; pair responses by rules; produce ordered events
- ClassMethod PairInproc(pRows As %DynamicArray, Output pPairs As %DynamicArray) As %Status
  - Helper for Inproc pair discovery (reversed endpoints + Type="Response"; CorrMsgId confirm/warn on conflict)
- ClassMethod PairQueued(pRows As %DynamicArray, Output pPairs As %DynamicArray) As %Status
  - Helper for Queue pair discovery (primary CorrMsgId; fallback ReturnQueueName; unpaired warns)

Reference design details and pseudocode are in docs/dev-notes-correlation.md.

## 4) Event Object Schema

For each emitted event (see Dev Notes for more detail):
- EventType: "Request" | "Response" | "Warning"
- Src, Dst: Source/TargetConfigName
- Label: MessageBodyClassName (full; downstream may toggle to short)
- Arrow: "->>" | "-->>"
- Invocation: preserved as-is
- ID: current row ID
- PairWithID: request ID for responses ("" for requests)
- CorrespondingMessageId: value or ""
- ReturnQueueName: value or ""
- SessionId: integer
- Notes: optional string containing warning text (rendered later as “%% …”)
- PairId: optional numeric grouping identifier for pair-related assertions

## 5) Correlation Rules

Inproc (sync)
- Request: Src -> Dst with "->>"
- Response: reverse direction (Dst -> Src) with "->>"
- Pairing: forward-only; match first Response with reversed Source/Target and Type="Response"
- CorrMsgId: if present and matches, confirm; if present and conflicts, emit warning but still use order-based pairing

Queue (async)
- Request: Src -->> Dst
- Response: Dst -->> Src (always async) when paired
- Pairing priority:
  1) CorrespondingMessageId (resp.CorrMsgId = req.ID)
  2) ReturnQueueName equality as fallback (consider reversed endpoints preference)
- If no match: leave unpaired and emit a warning

Unknown Invocation
- Emit warning and default arrow to sync "->>" for that message

## 6) Warning Strategy (attached to Notes for downstream “%%” emission)

- Unknown Invocation: "Warning: Unknown Invocation '<val>' at ID=<rid>; defaulting to sync (->>)"
- Inproc CorrMsgId conflict: "Warning: CorrMsgId conflict between ReqID=<rid> and RespID=<cid>; using order-based pairing"
- Unpaired queued request: "Warning: Unpaired queued request at ID=<rid>; missing or unmatched CorrMsgId/ReturnQueueName"

## 7) Test Plan (map to ACs)

Create/extend %UnitTest in src/MALIB/Test/DiagramToolTest.cls or a new test class targeting ST-003:

AC-05 Invocation Handling
- Inputs with "inproc", "QUEUE", and an unknown value (e.g., "ASYNCFAST")
- Assert arrow mapping and presence of unknown warning

AC-06 Inproc Correlation with Confirmation
- Sequence: Request (Inproc), Response with reversed endpoints
- Case A: matching CorrMsgId confirms
- Case B: conflicting CorrMsgId yields warning but still pairs by order

AC-07 Queued Correlation and Async Arrows
- Case A: CorrMsgId primary match
- Case B: ReturnQueueName fallback match
- Case C: Missing both → unpaired with warning
- Assert both legs async "-->>" when paired

AC-09 Per-Session Structure (partial for correlation)
- Validate event list directionality and ordering align with rules

AC-13 Error Handling and Best-Effort
- Validate no hard failures on partial data; warnings present and %Status OK

Additional edge tests
- Multiple candidates ahead; ensure forward-only first valid match is used
- Mixed invocation sequences
- Empty/degenerate inputs (0 events)

## 8) Files to Modify (Dev Agent)

- src/MALIB/Util/DiagramTool.cls — implement correlation methods (no SM edits)
- src/MALIB/Test/DiagramToolTest.cls — add ST-003 tests for AC-05/06/07 (+ edges)
- Optional: emitter enhancements later (ST-005) to surface Notes as “%%” comments inline

## 9) Deliverables & Definition of Done

- Code compiles with no warnings
- Unit tests added and pass for AC-05/06/07 (and related AC-09/13 behaviors)
- Deterministic behavior verified across runs (given ST-002 ordering)
- Warnings captured in event Notes for later “%%” emission
- QA Gate updated with status and evidence; reviewer sign-off

## 10) Notes/Constraints

- Forward-only scan; no backtracking
- Preserve Invocation string casing, but comparisons should be case-insensitive
- Do not modify storage sections in ObjectScript classes
- Use $$$ macros (triple $) and proper %Status patterns per project standards
- QUIT with arguments is not allowed inside Try/Catch; follow project’s QUIT/return guidance if used in tests/helpers

## 11) Open Questions (Dev to confirm if needed)

- For Queue fallback on ReturnQueueName: should we accept fallback when reversed endpoints do NOT match, or keep reversed endpoints as a preference/requirement? Current guidance prefers reversed endpoints when available; if not, safest is to require it. Confirm if a looser fallback is desired.
- Singleton responses (unpaired) for Inproc: should they be emitted as standalone Response events with best-effort or ignored? Current design allows best-effort; confirm desired behavior for MVP.
- Any constraints on maximum scan distance for pairing (e.g., stop scanning after N steps) for performance? Current design uses full forward scan.

## 12) Next Steps

- Dev implements methods/tests per above
- Run unit tests, update QA gate (docs/qa/gates/st.003-correlation-rules.yml) with results
- Prepare short developer README note if additional nuances arise
