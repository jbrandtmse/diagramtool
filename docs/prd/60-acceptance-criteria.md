# PRD v4 Shard — 60 Acceptance Criteria (BDD): MALIB.Util.DiagramTool

Status: Draft v4
Owner: PM (BMad)
Related: ../prd.md, 00-overview.md, 20-functional-requirements.md, 30-non-functional-requirements.md, 40-data-sources-and-mapping.md, 50-diagramming-rules.md

AC-01 Session Spec Parsing
- Given a session selector string "1, 5-7, 12"
- When the selector is parsed
- Then the result contains [1,5,6,7,12] in numeric order
- And invalid tokens (e.g., empty entries, non-numeric) are ignored without error

AC-02 Ordering Determinism (SQL-only)
- Given Ens.MessageHeader rows for a session
- When rows are loaded and ordered
- Then ordering is by TimeCreated then ID
- And if TimeCreated cannot be used, ordering falls back deterministically to ID only
- And repeated runs with the same data produce identical ordering

AC-03 Participant Extraction
- Given an ordered set of rows with SourceConfigName and TargetConfigName
- When participants are declared
- Then each unique participant is declared once in order of first appearance
- And participant identifiers are Mermaid-safe while labels preserve original names
- And if two identifiers collide after sanitization, a numeric suffix (_2, _3, …) is appended

AC-04 Labeling Defaults and Toggle
- Given MessageBodyClassName values are present
- When generating message labels with default settings
- Then each label is the full class name including package, sanitized for Mermaid
- When labelMode=short is specified at runtime
- Then each label is the last segment of the class name (after '.')

AC-05 Invocation Handling (Strict Recognition)
- Given rows contain Invocation values with various casing (e.g., "inproc", "QUEUE")
- When mapping arrow semantics
- Then "Inproc" is treated as synchronous (->>) and "Queue" as async (-->>)
- And any unknown Invocation value causes a "%%" warning comment and defaults to synchronous (->>) for that message

AC-06 Inproc Correlation with Confirmation
- Given a sequence of rows with Invocation = "Inproc"
- And Type alternates as Request then Response
- When correlating Request to Response
- Then the Response is identified by forward scan using reversed Source/Target and Type="Response"
- And if CorrespondingMessageId is present and matches, the pairing is confirmed
- And if CorrespondingMessageId conflicts, a "%%" warning is emitted and order-based pairing is still used

AC-07 Queued Correlation and Async Arrows
- Given queued interactions with Invocation = "Queue"
- When correlating queued requests and responses
- Then CorrespondingMessageId is used as the primary correlation key
- And when CorrespondingMessageId is missing, ReturnQueueName is used as fallback
- And if neither is available, the response remains unpaired and a "%%" warning is emitted
- And both the request and response arrows are async (-->>) for queued pairs

AC-08 Loop Detection and Compression
- Given contiguous repeated pairs of identical request/response signatures
- When generating the diagram
- Then repeated pairs are compressed into a Mermaid loop block with count N and the request/response lines inside
- And loop compression only applies to strictly contiguous identical pairs
- And when an interruption occurs (different signature), compression ends

AC-09 Per-Session Diagram Structure
- Given a single SessionId = S
- When generating the diagram
- Then output starts with `sequenceDiagram`
- And includes a comment header "%% Session S"
- And declares participants before message lines
- And emits message lines in order using the arrow mapping
- And non-fatal issues are emitted as "%%" warning comments near the relevant lines where feasible

AC-10 Multi-Session Deduplication (Default ON)
- Given two SessionIds that produce identical diagram text
- When generating with default settings
- Then only one copy of the identical diagram is included in the final output
- And no summary of removed SessionIds is emitted (silent deduplication)

AC-11 Output Contract — Append-Only with Divider
- Given any successful generation
- When writing diagrams to a file path
- Then the content is appended (append-only)
- And a divider comment "%% ---" is written between diagrams
- And the combined diagram text returned to the caller contains a blank line between diagrams
- And the combined text is echoed to terminal/stdout

AC-12 Minimal Diagram on Empty Session
- Given a SessionId with no rows after filtering
- When generating the diagram
- Then a valid Mermaid document is produced containing:
  - sequenceDiagram
  - %% Session <SessionId>
  - %% No data available (filtered or empty)

AC-13 Error Handling and Best-Effort
- Given partial or missing correlation fields (CorrespondingMessageId/ReturnQueueName)
- When generating diagrams
- Then best-effort output is produced without failing the run
- And a %Status is returned indicating success or error for programmatic use
- And warnings are emitted as "%%" comments where feasible (no strict-mode failures)

Out-of-Scope Confirmations (MVP)
- SuperSession composition
- CSV or non-SQL data modes
- Strict mode failures

Traceability
- FR-01, FR-02, FR-03, FR-04, FR-05, FR-06, FR-07, FR-08, FR-09, FR-10, FR-11, FR-12, FR-13, FR-14
- NFR-01, NFR-02, NFR-03, NFR-05
