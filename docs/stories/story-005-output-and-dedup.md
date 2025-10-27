# Story ST-005 — Output (Append-only, Divider), Dedup (Default ON), Warnings, Label Toggle

Status: Draft
Epic/PRD: docs/prd.md (v4)
Shards:
- 20-functional-requirements.md (FR-05, FR-10, FR-11, FR-12)
- 50-diagramming-rules.md
- 60-acceptance-criteria.md (AC-04, AC-09, AC-10, AC-11, AC-13)

Story
As an IRIS developer producing final diagrams,
I want multi-session runs to append diagrams to a file with a clear divider, deduplicate identical outputs by default, emit warnings inline, and optionally switch label modes,
so that the resulting artifact is readable, compact, and aligned with project conventions.

Business Value
- Consistent outputs for documentation pipelines.
- Prevents duplication and clarifies warnings inline for auditability.
- Allows label verbosity control without changing code.

Scope (Decisions-aligned)
- Labeling:
  - Default message label: full MessageBodyClassName (including package), sanitized for Mermaid
  - Runtime toggle: labelMode=full|short (default=full); short = last segment after "."
- Output to file:
  - Append-only semantics when a file path is provided
  - Always insert a divider comment between diagrams: "%% ---"
  - Maintain a blank line between diagrams in the combined text result
- Warnings:
  - Emit non-fatal warnings as Mermaid "%%" comments near relevant lines where feasible:
    - Unknown Invocation defaulted to sync
    - Inproc CorrMsgId conflict (order-based pairing retained)
    - Unpaired queued response due to missing CorrMsgId/ReturnQueueName
- Deduplication:
  - ON by default for multi-session runs
  - Only output unique diagrams (stable hash)
  - Silent deduplication (no summary of removed SessionIds)
- Best-effort policy:
  - No strict mode; never fail on ambiguities; surface issues as warnings

Out of Scope (MVP)
- Summaries of removed SessionIds (silent dedup)
- CSV or non-SQL data modes
- SuperSession composition

Assumptions
- Correlated events and loop compression are already performed by ST-003 and ST-004.
- Participants were declared once at the top of each per-session diagram.

Dependencies
- ST-001: session spec parsing
- ST-002: SQL-only data loading and ordering
- ST-003: correlation (Inproc confirm, Queue CorrMsgId→ReturnQueueName, unpaired warnings)
- ST-004: loop detection (contiguous identical pairs)

Acceptance Criteria (mapped from PRD 60-acceptance-criteria.md)
AC-04 Labeling Defaults and Toggle
- Given default settings
- Then labels are full class names; when labelMode=short, labels are the last segment after "."

AC-09 Per-Session Structure (partial)
- Given a generated diagram
- Then participant declarations precede message lines; warnings appear as "%%" comments near relevant lines

AC-10 Multi-Session Deduplication (Default ON)
- Given two SessionIds that produce identical diagram text
- When generating with default settings
- Then only one copy is included; no summary of removed SessionIds is emitted

AC-11 Output Contract — Append-Only with Divider
- Given a file path
- When writing diagrams
- Then content is appended; a divider "%% ---" is written between diagrams; combined text has blank line separation

AC-13 Error Handling and Best-Effort
- Given ambiguous or missing correlation information
- When generating output
- Then generation does not fail; warnings are emitted as "%%" comments; %Status indicates success or error without strict-mode failures

Additional Test Cases
- Multi-session with duplicates → only unique kept; no summary produced
- Append-only idempotence: multiple runs append with dividers and keep prior content intact
- Label toggling: full vs short reflected in emitted labels

Non-Functional References
- Determinism (NFR-02): dedup and divider logic is predictable and stable.
- Resilience (NFR-03): warnings over failures for non-fatal issues.
- Testability (NFR-05): unit tests assert append, divider presence, dedup ON default, and label toggle behavior.

Tasks (Draft)
T1. Output writer
- Implement append-only file writing; ensure divider "%% ---" between diagrams
- Maintain blank line separation in combined text

T2. Deduplication
- Default ON; compute stable hash per diagram; filter duplicates silently

T3. Warning emission
- Insert "%%" comments at relevant positions when conditions occur
- Ensure warnings also appear in stdout echo

T4. Label toggle
- Implement runtime parameter labelMode=full|short (default=full)

T5. Unit Tests (%UnitTest)
- Validate ACs and Additional Test Cases
- Confirm deterministic behavior and absence of summaries for dedup

T6. Documentation
- Usage examples: append-only, divider, dedup ON, label toggle, warning semantics

Definition of Ready
- PRD shards stable; ST-001..ST-004 design complete.

Definition of Done
- All ACs met with passing %UnitTest.
- Outputs meet append-only/divider/dedup/warning requirements.
- Story marked Ready for PO review and QA design.

Change Log
- v0.1 Draft created and aligned with finalized decisions.
