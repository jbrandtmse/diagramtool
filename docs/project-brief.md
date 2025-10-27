# Project Brief — MALIB.Util.DiagramTool (ObjectScript)

Summary
- Build an ObjectScript utility class library that generates Mermaid sequence diagrams from IRIS Interoperability trace sessions.
- Input: Session spec (single, ranges, and lists), e.g., "1,5-9,12".
- Output: One sequence diagram per session returned as a string; can also write to a file; also echo to terminal.
- Scope: Class library only (no UI) for developer documentation of Interoperability solutions.

Context
- Source data: Ens.MessageHeader (Ens.MessageHeader.cls / Ens.MessageHeaderBase.cls).
- Examples:
  - SQL: docs/sample.sql
  - Sample data CSV: docs/sampledata.csv
- Actors: SourceConfigName and TargetConfigName.
- Message type: MessageBodyClassName.
- Invocation semantics:
  - Inproc: synchronous request/response; response implied by order (TimeCreated), reversed Source/Target; may also have CorrespondingMessageId.
  - Queue: queued (potentially async) with correlation via CorrespondingMessageId and/or ReturnQueueName.
- One diagram per session; deduplicate identical diagrams across sessions in combined output.

Why This Matters
- Architectural documentation for Interoperability is often manual and error-prone.
- This tool programmatically renders accurate sequence diagrams directly from trace data, improving speed, consistency, and maintainability.

Goals
- Provide a clear API to:
  - Accept session spec string (single IDs, ranges, lists).
  - Generate Mermaid sequence diagrams for each session.
  - Distinguish sync (Inproc) vs async/queued (Queue) interactions.
  - Detect request/response pairs and compress loops of repeated pairs.
  - Deduplicate identical diagrams across multiple sessions.
  - Return diagrams as text, with option to write to file and always echo to terminal.
- Follow .clinerules ObjectScript standards and best practices.

Non-Goals (MVP)
- No UI or visualization hosting.
- No advanced filtering beyond Ens.MessageHeader query and exclusion of HS.Util.Trace.Request per sample SQL.
- No enterprise packaging/release automation (beyond basic docs); ZPM packaging is optional and can be planned later.

Primary Users and Stakeholders
- IRIS developers and architects documenting Interoperability productions.
- Business Analysts and QA using diagrams for analysis and verification.
- Product/Architecture stakeholders who need reliable system interaction narratives.

Key Functional Requirements
- Input parsing:
  - Accept "1,5-9,12" format; expand to concrete session IDs.
- Data extraction:
  - Query Ens.MessageHeader by SessionId; exclude HS.Util.Trace.Request as per example.
  - Respect ordering by TimeCreated, ID to reflect causality.
- Diagram generation:
  - Participants from SourceConfigName/TargetConfigName.
  - Message label from MessageBodyClassName (short class name by default).
  - Arrows:
    - Sync (Inproc) → "->>"
    - Async/Queue → "-->>"
  - Correlation:
    - Inproc: response implied by order, reversed endpoints; CorrespondingMessageId may exist.
    - Queue: correlate via CorrespondingMessageId and/or ReturnQueueName.
  - Loop detection:
    - Compress contiguous repeated request/response pairs with same endpoints and labels into Mermaid loop blocks.
- Output handling:
  - Produce one Mermaid sequenceDiagram per session.
  - Deduplicate identical diagrams in combined output when multiple sessions are processed.
  - Return combined text, write optional file, and echo to terminal.

Non-Functional Requirements
- Compatibility: IRIS 2023.2+ (configurable).
- Performance: Handle typical production sessions with hundreds to a few thousand messages without prohibitive latency.
- Reliability: Deterministic ordering; robust handling of missing or partial correlation fields.
- Testability: Unit tests using %UnitTest, focused on parsing, correlation, and generation.

Assumptions and Constraints
- Use ObjectScript; follow .clinerules:
  - $$$ macros, %Status patterns, QUIT restrictions in try/catch, no underscores in parameter names, do not edit Storage.
- Data source availability in the target namespace (dev/test): Ens.MessageHeader must be accessible.
- Sample CSV exists for offline demonstration (no IRIS dependency).
- PRD is v4, sharded at docs/prd/ per .bmad-core/core-config.yaml.

Success Metrics
- Can generate a valid Mermaid sequence diagram for sample session 1584253 from CSV.
- Accurate sync vs async depiction based on Invocation and correlation fields.
- Correct loop detection on repeated request/response patterns.
- Deduplication eliminates duplicates across sessions reliably.

High-Level Approach
1) Parse session spec into concrete SessionIds.
2) For each SessionId:
   - Query Ens.MessageHeader (or load from CSV for demo).
   - Build ordered event list with participants, labels, invocation, and correlation fields.
   - Correlate requests to responses (Inproc vs Queue rules).
   - Emit Mermaid sequence diagram with participants + messages; compress loops if detected.
3) Concatenate per-session diagrams, with optional deduplication.
4) Return combined text; optionally write to a file; always echo to terminal.

Initial Risks
- Variations in Invocation values (case, spelling like "Inproc" vs "InProcess" vs "InProcess"?).
- Inconsistent or missing CorrespondingMessageId/ReturnQueueName in real data.
- TimeCreated granularity/format differences across environments.
- Participant names requiring Mermaid-safe identifiers.
- Large super-sessions vs sessions (ensure correct key dimension: SessionId vs SuperSession as needed).

Open Questions
- Should we include additional label info (e.g., Type column) on messages?
- Should we offer configuration to fully qualify class labels vs short names?
- Any production-specific exclusions beyond HS.Util.Trace.Request?
- Should we support SuperSession at MVP or defer?

Scope and Milestones
- Phase 0 — Planning (this brief + PRD v4 shards)
- Phase 1 — UX/Notation decisions (mermaid conventions, labels, loop style)
- Phase 2 — Story drafting (Scrum Master), refinement (PO)
- Phase 3 — Implementation (Dev), unit tests, demo via CSV
- Phase 4 — QA gate, risk analysis, test design
- Phase 5 — Packaging/readme polish (optional ZPM), release notes

Appendices
- Example SQL: docs/sample.sql
- Sample data CSV: docs/sampledata.csv
- Mermaid reference: https://mermaid.js.org/syntax/sequenceDiagram.html
- IRIS Interoperability reference: Ens.MessageHeader (recording trace metadata)
