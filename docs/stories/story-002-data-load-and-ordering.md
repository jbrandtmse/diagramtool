# Story ST-002 — Data Load & Deterministic Ordering (SQL-only)

Status: Done
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

Implementation Target and Contract
- Class: MALIB.Util.DiagramTool
- Method (new):
  - ClassMethod LoadHeadersForSession(pSessionId As %Integer, Output pRows As %DynamicArray, pForceIdOnlyOrder As %Boolean = 0) As %Status
- Contract:
  - Input: pSessionId (single SessionId)
  - Behavior: Query Ens.MessageHeader with required columns, filter out HS.Util.Trace.Request, apply deterministic ordering
  - Ordering:
    - Default: ORDER BY TimeCreated, ID
    - Fallback: ORDER BY ID when TimeCreated cannot be used (older IRIS versions or environments)
    - Optional explicit fallback: pForceIdOnlyOrder=1 forces ORDER BY ID in tests or legacy deployments
  - Output: pRows is a %DynamicArray of normalized row objects (see schema below)
  - Return: %Status (OK on success; non-OK if SQL error or unexpected failure). Non-fatal data conditions should not cause failure (best-effort philosophy).

Normalized Row Schema (per element in pRows)
- ID: %Integer
- Invocation: %String ("Inproc" | "Queue" | other → preserved as-is; downstream may warn)
- MessageBodyClassName: %String (full class name including package)
- SessionId: %Integer
- SourceConfigName: %String
- TargetConfigName: %String
- ReturnQueueName: %String or "" when null
- CorrespondingMessageId: %Integer or "" when null
- TimeCreated: %String or %TimeStamp (normalized to a consistent textual representation if needed by tests)
- Type: %String ("Request" | "Response")

Query and Ordering Strategy
- Primary query (preferred):
  SELECT
    ID, Invocation, MessageBodyClassName, SessionId,
    SourceConfigName, TargetConfigName,
    ReturnQueueName, CorrespondingMessageId,
    TimeCreated, Type
  FROM Ens.MessageHeader
  WHERE SessionId = ?
    AND MessageBodyClassName <> 'HS.Util.Trace.Request'
  ORDER BY TimeCreated, ID;

- Fallback query (when TimeCreated ordering is not available):
  SELECT
    ID, Invocation, MessageBodyClassName, SessionId,
    SourceConfigName, TargetConfigName,
    ReturnQueueName, CorrespondingMessageId,
    TimeCreated, Type
  FROM Ens.MessageHeader
  WHERE SessionId = ?
    AND MessageBodyClassName <> 'HS.Util.Trace.Request'
  ORDER BY ID;

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

References (Anchored)
- FR-02 Data Source and Filtering (SQL-only): docs/prd/20-functional-requirements.md#fr-02-data-source-and-filtering-sql-only
- FR-03 Ordering and Determinism: docs/prd/20-functional-requirements.md#fr-03-ordering-and-determinism
- FR-09 Per-Session Diagram Generation: docs/prd/20-functional-requirements.md#fr-09-per-session-diagram-generation
- AC-02 Ordering Determinism (SQL-only): docs/prd/60-acceptance-criteria.md#ac-02-ordering-determinism-sql-only
- Canonical SQL: docs/prd/40-data-sources-and-mapping.md#2-canonical-sql

Test Dataset Plan (Definition of Ready details)
Provide or identify a dev namespace with a session (or seed data) that exercises:
1) Filtering
   - At least one row with MessageBodyClassName = 'HS.Util.Trace.Request' that must be excluded.
2) Ordering and tie-break
   - At least two rows sharing identical TimeCreated but different IDs to validate secondary ordering by ID.
3) Mixed Types/Invocation
   - A mixture of Request/Response and Inproc/Queue values to confirm determinism does not regress with value variety.

Options:
- Real data: Use docs/sample.sql as a starting point to query a known session (e.g., 1584253) and verify ordering.
- Seeded data (preferred for unit tests): Insert a minimal dataset into a controlled test environment/table mirroring Ens.MessageHeader schema sufficient for loader behavior validation.
- Tests should run deterministically independent of wall-clock; normalize TimeCreated to a fixed set in test data where possible.

Tasks (Draft)
T1. SQL Loader
- Implement MALIB.Util.DiagramTool:LoadHeadersForSession(pSessionId, Output pRows, pForceIdOnlyOrder=0) As %Status
- Apply filter and deterministic ordering; choose fallback by pForceIdOnlyOrder or by error handling on ORDER BY TimeCreated,ID
- Normalize output rows to the schema defined above

T2. Unit Tests (%UnitTest)
- Validate filtering and ordering (primary and fallback)
- Confirm determinism across multiple runs
- Include tie-break by ID when TimeCreated matches
- Include empty/fully filtered session producing an empty result

T3. Documentation
- Brief developer notes on loader behavior and why ordering is critical for correlation
- Reference PRD shards 20, 40, and AC-02 with anchored links

Definition of Ready
- PRD references stable (FR-02, FR-03, AC-02).
- Test dataset plan documented above and accessible in dev/test namespace (real session or seeded data).
- Agreement on method signature, output structure, and fallback behavior captured in this story.

Definition of Done
- All ACs pass with %UnitTest.
- SQL loader produces deterministic, filtered outputs.
- Inline documentation added; story marked Ready for PO review and QA design.

QA Notes (Checklist)
- Verify exclusion rule for HS.Util.Trace.Request.
- Confirm deterministic ordering using multiple executions and tie-break on ID when TimeCreated matches.
- Verify fallback behavior by forcing ID-only ordering (pForceIdOnlyOrder=1) in at least one test.
- Validate normalized schema fields and types for downstream consumption.

Change Log
- v1.0 Marked Done; QA Gate PASS; README dev note and PRD indexing guidance; 22/22 unit tests passing; gate created (docs/qa/gates/st.002-data-load-and-ordering.yml).
- v0.4 Marked Ready for Review; implemented loader and added exhaustive unit tests covering filtering, deterministic ordering with fallback, tie-break by ID, null normalization, invalid session IDs, and field preservation (Invocation).
- v0.3 Added implementation signature, normalized row schema, anchored references, and concrete test dataset plan.
- v0.2 Updated to SQL-only (removed CSV references) and aligned with finalized decisions.
- v0.1 Draft created (BMAD docs-first).

## QA Results

### Review Date: 2025-11-05
### Reviewed By: Quinn (Test Architect)

### Code Quality Assessment
- Implementation matches FR-02, FR-03, FR-09 and satisfies AC-02.
- Embedded SQL applies required filter (excludes HS.Util.Trace.Request) and deterministic ordering.
- Fallback behavior is correct: default ORDER BY TimeCreated, ID; forced/legacy fallback ORDER BY ID via pForceIdOnlyOrder or if C1 open fails.
- Output normalization returns %DynamicArray of objects; optional fields (ReturnQueueName, CorrespondingMessageId) normalized to empty string.
- Best-effort philosophy respected: invalid/non-positive SessionId returns empty results with $$$OK.

### Test Evidence
- 11 ST-002 tests passed (22/22 total in MALIB.Test.DiagramToolTest).
- Covered: primary ordering, forced fallback ordering, tie-break by ID, exclusion filter, determinism across calls, null normalization, invalid SessionId handling, and Invocation value preservation.

### Compliance Check
- Coding Standards: ✓
- Project Structure: ✓
- Testing Strategy: ✓ (comprehensive %UnitTest coverage)
- All ACs Met: ✓ (AC-02 Ordering Determinism)

### NFR Validation
- Security: PASS (read-only SQL against Ens.MessageHeader).
- Performance: PASS for expected dev/test volumes; recommend ensuring suitable index strategy (e.g., composite on SessionId, TimeCreated, ID) for production-scale datasets.
- Reliability: PASS (deterministic and unit-tested).
- Maintainability: PASS (clear method contract and inline documentation).

### Improvements Checklist
- [ ] Add a brief README/dev note explaining fallback ordering and how to force it in tests via pForceIdOnlyOrder.
- [ ] Optional: Document assumed indexing on Ens.MessageHeader (SessionId, TimeCreated, ID) to avoid full scans at scale.

### Files Modified During Review
- docs/qa/gates/st.002-data-load-and-ordering.yml (to be created)

### Gate Status
Gate: PASS → qa.qaLocation/gates/st.002-data-load-and-ordering.yml

### Recommended Status
[✓ Ready for Done] (functionality complete; add minor documentation noted above)
