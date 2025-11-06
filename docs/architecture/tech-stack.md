# Tech Stack — MALIB.Util.DiagramTool

Status: Draft v4
Owner: Architecture
Related: docs/architecture.md, docs/architecture/coding-standards.md, docs/architecture/source-tree.md

Purpose
- Describe the technologies and tools used by the DiagramTool library.
- Give developers a clear reference for environment expectations and constraints.

Core Platform
- InterSystems IRIS (Interoperability)
  - Language: ObjectScript (+ Embedded SQL)
  - Data Source: Ens.MessageHeader (trace metadata)
  - Testing: %UnitTest framework

Languages & Formats
- ObjectScript (.cls) for implementation and tests
- SQL (Embedded) for read-only queries
- Mermaid (sequenceDiagram) as output format
- Markdown for documentation (PRD, stories, dev notes, architecture)
- YAML for QA gates and templates

Key Libraries / Classes
- Ens.MessageHeader / Ens.MessageHeaderBase (trace rows)
- %DynamicObject / %DynamicArray (normalized row/event representations)
- %UnitTest.TestCase (unit tests and assertions macros)

Project Policies (Highlights)
- SQL-only MVP: No CSV or alternate data modes in MVP
- Deterministic ordering:
  - Primary: ORDER BY TimeCreated, ID
  - Fallback: ORDER BY ID (legacy/forced)
- Correlation rules:
  - Inproc: reversed endpoints + Type="Response" (forward-only scan); CorrespondingMessageId confirms; conflict warns
  - Queue: CorrespondingMessageId primary; ReturnQueueName fallback ONLY when reversed endpoints match request (response direction Dst → Src); else unpaired with warning
  - Unknown Invocation: warn and default to sync (->>)
- Output rules:
  - Append-only file writes with divider comment (%% ---)
  - Dedup ON by default; silent removal of duplicates

Testing Toolchain
- Framework: %UnitTest
- Assertions: $$$AssertEquals, $$$AssertTrue, $$$AssertStatusOK (macros; no $$$AssertFalse)
- Constructor: When extending %UnitTest.TestCase, implement %OnNew(initvalue) and call ##super(initvalue)
- Determinism: Seed/normalize inputs; avoid wall-clock times in tests
- Test location: src/MALIB/Test/

Build & Execution
- Compilation and tests are executed in IRIS (outside MVP scope here)
- No Docker assumptions in this project’s docs (use local IRIS as available)
- Dev-only code authorship: Only the Dev agent should write/modify code (see .clinerules/08-role-boundaries.md)

Constraints & Non-Goals
- No UI/hosted visualization
- No SuperSession roll-up (one diagram per SessionId)
- No strict-mode failures (best-effort with %% warnings)
- No CSV/alternate data modes in MVP

References
- PRD shards: docs/prd/20-functional-requirements.md, docs/prd/40-data-sources-and-mapping.md, docs/prd/50-diagramming-rules.md, docs/prd/60-acceptance-criteria.md
- Story ST-003: docs/stories/story-003-correlation-rules.md (IMPORTANT: Devs must read docs/dev-notes-correlation.md)
- Coding Standards: docs/architecture/coding-standards.md
