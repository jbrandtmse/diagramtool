# Tech Stack — MALIB.Util.DiagramTool

Status: Draft v5
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
- MALIB.Util.DiagramTool.Event (typed event class with pipeline properties)
- MALIB.Util.DiagramTool.Episode / EpisodeBlock (ST-008 episode grouping containers)
- MALIB.Util.DiagramTool.ClineDebug (centralized debug utility, default-off)

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
- Dev-only code authorship: Only the Dev agent should write/modify code (see .clinerules/00-role-boundaries.md)

Constraints & Non-Goals
- No UI/hosted visualization
- No SuperSession roll-up (one diagram per SessionId)
- No strict-mode failures (best-effort with %% warnings)
- No CSV/alternate data modes in MVP

Implementation Notes
- Event.Invocation caveat:
  - Some IRIS builds declare `Invocation` as MultiDimensional (cannot hold scalar values).
  - The pipeline uses `Arrow` semantics (`->>` vs `-->>`) instead of Invocation for Inproc/Queue distinction.
  - See `MALIB.Util.DiagramTool.Output.ConvertDynamicToEvents` for the workaround.
- Debug infrastructure:
  - `MALIB.Util.DiagramTool.ClineDebug` provides controlled, opt-in `^ClineDebug` tracing.
  - Default: OFF. Enable with `SetDebug(1)` for focused debugging sessions.
  - Inline `^ClineDebug` statements should be avoided in production code.

References
- PRD shards: docs/prd/20-functional-requirements.md, docs/prd/40-data-sources-and-mapping.md, docs/prd/50-diagramming-rules.md, docs/prd/60-acceptance-criteria.md
- Story ST-003: docs/stories/story-003-correlation-rules.md (IMPORTANT: Devs must read docs/dev-notes-correlation.md)
- Story ST-008: docs/stories/story-008-episode-based-loop-compression.md
- Coding Standards: docs/architecture/coding-standards.md
- Source Tree: docs/architecture/source-tree.md

Change Log
- v0.5 Added MALIB.Util.DiagramTool subpackage classes; added Event.Invocation caveat and debug infrastructure notes; updated references.
