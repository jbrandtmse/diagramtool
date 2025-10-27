# Story ST-003 — Correlation Rules (Inproc vs Queue, Warnings)

Status: Draft
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
  - Fallback via ReturnQueueName
  - If neither present, leave unpaired and emit a "%%" warning
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

T3. Queue correlation logic
- Primary CorrMsgId; fallback ReturnQueueName
- None present → leave unpaired + "%%" warning
- Both legs for queued pairs must be async -->> arrows

T4. Unknown Invocation handling
- Emit "%%" warning and default to sync (->>) for that message

T5. Unit Tests (%UnitTest)
- Cover AC-05/06/07 and Additional Test Cases
- Validate arrow mapping, pairing correctness, and warning presence

T6. Documentation
- Note correlation precedence, defaulting behavior, and warning strategy with examples

Definition of Ready
- FR/NFR shards stable; ST-002 ordering in place.

Definition of Done
- All ACs met with passing %UnitTest.
- Warnings appear as "%%" comments near relevant emission points.
- Story marked Ready for PO review and QA design.

Change Log
- v0.1 Draft created and aligned with finalized decisions.
