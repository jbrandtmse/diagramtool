# PRD v4 Shard — 00 Overview: MALIB.Util.DiagramTool

Status: Draft v4
Owner: PM (BMad)
Related: ../prd.md, ../project-brief.md

1. Problem Statement
Manually documenting IRIS Interoperability message flows is slow, error-prone, and often diverges from reality. Teams frequently rely on screenshots or hand-crafted diagrams that quickly go stale. We need a reliable way to generate sequence diagrams directly from Ens.MessageHeader traces so documentation stays accurate, repeatable, and fast.

2. Product Summary
MALIB.Util.DiagramTool is an ObjectScript utility class library that:
- Reads IRIS Interoperability traces from Ens.MessageHeader by SessionId (SQL-only)
- Produces Mermaid sequence diagrams (one diagram per session)
- Uses full class names for message labels by default (MessageBodyClassName), with a runtime toggle for short names
- Enforces strict Invocation handling (Inproc/Queue only); unknown values warn and default to sync
- Treats queued pairs as async on both legs (-->>)
- Correlates requests/responses with clear rules (Inproc confirmation by order; Queue by CorrespondingMessageId → ReturnQueueName)
- Compresses repeated request/response pairs into loop blocks
- Deduplicates identical diagrams across sessions (ON by default, silent)
- Appends to output files with a divider comment (%% ---) and emits warnings as %% comments

Scope: Back-end utility library only (no UI)

3. Why Now
- Interoperability solutions are increasingly complex; trace-driven documentation reduces cognitive load and errors
- Mermaid adoption is widespread and integrates easily with docs/markdown pipelines
- Improves onboarding, debugging, audits, and compliance documentation

4. Goals
- Generate accurate Mermaid sequence diagrams from Ens.MessageHeader traces
- Support session spec input (single, range, list): “1,5-9,12”
- Default label = full MessageBodyClassName; runtime toggle labelMode=full|short
- Strict Invocation recognition (Inproc/Queue only); unknown values → %% warning + default to sync
- Queued correlation and arrows: CorrMsgId → ReturnQueueName; both legs async (-->>); unpaired ⇒ %% warning
- Inproc correlation: reversed endpoints + order; CorrMsgId confirms; conflicts warn but still use order
- Loop detection: compress contiguous repeated request/response pairs
- Dedup identical diagrams (ON, silent)
- Append-only file output with %% divider and blank line separation in combined text
- Emit non-fatal warnings as %% comments near relevant lines

5. Non-Goals (MVP)
- No UI or hosted visualization
- No CSV or alternate data modes (SQL-only)
- No SuperSession rollup (one diagram per SessionId)
- No strict-mode failures (best-effort with %% warnings)
- No ZPM packaging in MVP (deferred)

6. Primary Personas
- IRIS Developers: need ground-truth sequence diagrams for design and debugging
- System Architects: maintain accurate architecture documentation at scale
- Business Analysts: communicate flows to stakeholders clearly
- QA/Test Architects: correlate tests with message interactions and risk areas
- PM/PO: verify that delivered flows match PRD and acceptance criteria

7. Success Metrics (MVP)
- Generates valid diagrams for representative sessions
- Correct strict Invocation handling and queued/Inproc correlation behavior
- Loop compression reduces long repeated patterns without losing clarity
- Deduplication removes duplicate diagrams silently
- Append-only file writes with visible divider comments
- Warnings are visible in output via %% comments

8. Constraints and Assumptions
- IRIS 2023.2+ target
- SQL-only from Ens.MessageHeader (no CSV)
- Follow .clinerules:
  - Use $$$ macros, %Status patterns; QUIT-in-try/catch restrictions
  - No underscores in parameter names
  - Do not edit Storage sections
- Best-effort behavior: never fail runs due to unknown Invocation or correlation ambiguities; emit %% warnings

9. Data Sources and Artifacts
- Ens.MessageHeader (Ens.MessageHeader.cls / Ens.MessageHeaderBase.cls)
- Example SQL: ../sample.sql
- Mermaid docs: https://mermaid.js.org/syntax/sequenceDiagram.html

10. Key Terms (Glossary)
- SessionId: Trace session identifier (one diagram per session)
- Invocation: “Inproc” (sync), “Queue” (queued/async) — strictly recognized; others default to sync with warning
- CorrespondingMessageId: Correlation key for queued flows
- ReturnQueueName: Fallback correlation field for queued flows
- Participants/Actors: Derived from SourceConfigName and TargetConfigName
- Message Label: Default full MessageBodyClassName (labelMode toggle supports short names)

11. Risks (Snapshot)
- Unknown Invocation values in the wild → addressed by strict recognition and warnings
- Missing/Conflicting correlation fields → best-effort with warnings
- Readability for large sessions → loop compression

12. Out of Scope (MVP)
- UI/Viewer, live refresh, or interactive debugging
- SuperSession composition
- CSV or non-SQL data inputs
- Strict-mode failures

13. Traceability
This overview informs shards:
- 20 Functional Requirements
- 30 Non-Functional Requirements
- 40 Data Sources and Mapping
- 50 Diagramming Rules
- 60 Acceptance Criteria
- 70 Risks & Issues
- 80 Milestones
- 90 Open Questions (resolved in PRD and reflected in shards)
