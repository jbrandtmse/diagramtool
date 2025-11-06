# diagramtool

A workspace for the diagramtool project.

This repository contains editor/workspace settings and will evolve as code and assets are added.

## Repo housekeeping

- `.gitignore` covers common OS/editor, Node, and Python artifacts
- `.editorconfig` enforces consistent formatting across editors
- `.gitattributes` normalizes line endings and marks common binaries

## Getting started

Add your project files here. Update this README with:
- What the project does
- How to develop and run it
- Any prerequisites or dependencies

## Development Notes

### ST-002 — Data Load & Deterministic Ordering (SQL-only)

This project includes a loader that reads Ens.MessageHeader rows for a single SessionId with filtering and deterministic ordering for downstream correlation.

- Data source: Ens.MessageHeader (SQL-only; read-only access)
- Filtering: excludes rows where `MessageBodyClassName = "HS.Util.Trace.Request"`
- Default ordering: `ORDER BY TimeCreated, ID`
- Fallback ordering: `ORDER BY ID` (deterministic) when TimeCreated ordering is unavailable, or when forced (see below)
- Output shape: `%DynamicArray` of objects with normalized fields:
  - `ID, Invocation, MessageBodyClassName, SessionId, SourceConfigName, TargetConfigName, ReturnQueueName, CorrespondingMessageId, TimeCreated, Type`
  - Optional fields normalized: `ReturnQueueName=""`, `CorrespondingMessageId=""`

Contract (ObjectScript)
- Class: `MALIB.Util.DiagramTool`
- Method:
  - `ClassMethod LoadHeadersForSession(pSessionId As %Integer, Output pRows As %DynamicArray, pForceIdOnlyOrder As %Boolean = 0) As %Status`

Usage examples (ObjectScript)
```
Set sid = 1584253
Set rows = ""

// Default: ORDER BY TimeCreated, ID
Set tSC = ##class(MALIB.Util.DiagramTool).LoadHeadersForSession(sid, .rows)

#; Force ID-only fallback ordering (e.g., tests or legacy environments)
Set tSC = ##class(MALIB.Util.DiagramTool).LoadHeadersForSession(sid, .rows, 1)

#; Iterate results (0-based index for %DynamicArray)
If $IsObject(rows) {
    Set n = rows.%Size()
    For i=0:1:n-1 {
        Set obj = rows.%Get(i)
        Write obj.%Get("ID"), " ", obj.%Get("TimeCreated"), !
    }
}
```

Determinism and tie-breaks
- Repeated runs against identical data produce identical ordering
- When `TimeCreated` values are identical, ordering is deterministically tied by `ID` ascending

Performance guidance
- For production-scale datasets, ensure appropriate indexing on Ens.MessageHeader to avoid full scans:
  - Composite index `(SessionId, TimeCreated, ID)` for primary ordering
  - Secondary index `(SessionId, ID)` to support the ID-only fallback
- See PRD shard for details: docs/prd/40-data-sources-and-mapping.md#13-indexing-guidance
