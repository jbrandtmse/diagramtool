# Source Tree — MALIB.Util.DiagramTool

Status: Draft v4
Owner: Architecture
Related: docs/architecture.md, docs/architecture/coding-standards.md, docs/architecture/tech-stack.md

Purpose
- Provide a quick map of where things live so developers and QA know where to add/inspect files.

High-Level Layout
- src/ — ObjectScript sources and tests
  - Ens/
    - MessageHeader.cls
    - MessageHeaderBase.cls
  - MALIB/
    - Util/
      - DiagramTool.cls           # Implementation target (ST-002 loader, ST-003 correlation methods to be added by Dev)
    - Test/
      - DiagramToolTest.cls       # Unit tests using %UnitTest (extend or add new test classes here)
- docs/ — Documentation (stories, PRD shards, QA gates, hand-offs, architecture)
  - prd/
    - 20-functional-requirements.md
    - 40-data-sources-and-mapping.md
    - 50-diagramming-rules.md
    - 60-acceptance-criteria.md
    - ... (other shards)
  - stories/
    - story-001-session-spec-parsing.md
    - story-002-data-load-and-ordering.md
    - story-003-correlation-rules.md   # Ready for Development (explicit dev-notes callout)
    - story-004-loop-detection.md
    - story-005-output-and-dedup.md
  - qa/gates/
    - st.001-session-spec-parsing.yml
    - st.002-data-load-and-ordering.yml
    - st.003-correlation-rules.yml
  - hand-offs/
    - hand-off-st-003.md
  - architecture.md                     # Overview index
  - architecture/
    - coding-standards.md               # ObjectScript + testing standards
    - tech-stack.md                     # Platform/tools/libraries
    - source-tree.md                    # This file

Key Conventions
- Implementation target
  - ST-003: Add correlation methods to src/MALIB/Util/DiagramTool.cls (Dev agent only; see .clinerules/08-role-boundaries.md).
- Tests
  - Use src/MALIB/Test/ for %UnitTest test classes and methods (Test* methods).
  - Assertions via $$$ macros (AssertEquals, AssertTrue, AssertStatusOK).
  - Implement %OnNew(initvalue) and call ##super(initvalue).
- Docs
  - Stories live under docs/stories/.
  - PRD shards live under docs/prd/.
  - QA gates live under docs/qa/gates/.
  - Developer hand-offs under docs/hand-offs/.
  - Architecture references under docs/architecture.md and docs/architecture/*.

Policy Reminder
- Only the Dev agent writes/modifies code and tests under src/**.
- SM/PO update documentation and process artifacts only (stories, PRD, gates, hand-offs, architecture).
- See .clinerules/08-role-boundaries.md for enforcement details.

Change Log
- v0.1 Initial source tree map aligned with PRD v4 and ST-003 handoff.
