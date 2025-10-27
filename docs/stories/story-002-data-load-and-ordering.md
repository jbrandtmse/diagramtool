# Story ST-002 — Data Load & Deterministic Ordering (SQL-only)

Status: Draft
Epic/PRD: docs/prd.md (v4)
Shards: 
- 20-functional-requirements.md (FR-02, FR-03, FR-09)
- 40-data-sources-and-mapping.md
- 60-acceptance-criteria.md (AC-02, AC-09)

Story
As an IRIS developer generating sequence diagrams,
I need to load Ens.MessageHeader rows for a given SessionId with correct filtering and deterministic ordering,
so that downstream correlation and diagram generation are stable and reproducible.

Business Value
- Ensures all subsequent steps operate on a consistent, correctly filtered view of trace data.
- Prevents non-deterministic diagrams that erode trust in documentation.

Scope (Decisions-aligned)
- SQL-only data source: Ens.MessageHeader (no CSV or alternate data modes).
- Required fields: ID, Invocation, MessageBodyClassName, SessionId, SourceConfigName, TargetConfigName, ReturnQueueName, CorrespondingMessageId, TimeCreated, Type.
- Filtering:
  - Exclude rows where MessageBodyClassName = "HS.Util.Trace.Request".
- Ordering (deterministic):
  - Prefer ORDER BY TimeCreated, ID.
  - Fallback deterministically to ORDER BY ID when TimeCreated ordering isn’t available.
- Result normalization:
  - Provide rows as a consistent structure for downstream processing (correlation and diagram builder).

Out of Scope (MVP)
- Correlation logic (covered in ST-003).
- Loop detection (covered in ST-004).
- Multi-session concat, dedup, append-only output, divider and warnings surfacing (covered in ST-005).
- Any CSV/demo mode.

Assumptions
- Ens.MessageHeader is available in the target namespace for SQL-driven runs.
- SessionId is the scoping key (SuperSession out of scope).

Dependencies
- PRD v4: FR-02, FR-03, FR-09; AC-02; shard 40-data-sources-and-mapping.md.
- ST-001 outputs (session ID list) will drive which sessions to load.
- ST-003 will consume these ordered rows for correlation.

Acceptance Criteria (mapped from PRD 60-acceptance-criteria.md)
AC-02 Ordering Determinism (SQL-only)
- Given Ens.MessageHeader rows for a session
- When rows are loaded and ordered
- Then ordering is by TimeCreated then ID
- And if TimeCreated cannot be used, ordering falls back deterministically to ID only
- And repeated runs with the same data produce identical ordering

Additional AC for Filtering
- Given rows where MessageBodyClassName = "HS.Util.Trace.Request"
- When loading data
- Then those rows are excluded from the result set

Additional Test Cases (SQL-only)
- Single-session with mixed Invocation values (Inproc/Queue) to confirm ordering stability
- Rows with identical TimeCreated but different IDs confirm tie-break by ID
- Empty (or fully filtered) session produces an empty row set for downstream handling

Non-Functional References
- Deterministic outputs (NFR-02).
- Resilience and best-effort behavior downstream (warnings emitted later by builder; NFR-03).
- Testability (NFR-05).

Tasks (Draft)
T1. SQL Loader
- Prepare statement selecting required fields with WHERE SessionId=? AND MessageBodyClassName <> 'HS.Util.Trace.Request'
- ORDER BY TimeCreated, ID; gracefully fallback to ORDER BY ID if primary ordering unsupported
- Return normalized row objects suitable for downstream steps

T2. Unit Tests (%UnitTest)
- Validate filtering and ordering (primary and fallback)
- Confirm determinism across multiple runs

T3. Documentation
- Brief developer notes on loader behavior and why ordering is critical for correlation
- Reference PRD shards 20, 40, and AC-02

Definition of Ready
- PRD references stable (FR-02, FR-03, AC-02).
- Test datasets identified and accessible in dev namespace.

Definition of Done
- All ACs pass with %UnitTest.
- SQL loader produces deterministic, filtered outputs.
- Inline documentation added; story marked Ready for PO review and QA design.

QA Notes (Placeholder)
- Verify exclusion rule for HS.Util.Trace.Request.
- Confirm deterministic ordering using multiple executions and tie-break on ID when TimeCreated matches.

Change Log
- v0.2 Updated to SQL-only (removed CSV references) and aligned with finalized decisions.
- v0.1 Draft created (BMAD docs-first).
