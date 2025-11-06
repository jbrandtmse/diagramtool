# Story ST-003 — Correlation Rules (Inproc vs Queue, Warnings)

Status: Ready for Development
Epic/PRD: docs/prd.md (v4)
Shards:
- 20-functional-requirements.md (FR-06, FR-07, FR-09, FR-12)
- 40-data-sources-and-mapping.md
- 50-diagramming-rules.md
- 60-acceptance-criteria.md (AC-05, AC-06, AC-07, AC-09, AC-13)

Story
As an IRIS developer building sequence diagrams,
I need reliable request/response correlation for synchronous (Inproc) and queued (Queue) interactions,
so that arrows and message pairings reflect actual flow while handling ambiguity with best-effort warnings.

Business Value
- Produces accurate, trustable diagrams by pairing requests and responses correctly.
- Handles real-world ambiguity (missing/unknown fields) without failing runs, surfacing issues as visible comments.

Scope (Decisions-aligned)
- Invocation handling (strict recognition; case-insensitive):
  - Inproc (sync) → arrow ->>
  - Queue (async) → both legs async -->> (response always async regardless of its row Invocation)
  - Unknown Invocation: emit a "%%" warning and default to Sync (->>) for that message
- Inproc pairing:
  - Authoritative: forward-only scan, reversed Source/Target and Type="Response"
  - If CorrespondingMessageId present and matches, confirm the pairing
  - If CorrMsgId conflicts, emit "%%" warning and still use order-based reversed-endpoints pairing
- Queue pairing:
  - Primary correlation via CorrespondingMessageId
  - Fallback via ReturnQueueName only when reversed Source/Target relative to the request (response direction Dst → Src)
  - If neither present, or reversed-endpoints check fails, leave unpaired and emit a "%%" warning
- Emission:
  - Requests: Src → Dst with appropriate arrow
  - Responses: Dst → Src with appropriate arrow (always -->> for queued pairs)
  - Non-fatal issues are emitted as "%%" comments near relevant lines where feasible

Out of Scope (MVP)
- Loop detection (covered in ST-004).
- File output append-only behavior, divider comment, dedup ON by default, and label toggle details (covered in ST-005).
- SuperSession handling and CSV data modes.

Assumptions
- Rows have been filtered and deterministically ordered by ST-002 (TimeCreated then ID, or ID fallback).
- Label formatting policy (default full class name; labelMode toggle) is applied by the diagram builder.

Dependencies
- ST-002 provides ordered row sets per SessionId (SQL-only).
- ST-004 uses the correlated sequence to detect contiguous request/response repeats.
- ST-005 handles multi-session concatenation, append-only file writes, divider insertion, and dedup default ON.

Acceptance Criteria (mapped from PRD 60-acceptance-criteria.md)
AC-05 Invocation Handling (Strict Recognition)
- Given rows contain Invocation values with various casing
- When mapping arrow semantics
- Then "Inproc" → ->>, "Queue" → -->> (both legs for queued)
- And unknown Invocation values cause a "%%" warning and default to ->> for that message

AC-06 Inproc Correlation with Confirmation
- Given a sequence with Invocation="Inproc"
- When correlating request to response
- Then reversed Source/Target and Type="Response" are used with a forward scan
- And CorrMsgId (when present) confirms the match; if it conflicts, a "%%" warning is emitted and order-based pairing is still used

AC-07 Queued Correlation and Async Arrows
- Given queued interactions (Invocation="Queue")
- When correlating
- Then CorrMsgId is used as the primary key; ReturnQueueName as fallback
- And if neither is present, leave unpaired and emit a "%%" warning
- And both request and response arrows are async -->> for queued pairs

AC-09 Per-Session Diagram Structure (partial)
- Given correlation completes
- When emitting the per-session diagram
- Then arrows and directions reflect the mapping above
- And non-fatal issues are emitted as "%%" warning comments near relevant lines where feasible

AC-13 Error Handling and Best-Effort
- Given partial or missing correlation fields
- When generating diagrams
- Then best-effort output is produced without failing the run
- And a %Status is returned (no strict-mode failures)

Additional Test Cases
- Inproc sequence with conflicting CorrMsgId → pairing by reversed-endpoints and "%%" warning present
- Queued request without CorrMsgId but with ReturnQueueName → paired via ReturnQueueName
- Queued request with neither CorrMsgId nor ReturnQueueName → remains unpaired and "%%" warning present
- Unknown Invocation value (e.g., "ASYNCFAST") → "%%" warning and default to sync arrow for that message

Non-Functional References
- Determinism via ST-002 ordering (NFR-02).
- Best-effort warnings as "%%" comments (NFR-03).
- Testability via %UnitTest with given/when/then scenarios (NFR-05).

Tasks (Draft)
T1. Implement correlation function(s)
- Input: ordered rows (ID, Invocation, MessageBodyClassName, SessionId, SourceConfigName, TargetConfigName, ReturnQueueName, CorrespondingMessageId, TimeCreated, Type)
- Output: correlated event list (pairs and singletons) with assigned arrow directions

T2. Inproc correlation logic
- Forward-only scan; reversed endpoints + Type="Response"
- Confirm with CorrMsgId when present; conflict → "%%" warning + keep order-based pairing
- Unpaired Responses: emit standalone Response event with a "%%" warning (best-effort visibility)

T3. Queue correlation logic
- Primary CorrMsgId
- Fallback ReturnQueueName only if reversed Source/Target match the request (response direction Dst → Src); else treat as unpaired
- None present or reversed-endpoints check fails → leave unpaired + "%%" warning
- Both legs for queued pairs must be async -->> arrows

T4. Unknown Invocation handling
- Emit "%%" warning and default to sync (->>) for that message

T5. Unit Tests (%UnitTest)
- Cover AC-05/06/07 and Additional Test Cases
- Validate arrow mapping, pairing correctness, and warning presence

T6. Documentation
- Note correlation precedence, defaulting behavior, and warning strategy with examples

## Implementation Target and Contract
IMPORTANT: Developers must read docs/dev-notes-correlation.md before implementing ST-003. This document records the chosen policies, event schema, and algorithmic guidance required for development and testing.
- Class: MALIB.Util.DiagramTool
- Methods (proposed):
  - ClassMethod CorrelateEvents(pRows As %DynamicArray, Output pEvents As %DynamicArray) As %Status
    - Input: ordered rows from ST-002
    - Behavior: Forward-only scan; for each request, pair a response per rules; map arrow based on Invocation; attach inline '%%' warnings for non-fatal issues; emit standalone Inproc responses with a '%%' warning when no matching request is found; preserve event order for emission.
    - Output: pEvents as %DynamicArray of event objects (see schema below)
    - Return: %Status; best-effort (non-fatal conditions → warnings, not failures)
  - ClassMethod PairInproc(pRows As %DynamicArray, Output pPairs As %DynamicArray) As %Status
    - Behavior: Reverse Src/Dst and require Type="Response"; confirm with CorrespondingMessageId when present; on conflict, emit '%%' and still use order-based pairing.
  - ClassMethod PairQueued(pRows As %DynamicArray, Output pPairs As %DynamicArray) As %Status
    - Behavior: Correlate by CorrespondingMessageId; fallback to ReturnQueueName only when reversed Source/Target match; otherwise leave unpaired; warn on fallback/no-match.
  - ClassMethod ArrowForInvocation(pInvocation As %String) As %String
    - Returns '->>' for Inproc; '-->>' for Queue; unknown values: emit '%%' warning and default to '->>'.

## Correlated Event Schema
- EventType: 'Request' | 'Response' | 'Warning'
- Src: %String (SourceConfigName)
- Dst: %String (TargetConfigName)
- Label: %String (default = full MessageBodyClassName; builder may toggle)
- Arrow: '->>' | '-->>'
- Invocation: %String (preserve original value)
- ID: %Integer
- PairWithID: %Integer or '' (for responses referencing request ID)
- CorrespondingMessageId: %Integer or ''
- ReturnQueueName: %String or ''
- SessionId: %Integer
- Notes: %String (optional; inline '%%' warning text)
- PairId: %Integer or '' (optional; stable identifier for tests)

## Anchored References
- FR-06 Invocation → Arrow: docs/prd/20-functional-requirements.md#fr-06-invocation--arrow-semantics-strict-recognition
- FR-07 Request/Response Correlation: docs/prd/20-functional-requirements.md#fr-07-requestresponse-correlation
- Diagramming rules (arrows): docs/prd/50-diagramming-rules.md#5-arrow-semantics-invocation--arrow
- AC-05 Invocation Handling: docs/prd/60-acceptance-criteria.md#ac-05-invocation-handling-strict-recognition
- AC-06 Inproc Correlation: docs/prd/60-acceptance-criteria.md#ac-06-inproc-correlation-with-confirmation
- AC-07 Queued Correlation: docs/prd/60-acceptance-criteria.md#ac-07-queued-correlation-and-async-arrows
- AC-09 Per-Session Structure: docs/prd/60-acceptance-criteria.md#ac-09-per-session-diagram-structure
- AC-13 Error Handling: docs/prd/60-acceptance-criteria.md#ac-13-error-handling-and-best-effort

## Key Files to Modify
- src/MALIB/Util/DiagramTool.cls — add correlation methods and arrow mapping
- src/MALIB/Test/DiagramToolTest.cls — add tests for AC-05/06/07 and edge cases (unknown invocation, CorrMsgId conflict, unpaired queued response)
- docs/readme/dev-notes (optional) — short note on correlation precedence, defaulting, and warnings

## Testing
- Framework: IRIS %UnitTest (tests under src/MALIB/Test/)
- AC mapping: cover AC-05 (Invocation), AC-06 (Inproc correlation), AC-07 (Queued correlation); also validate directionality (AC-09) and best-effort/warnings (AC-13)
- Data: use deterministic ordered rows from ST-002 (prefer seeded/controlled data; avoid wall-clock dependencies)
- Standards: use $$$ macros (AssertEquals, AssertTrue, AssertStatusOK); implement %OnNew(initvalue) correctly when extending %UnitTest.TestCase; test methods begin with "Test"
- Execution: assert event arrows, pairings, and warning Notes; verify forward-only scan behavior

## Special Testing Considerations
- Use deterministic, ordered rows from ST-002.
- Arrow semantics: Inproc responses use ->>; queued pairs use -->> on both legs.
- Forward-only scan: construct sequences that require the first valid candidate to match.
- Emit and assert warnings for: unknown Invocation, standalone Inproc responses without a matching request, CorrMsgId conflicts (Inproc), queued responses with neither CorrMsgId nor ReturnQueueName.

Definition of Ready
- FR/NFR shards stable; ST-002 ordering in place.

Definition of Done
- All ACs met with passing %UnitTest.
- Warnings appear as "%%" comments near relevant emission points.
- Story marked Ready for PO review and QA design.

Change Log
- v0.1 Draft created and aligned with finalized decisions.
