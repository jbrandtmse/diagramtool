# Story ST-004 — Loop Detection (Contiguous Identical Pairs)

Status: Draft
Epic/PRD: docs/prd.md (v4)
Shards:
- 20-functional-requirements.md (FR-08, FR-09)
- 50-diagramming-rules.md
- 60-acceptance-criteria.md (AC-08, AC-09)

Story
As an IRIS developer generating sequence diagrams,
I want repeated request/response exchanges with identical signatures to be compressed into Mermaid loop blocks,
so that long repeated patterns remain readable without losing essential information.

Business Value
- Improves readability of chatty flows.
- Keeps diagrams compact and consumable for stakeholders.

Scope (Decisions-aligned)
- Loop signature:
  - Request: (Src, Dst, Label)
  - Response: (Src, Dst, Label)
- Detection policy:
  - Identify strictly contiguous repeated pairs with identical signatures
  - N > 1 compresses into:
    loop N times <Label>
      <Req line>
      <Resp line>
    end
  - Interruption by a different message signature ends the compression window
- Emission details:
  - Use current label policy (default full MessageBodyClassName, labelMode runtime toggle supports short)
  - Use arrow semantics from correlation (Inproc ->>, Queue -->> both legs)
  - Ensure participants are declared once before messages
- Non-fatal behavior:
  - Best-effort; do not compress if pairing is ambiguous
  - Emit warnings via "%%" comments for relevant anomalies if encountered during grouping (rare)

Out of Scope (MVP)
- Non-contiguous repeats or fuzzy matching
- Multi-pair grouping across different labels or endpoints
- Any CSV-based operation (SQL-only project)

Assumptions
- Correlated event list is available from ST-003 (pairs with arrows).
- Participants were collected from ordered rows (ST-002).

Dependencies
- ST-003 must provide correlated request/response pairs and singletons.
- ST-005 will build the final output with deduplication, append-only behavior, divider, and warnings.

Acceptance Criteria (mapped from PRD 60-acceptance-criteria.md)
AC-08 Loop Detection and Compression
- Given contiguous repeated pairs of identical request/response signatures
- When generating the diagram
- Then repeated pairs are compressed into a loop block with count N and the request/response lines inside
- And loop compression only applies to strictly contiguous identical pairs
- And when an interruption occurs (different signature), compression ends

AC-09 Per-Session Diagram Structure (partial)
- Given a single SessionId
- When emitting the diagram
- Then participant declarations precede message lines
- And compressed loops render as valid Mermaid blocks with correct arrows and labels

Additional Test Cases
- 3 identical pairs contiguous → loop 3 times with 1 req + 1 resp lines
- 2 identical pairs, interruption, then 2 identical pairs → two separate loop blocks
- Queued loops: both legs use -->> arrows
- Mixed Inproc/Queue loops should only compress when the pair signature (including arrows derived from Invocation) is identical

Non-Functional References
- Determinism (NFR-02): same inputs yield same loop segmentation.
- Resilience (NFR-03): anomalies lead to best-effort emission and optional warnings.
- Testability (NFR-05): unit tests exercise contiguous grouping semantics.

Tasks (Draft)
T1. Implement loop grouping
- Scan correlated events; group contiguous identical pair signatures
- Emit loop blocks for N>1; otherwise emit single pair lines

T2. Edge conditions
- Handle singletons and mixed sequences robustly
- Ensure correct indentation and newline handling for Mermaid validity

T3. Unit Tests (%UnitTest)
- Validate examples above and edge cases
- Confirm deterministic behavior

T4. Documentation
- Explain loop signature and why contiguity matters
- Provide examples with Inproc and Queue variants

Definition of Ready
- Correlated pairs and singletons from ST-003 are available.

Definition of Done
- All ACs met with passing %UnitTest.
- Correct Mermaid output for compressed and non-compressed regions.
- Story marked Ready for PO review and QA design.

Change Log
- v0.1 Draft created and aligned with finalized decisions.
