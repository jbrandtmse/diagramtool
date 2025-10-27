# PRD v4 Shard — 30 Non-Functional Requirements (NFR): MALIB.Util.DiagramTool

Status: Draft v4
Owner: PM (BMad)
Related: ../prd.md, 00-overview.md, 20-functional-requirements.md, 40-data-sources-and-mapping.md, 50-diagramming-rules.md, 60-acceptance-criteria.md

NFR-01 Performance
- No explicit performance targets for MVP.
- Aim for reasonable behavior on typical sessions; processing should be approximately linear with the number of ordered events.

NFR-02 Determinism and Ordering
- Deterministic output for identical inputs.
- Primary ordering: TimeCreated, then ID. If TimeCreated cannot be used, fallback deterministically to ID only.
- Loop compression must be stable and repeatable (identical contiguous pair signatures compress identically).

NFR-03 Reliability and Resilience
- Best-effort behavior: unknown Invocation values, correlation ambiguities, and unpaired queued responses do not fail generation.
- Emit warnings as Mermaid comments (%% …) inline where feasible.
- Return %Status codes for programmatic callers (success or error). No strict-mode failures in MVP.

NFR-04 Compatibility and Standards
- Target InterSystems IRIS 2023.2+.
- SQL-only source: Ens.MessageHeader. CSV or alternate data modes are out of scope for MVP.
- Follow .clinerules guidance:
  - Use $$$ macros and %Status patterns.
  - QUIT-in-try/catch restrictions: no QUIT with arguments inside try/catch.
  - No underscores in parameter names; use camelCase.
  - Do not edit or hand-author Storage sections.

NFR-05 Testability
- Unit tests using %UnitTest with Given/When/Then structure mapped from Acceptance Criteria.
- Include tests for:
  - Session spec parsing (single, list, range).
  - Ordering and correlation (Inproc confirm-by-order with CorrMsgId check; Queue Correlation: CorrMsgId → ReturnQueueName → warn if unpaired).
  - Loop compression of contiguous identical pairs.
  - Deduplication default ON.
  - Identifier sanitization and collision suffixing.
  - Output formatting: append-only with divider comments.
- Warnings appear as %% comments; tests should validate presence where applicable.

NFR-06 Observability and Diagnostics
- Warnings surface via Mermaid comments (%%) in the rendered output/stdout where feasible.
- Optional developer diagnostics (e.g., ^ClineDebug) may be used during development, but warnings are not required to be duplicated there for MVP.

NFR-07 Security and Safety
- Read-only SQL access to Ens.MessageHeader; no data mutation.
- When writing to file, append-only semantics in explicitly specified target path.
- Sanitize Mermaid participant identifiers; preserve original labels safely.

NFR-08 Maintainability
- Code style aligned with .clinerules (indentation, macros, try/catch patterns).
- Small, cohesive methods with clear responsibilities (parsing, data load, correlation, emission, hashing).
- Avoid premature abstraction; document public APIs and expected inputs/outputs.

NFR-09 Configurability (MVP-scope)
- Runtime labelMode toggle (full|short), default=full.
- Deduplication default: ON (silent).
- Append-only file output with divider comment between diagrams.
- No configurable exclude list in MVP (only HS.Util.Trace.Request is excluded).

NFR-10 Documentation
- Developer documentation: usage examples (SQL-only), Mermaid basics link, append-only behavior, dedup default, and warning semantics.
- Inline class/method doc banners sufficient for developers.
- Traceability to PRD shards and Acceptance Criteria.

NFR-11 Internationalization/Localization
- Participant labels may contain non-ASCII characters; identifiers must be sanitized while preserving labels.
- No translation/localization in MVP; diagrams remain language-agnostic.

NFR-12 Operational Considerations
- Library is stateless between invocations (no persistent caches).
- Can be safely invoked in CI or local scripts.
- No UI; no server process; no background jobs.

NFR-13 Quality Gates (Advisory)
- QA review to produce a gate decision (PASS/CONCERNS/FAIL/WAIVED) based on:
  - Requirements traceability to tests.
  - Risk profile coverage (queued correlation, loop compression).
  - Non-functional determinism and warning behavior.
  - Test design completeness.

Traceability
- Supports Overview constraints (00-overview.md §8) and informs Acceptance Criteria thresholds (60-acceptance-criteria.md).
