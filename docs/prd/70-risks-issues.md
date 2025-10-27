# PRD v4 Shard — 70 Risks, Assumptions, and Issues: MALIB.Util.DiagramTool

Status: Draft v4
Owner: PM (BMad)
Related: ../prd.md, 00-overview.md, 20-functional-requirements.md, 30-non-functional-requirements.md, 40-data-sources-and-mapping.md, 50-diagramming-rules.md, 60-acceptance-criteria.md

1) Key Risks (with Mitigations)
- R-01 Invocation Variants (Strict Recognition)
  - Risk: Environments may emit Invocation values beyond “Inproc”/“Queue”.
  - Mitigation: Strict recognition only (case-insensitive) for “Inproc”/“Queue”; unknown values emit a %% warning and default to sync (->>).

- R-02 Missing/Conflicting Correlation Data
  - Risk: CorrespondingMessageId and/or ReturnQueueName may be null or conflict with ordering (for Inproc confirmation).
  - Mitigation: Inproc—order + reversed endpoints is authoritative; CorrMsgId only confirms; conflicts warn and still use order. Queue—CorrMsgId primary, ReturnQueueName fallback; if neither present, leave unpaired and warn.

- R-03 TimeCreated Ordering Ambiguity
  - Risk: TimeCreated granularity or storage differences create ambiguous ordering.
  - Mitigation: Deterministic tie-break on ID; fallback to ORDER BY ID when TimeCreated cannot be used.

- R-04 Large Sessions / Output Readability
  - Risk: Very large sessions (thousands of rows) can degrade readability and scanning performance.
  - Mitigation: Loop compression for contiguous repeated pairs; default full labels and strict correlation rules; keep comments concise.

- R-05 Identifier Sanitization Collisions
  - Risk: Different config names sanitize to identical identifiers.
  - Mitigation: Append numeric disambiguator suffix (_2, _3, …); preserve original labels.

- R-06 Silent Deduplication
  - Risk: Identical diagrams are removed silently; users might not realize duplicates were produced.
  - Mitigation: Document dedup default (ON) as intentional; users can re-run without dedup if they need all per-session outputs.

- R-07 Warning Visibility
  - Risk: Important issues (unknown Invocation, unpaired queued responses) may be overlooked.
  - Mitigation: Emit warnings inline as Mermaid “%%” comments near affected lines; also echo to stdout.

2) Assumptions
- A-01 IRIS 2023.2+ in target environments.
- A-02 Ens.MessageHeader is available for SQL-driven runs (SQL-only; CSV/out-of-band data modes are out of scope).
- A-03 Mermaid sequence diagrams are consumed via docs/markdown pipelines (no UI required).

3) Known Issues / Open Constraints
- K-01 Locale/case sensitivity in labels (Mermaid supports UTF-8; viewer differences may exist).
- K-02 ReturnQueueName semantics vary by production; treated as a best-effort fallback only.
- K-03 Exact “Type” values expected as “Request”/“Response”; non-standard values reduce correlation quality but do not fail generation (best-effort, emit warning if relevant).
- K-04 Mixed sync/async patterns in the same session can interleave—forward-scan logic relies on deterministic ordering and the strict queue/inproc policy.

4) Dependencies
- D-01 InterSystems IRIS Ens.MessageHeader availability and stability (SQL access).
- D-02 Mermaid sequence diagram rendering in downstream toolchains.
- D-03 Internal standards enforced via .clinerules (ObjectScript coding, testing).

5) Risk Tracking Plan
- Maintain a lightweight risk register (severity, likelihood, mitigation).
- Tie high-risk items to explicit test scenarios (e.g., unknown Invocation, unpaired queues, CorrMsgId conflicts).
- Reassess after early runs on representative sessions; capture findings in QA gate artifacts.

Traceability
- Aligns with Overview (00-overview.md constraints), informs Acceptance Criteria (60-acceptance-criteria.md) for warning behavior and determinism, and supports NFR-03 resilience and NFR-05 testability.
