# Story ST-001 — Session Spec Parsing

Status: Ready for Development
Epic/PRD: docs/prd.md (v4), shards docs/prd/20-functional-requirements.md#fr-01-session-spec-parsing (FR-01), docs/prd/60-acceptance-criteria.md#ac-01-session-spec-parsing (AC-01)
Owners: SM (Bob), PO (Sarah), Dev (James), QA (Quinn)

Story
As an IRIS developer documenting Interoperability flows,
I want to specify sessions using a compact string (single IDs, ranges, and lists),
so that I can generate diagrams for one or more sessions without manually expanding IDs.

Business Value
- Enables ergonomic selection of sessions, speeding up doc generation.
- Feeds all downstream steps (data loading, correlation, and diagram building).

Scope
- Parse a selector string like "1, 5-7, 12" into [1,5,6,7,12].
- Ignore invalid or empty tokens gracefully.
- Whitespace-insensitivity.
- Output a deterministic list of integers.

Out of Scope (MVP)
- SuperSession parsing or expansion.
- Validation against database (this story only parses; no I/O or SQL).

Assumptions
- Session IDs are positive integers.
- Whitespace and mixed delimiters are possible but commas are canonical.
- Ranges use a hyphen (e.g., 5-9).

Dependencies
- PRD v4: [FR-01](docs/prd/20-functional-requirements.md#fr-01-session-spec-parsing) (Session Spec Parsing), [AC-01](docs/prd/60-acceptance-criteria.md#ac-01-session-spec-parsing).
- Upcoming stories consume this output (ordering, correlation, builder).

Acceptance Criteria (from PRD 60-acceptance-criteria.md)
AC-01 Session Spec Parsing
- Given a session selector string "1, 5-7, 12"
- When the selector is parsed
- Then the result contains [1,5,6,7,12] in numeric order
- And invalid tokens (e.g., empty entries, non-numeric) are ignored without error

Additional Test Cases
- "  10  " → [10]
- "2-2" → [2]
- "3-1" (invalid range) → []
- "1,,4" → [1,4]
- "a,1,2-b,9" → [1,9]
- "" → []
- "  " → []
- "1 , 5-7 , 12 , 100-102" → [1,5,6,7,12,100,101,102]

Non-Functional References
- Deterministic output (NFR-02).
- Testability via %UnitTest (NFR-05).

Tasks (Draft)
T1. Implement parser utility in MALIB.Util.DiagramTool.cls
- Target: src/MALIB/Util/DiagramTool.cls
- Add: ClassMethod ParseSessionSpec(pSelector As %String = "") As %List
- Return type: %List (built via $LISTBUILD) containing positive integers
- Ordering: numeric ascending; duplicates preserved if present
- Error handling: ignore invalid tokens (non-numeric, empty) and invalid ranges (a>b) without error; whitespace-insensitive
- Examples: "1, 5-7, 12" → $LB(1,5,6,7,12); "2-2" → $LB(2); "3-1" → $LB()

T2. Robust tokenization and validation
- Trim whitespace and ignore empty tokens
- Accept single integers (e.g., "15")
- Accept range tokens "a-b" where a ≤ b and both are positive integers

T3. Unit tests (%UnitTest)
- Cover AC-01 example and Additional Test Cases
- Negative/edge cases for invalid inputs
- Determinism check: identical input yields identical output

T4. Documentation
- Update developer notes/README usage examples referencing this parsing behavior

Definition of Ready
- PRD references are stable (FR-01, AC-01).
- Test inputs and expected outputs defined in this story.

Definition of Done
- All acceptance criteria met with passing %UnitTest.
- Deterministic behavior verified.
- Inline doc/comments describing parsing rules are present.
- Story marked Ready for PO review and QA design.

QA Notes (Placeholder)
- Trace test cases to AC-01 and verify negative paths do not throw.
- Consider boundary values (very large IDs, leading zeros).

Change Log
- v0.2 Marked Ready for Development after Story Draft Checklist PASS
- v0.1 Draft created (BMAD docs-first).
