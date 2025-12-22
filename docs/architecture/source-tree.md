# Source Tree — MALIB.Util.DiagramTool

Status: Draft v5
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
      - DiagramTool.cls                    # ST-006 Orchestration entrypoint (GenerateDiagrams) + facades
      - DiagramTool/
        - ClineDebug.cls                   # Centralized debug utility (default-off)
        - Correlation.cls                  # ST-003 Correlation rules (Inproc/Queue pairing, warnings)
        - Episode.cls                      # ST-008 Episode container class
        - EpisodeBlock.cls                 # ST-008 Episode loop block container
        - Event.cls                        # Typed event class for pipeline processing
        - Loader.cls                       # ST-002 Data loading (SQL-only, deterministic ordering)
        - Output.cls                       # ST-004/05/07/08 Loop detection, output, participant ordering, episode compression
        - SessionSpec.cls                  # ST-001 Session selector parsing
    - Test/
      - DiagramToolCorrelationTest.cls     # ST-003 correlation tests
      - DiagramToolLoaderTest.cls          # ST-002 loader tests
      - DiagramToolOutputTest.cls          # ST-004/05/07/08 output/loop/participant/episode tests
      - DiagramToolSessionSpecTest.cls     # ST-001 session spec tests
      - DiagramToolTest.cls                # ST-006 orchestration tests
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
- Implementation structure
  - Main entrypoint: `src/MALIB/Util/DiagramTool.cls` (GenerateDiagrams + facades)
  - Feature classes: `src/MALIB/Util/DiagramTool/*.cls` (one class per story/concern)
  - Dev agent only writes code/tests (see .clinerules/00-role-boundaries.md).
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
- v0.5 Updated to reflect ST-001..ST-008 class structure with detailed file descriptions; added DiagramTool subpackage classes.
- v0.1 Initial source tree map aligned with PRD v4 and ST-003 handoff.
