# PRD v4 Shard — 90 Open Questions: MALIB.Util.DiagramTool

Status: Draft v4
Owner: PM (BMad)
Related: ../prd.md, 00-overview.md, 20-functional-requirements.md, 30-non-functional-requirements.md, 40-data-sources-and-mapping.md, 50-diagramming-rules.md, 60-acceptance-criteria.md

1) Labeling and Message Detail
- OQ-01: Should message labels ever include Type (Request/Response) or other metadata (e.g., MessageBodyId) for disambiguation, or keep labels minimal (short class name only) for readability?
- OQ-02: Should full class names be optionally supported via a toggle (short vs full)? Default proposed: short.

2) Invocation Semantics and Variants
- OQ-03: Confirm canonical Invocation values (“Inproc”, “Queue”). Are there production variants (e.g., “InProcess”, “ASYNC”) needing a synonym map?
- OQ-04: For queued responses, do we always treat the return leg as async (“-->>”) even if response timing appears synchronous in practice?

3) Correlation Priorities and Fallbacks
- OQ-05: In Inproc flows, should CorrespondingMessageId (when present) be used to confirm response pairing or solely rely on order + reversed endpoints?
- OQ-06: In queued flows, priority is CorrespondingMessageId, then ReturnQueueName. Any additional fallback signals (e.g., TargetQueueName) we should consider for edge cases?

4) Filtering Rules
- OQ-07: Beyond excluding HS.Util.Trace.Request, are there other known trace-only classes to filter out in some environments?
- OQ-08: Should we allow an optional configured “exclude list” of MessageBodyClassName for env-specific noise?

5) Session vs SuperSession
- OQ-09: MVP defers SuperSession. Any short-term scenarios requiring roll-up by SuperSession (e.g., audit use-cases) that would justify elevating scope?

6) Participant Naming and Collisions
- OQ-10: On sanitized identifier collisions, is suffixing with “_2 / _3” acceptable, or should we add a hash suffix for stability across runs?
- OQ-11: Do we need an optional max-length for identifiers or labels for specific documentation toolchains?

7) Output Formatting and Packaging
- OQ-12: Default newline normalization (LF) and file overwrite semantics are proposed. Any requirement for append mode or per-session page breaks?
- OQ-13: Any near-term need for InterSystems Package Manager (ZPM) packaging as part of MVP, or defer to a later release?

8) Performance and Size Limits
- OQ-14: Confirm performance targets (sessions up to ~5k rows). Are there known heavier sessions (10k–50k+) we should plan to test?
- OQ-15: Any constraints for memory footprint in CI environments we should explicitly bound (e.g., ≤ 512MB)?

9) CSV Demo Mode Parity
- OQ-16: CSV column order appears fixed in sample. Should we implement a header-driven field mapping to guard against column reordering in future samples?

10) Deduplication Defaults
- OQ-17: Should deduplication be ON by default for multi-session runs? Proposed default: ON.
- OQ-18: If deduplication removes duplicates, do we need a summary report of removed session IDs for traceability?

11) Error/Warning Surfaces
- OQ-19: Where should best-effort warnings be surfaced (stdout comments, ^ClineDebug, or return status only)?
- OQ-20: Any preference for a “strict mode” that fails on correlation ambiguities vs the default best-effort mode?

Traceability
- Questions map primarily to FR-05/FR-06/FR-07/FR-08 (labels, arrows, correlation, loops), FR-10 (dedup), FR-11 (output), FR-13 (CSV), and NFR-01/02/03/05 (performance, determinism, resilience, testability).
