# Coding Standards — MALIB.Util.DiagramTool

Status: Draft v4
Owner: Architecture
Related: docs/architecture.md, docs/architecture/tech-stack.md, docs/architecture/source-tree.md

Purpose
- Define ObjectScript coding conventions and testing rules used by this project.
- Keep code deterministic, testable, and consistent across contributors.

General ObjectScript Conventions
- Indentation and formatting
  - Indent ObjectScript commands at least one space; keep blocks consistently indented.
  - Prefer clear, single-purpose methods; keep lines reasonably short.
- Naming
  - Parameters: prefix with `p` (e.g., `pSessionId`).
  - Locals: prefix with `t` (e.g., `tCount`, `tSC`).
  - Properties: Capitalized (e.g., `SessionId`, `MessageBodyClassName`).
  - Class Parameters: CamelCase or ALLCAPS with no underscores (IRIS restriction).
- Class storage
  - NEVER edit or add Storage sections by hand. The compiler manages Storage from declared properties.

Macros and Status Handling
- Use $$$ macros (triple dollar) — not `$$`.
  - Assertions in tests: `Do $$$AssertEquals(...)`, `Do $$$AssertTrue(...)`, `Do $$$AssertStatusOK(...)`.
  - Status constants: `$$$OK`, error checks `$$$ISERR(tSC)`.
- Return a `%Status` from methods that have no meaningful return value.
  - Pattern:
    ```
    Set tSC = $$$OK
    // ... logic ...
    Quit tSC
    ```
- Try/Catch and QUIT
  - Do NOT `QUIT value` inside a Try/Catch block (IRIS restriction).
  - Pattern:
    ```
    Set result = ""  // initialize before Try
    Try {
      // set result
      Quit  // argumentless
    } Catch ex {
      // handle
      Quit  // argumentless
    }
    Quit result
    ```

Abstract Methods (if used later)
- IRIS requires a code block even for abstract methods; return type-appropriate defaults:
  - Object: `Quit $$$NULLOREF` or `Quit ""`
  - %Status: `Quit $$$OK`
  - %String: `Quit ""`
  - %Boolean: `Quit 0`
  - %Numeric: `Quit 0`

Dynamic Objects and JSON
- Access %DynamicObject properties using `%Get`/`%Set`.
- For JSON keys containing underscores, quote the key (underscore is concatenation in ObjectScript):
  - Example: `Set obj."max_results" = 5`

SQL and Determinism
- Use read-only SQL against `Ens.MessageHeader` (SQL-only MVP).
- Deterministic ordering is critical:
  - Primary: `ORDER BY TimeCreated, ID`
  - Fallback: `ORDER BY ID` (explicit flag or when TimeCreated path not available)

Correlation Rules (summary reference)
- Invocation mapping: Inproc `->>`, Queue `-->>` (both legs async for queued).
- Queue fallback policy: `CorrespondingMessageId` primary; `ReturnQueueName` fallback ONLY when reversed endpoints match the request (response direction Dst → Src); otherwise unpaired with a warning.
- Unknown Invocation: emit “%%” warning and default to sync `->>`.

Testing Standards
- Framework: IRIS `%UnitTest`.
- Location: tests live under `src/MALIB/Test/`.
- Method naming: test methods start with `Test`.
- Constructor: when extending `%UnitTest.TestCase`, implement `%OnNew(initvalue)` and call `##super(initvalue)`; check status.
- Assertions: use standard macros (`$$$AssertEquals`, `$$$AssertTrue`, `$$$AssertStatusOK`, etc.). There is no `$$$AssertFalse`; use `$$$AssertTrue('condition, ...)`.
- Determinism: seed/normalize test data; avoid wall-clock dependencies.
- Coverage: map tests to ACs (AC-05/06/07/09/13 for ST-003).

Code Boundaries and Roles
- Only the Dev agent writes/modifies code and tests (see `.clinerules/08-role-boundaries.md`).
- Scrum Master/PO edits documentation only (stories, PRD, QA gates, hand-offs, architecture docs).

Change Log
- v0.1 Initial coding standards extracted from project policies and .clinerules.
