# Role Boundaries — Code Authorship Policy

Status: Active
Owner: Product/Process (Scrum Master enforces)
Related: .clinerules/07-sm.md, docs/hand-offs/hand-off-st-003.md

Purpose
- Prevent accidental code edits by non‑developer personas.
- Keep responsibilities clean: Scrum Master prepares stories, gates, and handoffs; Dev agent writes and changes code.

Core Policy
- Only the Dev agent may write, modify, or delete code or test code.
- Scrum Master (SM, @sm) and any non‑Dev persona must not make code changes.

Definitions
- “Code” includes:
  - Source code under src/** (all languages, e.g., .cls, .js, .ts, .py, etc.)
  - Test code under src/**/Test/** (e.g., src/MALIB/Test/**)
  - Build/compile scripts, CI configs that affect builds, and runtime configs under src/**
- “Documentation” includes:
  - docs/**, README.md, docs/qa/**, docs/hand-offs/**, docs/stories/**, docs/prd/**
  - .clinerules/** (process/policy docs)
  - .bmad-core/** (agent tasks/templates/checklists) — non-code content only

Enforcement Rules (Tool/Action Guardrails)
- While acting as Scrum Master (@sm):
  - Allowed:
    - Use read_file, list_files, search_files (read-only exploration).
    - Use write_to_file/replace_in_file ONLY for documentation paths (docs/**, README.md, docs/qa/**, docs/hand-offs/**, docs/stories/**, docs/prd/**, .clinerules/**, .bmad-core/**).
  - Forbidden:
    - write_to_file/replace_in_file targeting any file under src/** or test code under src/**/Test/**.
    - execute_command that compiles, installs, modifies source, runs unit tests, or otherwise mutates the codebase.
    - MCP compile/test tools (e.g., compile_objectscript_*, execute_unit_tests) — these are reserved for the Dev agent.
- While acting as Dev agent:
  - Full code-edit authority per story scope and QA gates.
  - Must follow contracts defined in stories, dev notes, and PRD shards.

Response to Violations
- If the SM accidentally edits code:
  - Immediately revert the change.
  - Log a note to the dev debug log (see .bmad-core/core-config.yaml: devDebugLog) with timestamp and file path.
  - Continue by producing a proper developer handoff instead.

Workflow Expectations
- When a user requests implementation while @sm is active:
  - SM prepares/updates: story, dev notes, QA gate, and developer handoff.
  - SM asks the user to switch to the Dev agent (or equivalent) to perform code changes.
- Handoffs MUST contain:
  - Implementation target and contract (class/methods/signatures),
  - Data/event schemas,
  - Policy decisions,
  - AC-mapped test plan,
  - Open questions and next steps.

Quick Path Rules (SM)
- Allowed edits (examples):
  - docs/stories/story-XXX-*.md (stories/specs)
  - docs/hand-offs/hand-off-*.md (developer handoffs)
  - docs/qa/gates/*.yml (QA gates)
  - README.md, docs/prd/**, docs/dev-notes-*.md
  - .clinerules/** (process/policy)
- Not allowed edits (examples):
  - src/MALIB/Util/DiagramTool.cls
  - src/MALIB/Test/DiagramToolTest.cls
  - Any file under src/** (including tests)
  - Any script or file that compiles/runs code

Examples
- OK (SM): Update docs/stories/story-003-correlation-rules.md with contract/schema/policies.
- OK (SM): Create docs/hand-offs/hand-off-st-003.md and a QA gate under docs/qa/gates/.
- NOT OK (SM): Add methods to src/MALIB/Util/DiagramTool.cls or modify src/MALIB/Test/DiagramToolTest.cls.
- OK (Dev): Implement correlation methods and unit tests per handoff and story.

Escalation
- If policy conflicts with an urgent request, SM must:
  - Document the need in the handoff,
  - Request switch to Dev agent,
  - Await authorization to proceed as Dev (if permitted by the user).

Notes
- This policy augments .clinerules/07-sm.md and takes precedence for code authorship boundaries.
- Update this rule when new personas or code paths are introduced.
