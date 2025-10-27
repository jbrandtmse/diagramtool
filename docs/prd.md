# Product Requirements Document (PRD) v4 — MALIB.Util.DiagramTool

Status: Draft
Owner: PM (BMad) • Version: v4 • Sharded: yes (docs/prd/)
Related: docs/project-brief.md

Product Summary
- Build an ObjectScript utility class library that generates Mermaid sequence diagrams from IRIS Interoperability trace sessions (Ens.MessageHeader).
- Input: Session specification string (single IDs, ranges, lists) e.g., "1,5-9,12".
- Output: One diagram per session returned as text; echo to terminal; append to file with a divider comment when a path is provided.
- Scope: Utility class library (no UI) to help developers document Interoperability solutions.
- SQL-only: Data is read from Ens.MessageHeader via SQL (CSV or alternate data modes are out of scope for MVP).

Decisions (Finalized)
- Labels:
  - Default label is full MessageBodyClassName (including package), sanitized for Mermaid where necessary.
  - Runtime toggle labelMode=full|short (default=full). short uses the last segment after '.'.
- Invocation handling:
  - Recognized (case-insensitive): Inproc (sync) and Queue (async).
  - Unknown Invocation values: emit a "%%" warning and default to sync behavior (->>).
- Arrow semantics:
  - Inproc: ->>
  - Queue: both legs (request and response) are async -->> (response always async regardless of the response row Invocation).
- Correlation:
  - Inproc: forward-scan, reversed Source/Target with Type="Response"; CorrespondingMessageId confirms if present; if it conflicts, warn and still use order-based pairing.
  - Queue: CorrespondingMessageId primary; ReturnQueueName fallback; if neither, leave unpaired and emit a warning.
- Exclusions:
  - Exclude HS.Util.Trace.Request only (no configurable exclude list in MVP).
- SuperSession:
  - Out of scope. Always one diagram per SessionId.
- Participants/Identifiers:
  - Sanitize identifiers to Mermaid-safe; preserve original names as labels; if collisions occur, append numeric suffix (_2, _3, …). No truncation limits.
- Output format:
  - Append-only file writes; always add a divider comment (%% ---) between diagrams; dedup ON by default; silent (no summary of removed SessionIds); blank line separation in combined text.
- Warnings:
  - Emit non-fatal warnings as "%%" comments in the output/near the relevant lines; best-effort only (no strict-mode failures).
- Packaging/Performance:
  - ZPM packaging deferred.
  - No explicit MVP performance targets or CI memory bounds.

Non-Goals (MVP)
- No UI or hosted visualization.
- No CSV or alternate data modes (SQL-only).
- No SuperSession roll-up (one diagram per SessionId).
- No strict-mode failures (best-effort with %% warnings).
- No ZPM packaging in MVP (deferred).

Shard Index (docs/prd)
- 00-overview.md — Problem, Goals, Non-Goals, Personas, Success Metrics, Decisions
- 20-functional-requirements.md — Functional requirements and detailed behavior (updated to SQL-only, labelMode toggle, strict invocation, queued both-leg async, append-only, warnings, dedup ON)
- 30-non-functional-requirements.md — Performance, reliability, compatibility, testability (best-effort warnings, no strict/perf/mem bounds)
- 40-data-sources-and-mapping.md — Ens.MessageHeader mapping, ordering, strict invocation, correlation, identifiers, output
- 50-diagramming-rules.md — Mermaid conventions, label defaults, arrows, loop compression, warnings, divider, dedup
- 60-acceptance-criteria.md — Given/When/Then AC reflecting final decisions (SQL-only, labelMode, strict invocation, queued both-leg async, append-only + divider, warnings)
- 70-risks-issues.md — Risks, assumptions, mitigations (strict invocation/warnings, silent dedup)
- 80-milestones.md — Phases, deliverables, target sequencing (docs-first; removed CSV texts)
- 90-open-questions.md — Resolved in shards; retained for history (decisions captured in shards)

Implementation Guidance Snapshot (see shards for details)
- Actors = SourceConfigName, TargetConfigName (sanitized IDs; original labels preserved).
- Message label default = full MessageBodyClassName; labelMode runtime toggle supports short last-segment.
- Invocation: strict recognition: Inproc ->>, Queue -->> (both legs).
- Correlation:
  - Inproc: order + reversed endpoints; CorrMsgId confirms, conflict warns but still use order.
  - Queue: CorrMsgId → ReturnQueueName; if neither present, unpaired + warn.
- Loop detection: compress contiguous request/response identical signature pairs into loop blocks.
- Output: append-only; divider comment (%% ---) between diagrams; dedup ON and silent; warnings as %% comments.

References
- Example SQL: docs/sample.sql
- Mermaid: https://mermaid.js.org/syntax/sequenceDiagram.html
- IRIS Interoperability: Ens.MessageHeader (Ens.MessageHeader.cls / Ens.MessageHeaderBase.cls)

Change Log
- v4 (Draft): PRD and shards updated to reflect finalized decisions (SQL-only, label defaults/toggle, strict invocation, queued both-leg async, correlation rules, append-only output with divider, warnings, dedup ON, no CSV or strict-mode).
