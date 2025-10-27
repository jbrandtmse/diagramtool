# PRD v4 Shard — 80 Milestones and Plan: MALIB.Util.DiagramTool

Status: Draft v4
Owner: PM (BMad)
Related: ../prd.md, 00-overview.md, 20-functional-requirements.md, 30-non-functional-requirements.md, 40-data-sources-and-mapping.md, 50-diagramming-rules.md, 60-acceptance-criteria.md, 70-risks-issues.md

Milestone M0 — Planning (Docs-First)
- Inputs: Business goal, Ens.MessageHeader schema, Mermaid rules, .clinerules
- Outputs:
  - Project Brief (docs/project-brief.md)
  - PRD v4 (docs/prd.md) + shards (00/20/30/40/50/60/70/80/90)
  - Decisions finalized:
    - Labels: default full MessageBodyClassName (sanitized), labelMode runtime toggle (full|short, default=full)
    - Invocation: strict recognition (Inproc/Queue only), unknown → %% warning + default sync
    - Queue arrows: both legs async (-->>)
    - Correlation: Inproc order+reversed (CorrMsgId confirms; conflict warns but still order). Queue CorrMsgId → ReturnQueueName; else unpaired + warn
    - Exclusions: only HS.Util.Trace.Request
    - Output: append-only file writes, divider comment (%% ---), dedup ON (silent)
    - Warnings: %% comments; best-effort (no strict mode)
- Gate: PM/Architect sign-off on scope and decisions

Milestone M1 — Rule Freeze
- Activities:
  - Lock Mermaid/label/arrow/correlation/loop/append/dedup rules
  - Align FR/NFR/Mapping/Diagramming/AC shards to frozen rules
- Outputs:
  - 20/30/40/50/60 updated and stable
- Gate: Architect approval (no breaking rule changes after this)

Milestone M2 — Story Drafting and PO Refinement
- Activities:
  - Create stories to cover:
    - ST-001 Session spec parsing (existing)
    - ST-002 Data load & ordering (SQL-only; no CSV) (update)
    - ST-003 Correlation rules (Inproc confirm; Queue CorrMsgId→ReturnQueueName; warnings)
    - ST-004 Loop detection (contiguous identical pairs)
    - ST-005 Multi-session output (append-only, divider, dedup ON silent; labelMode toggle; warnings)
  - PO refinement to add/clarify acceptance criteria per shard 60
- Outputs:
  - Stories under docs/stories/ marked Draft → Ready for Dev
- Gate: Stories marked “Ready for Dev” (not Draft)

Milestone M3 — Implementation (Dev)
- Activities (after Ready for Dev):
  - Implement stories sequentially
  - Add unit tests mapping directly to shard 60 ACs
  - Ensure warnings as %% comments where applicable
- Outputs:
  - Compiling ObjectScript classes and passing unit tests
- Gate: All story DoD checks pass (story-level)

Milestone M4 — QA Gate and Test Design
- Activities:
  - QA review (risk profile, traceability, test design)
  - Produce QA gate decision (PASS/CONCERNS/FAIL/WAIVED)
- Outputs:
  - QA gate file and “QA Results” updates in stories
- Gate: Advisory sign-off to proceed to packaging

Milestone M5 — Packaging and Documentation
- Activities:
  - README usage examples (SQL-only), labelMode toggle, dedup behavior, append-only with divider, warning conventions
  - ZPM packaging deferred (document-only note, no implementation)
- Outputs:
  - Developer-ready documentation and release notes
- Gate: Release notes prepared

High-Level Timeline (indicative)
- Week 1: M0–M1 (docs-finalization and rule freeze)
- Week 2: M2 stories + PO review
- Weeks 3–4: M3 implementation + unit tests
- Week 5: M4 QA gate + refinements
- Week 6: M5 packaging/docs (ZPM out of scope)

Dependencies and Gates
- PRD stability (M0) before M1 freeze
- Rule freeze (M1) before coding (M3)
- Stories “Ready for Dev” (M2) before Dev starts
- QA gate (M4) before packaging (M5)

Success Criteria
- All ACs in 60-acceptance-criteria.md demonstrably met
- SQL-only data path validated
- Deterministic output, queue both-leg async mapping, correlation policies enforced
- Append-only output with divider and dedup ON (silent) verified
- Clear developer documentation and usage patterns

Traceability
- Drives execution plan from Overview and FR/NFR shards
- Establishes gating points aligned with BMAD workflow
