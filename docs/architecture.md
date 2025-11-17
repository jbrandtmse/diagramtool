# Architecture Overview — MALIB.Util.DiagramTool

Status: Draft v4
Owner: Architecture
Related: docs/prd.md (v4 shards), docs/stories/story-003-correlation-rules.md, docs/dev-notes-correlation.md

Purpose
- Document the system context and engineering standards used by the DiagramTool library.
- Provide stable references for developers and QA (testing standards, source tree conventions, coding standards, and tech stack).

System Context
- A library (no UI) that generates Mermaid sequence diagrams from IRIS Interoperability trace sessions (Ens.MessageHeader).
- Input: Session selector string (single IDs, ranges, lists) parsed to a set of SessionIds.
- Public orchestration entrypoint (ST-006): `MALIB.Util.DiagramTool.GenerateDiagrams(pSelector, pOutFile, pLabelMode, pDedupOn, .pText)` wires together parsing, loading, correlation, loop detection, and output/dedup according to the PRD.
- Data load (ST-002): SQL-only loader reads Ens.MessageHeader, filters HS.Util.Trace.Request, applies deterministic ordering (TimeCreated, ID) with ID-only fallback.
- Correlation (ST-003): Inproc and Queue pairing with strict rules and best-effort warnings.
- Loop detection (ST-004) and output/append/dedup (ST-005) come later in the sequence and are invoked from the orchestration entrypoint.

Key Decisions (aligned with PRD v4)
- Invocation handling (strict): Inproc (->>) and Queue (-->>) both legs async for queued pairs.
- Queue fallback: CorrespondingMessageId primary; ReturnQueueName fallback only when reversed endpoints match the request (response direction Dst → Src); otherwise unpaired with a warning.
- Best-effort warnings (“%%”) rather than strict failures.
- Append-only output and silent dedup for multi-session runs.

Testing Standards (summary)
- Framework: InterSystems IRIS %UnitTest (tests live under src/MALIB/Test/).
- Assertions: Use $$$ macros (AssertEquals, AssertTrue, AssertStatusOK, etc.).
- %OnNew requirement: When extending %UnitTest.TestCase, implement %OnNew(initvalue) and call ##super(initvalue).
- Determinism: Tests must not depend on wall-clock; seed data deterministically.
- Method names: Test methods start with “Test”; keep scenarios small and focused.
- See docs/architecture/coding-standards.md for additional ObjectScript rules.

Reference Documents
- Coding Standards: docs/architecture/coding-standards.md
- Tech Stack: docs/architecture/tech-stack.md
- Source Tree: docs/architecture/source-tree.md

Traceability
- PRD Functional: docs/prd/20-functional-requirements.md
- Data Mapping: docs/prd/40-data-sources-and-mapping.md
- Diagramming Rules: docs/prd/50-diagramming-rules.md
- Acceptance Criteria: docs/prd/60-acceptance-criteria.md
- Story ST-003: docs/stories/story-003-correlation-rules.md (IMPORTANT: Devs must also read docs/dev-notes-correlation.md)

Change Log
- v0.1 Initial architecture overview aligning with PRD v4 and ST-003 policy selections.
