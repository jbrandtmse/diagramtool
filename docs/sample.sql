-- MALIB.Util.DiagramTool — Sample SQL Snippets (PRD v4 aligned)
-- Primary data source: Ens.MessageHeader (SQL-only)
-- Exclusion: Filter out rows where MessageBodyClassName = 'HS.Util.Trace.Request'
-- Deterministic ordering: ORDER BY TimeCreated, ID; fallback to ORDER BY ID only

-- 1) Parameterized primary query (preferred ordering)
SELECT
  ID,
  Invocation,
  MessageBodyClassName,
  SessionId,
  SourceConfigName,
  TargetConfigName,
  ReturnQueueName,
  CorrespondingMessageId,
  TimeCreated,
  Type
FROM Ens.MessageHeader
WHERE SessionId = ?
  AND MessageBodyClassName <> 'HS.Util.Trace.Request'
ORDER BY TimeCreated, ID;

-- 2) Parameterized fallback query (ID-only ordering)
-- Use when TimeCreated ordering is not available in the target environment,
-- or when explicitly forcing deterministic ID-only tests.
SELECT
  ID,
  Invocation,
  MessageBodyClassName,
  SessionId,
  SourceConfigName,
  TargetConfigName,
  ReturnQueueName,
  CorrespondingMessageId,
  TimeCreated,
  Type
FROM Ens.MessageHeader
WHERE SessionId = ?
  AND MessageBodyClassName <> 'HS.Util.Trace.Request'
ORDER BY ID;

-- 3) Literal example for ad-hoc testing (replace 1584253 as needed)
-- Primary ordering example
SELECT
  ID,
  Invocation,
  MessageBodyClassName,
  SessionId,
  SourceConfigName,
  TargetConfigName,
  ReturnQueueName,
  CorrespondingMessageId,
  TimeCreated,
  Type
FROM Ens.MessageHeader
WHERE SessionId = 1584253
  AND MessageBodyClassName <> 'HS.Util.Trace.Request'
ORDER BY TimeCreated, ID;

-- Fallback ordering literal example
SELECT
  ID,
  Invocation,
  MessageBodyClassName,
  SessionId,
  SourceConfigName,
  TargetConfigName,
  ReturnQueueName,
  CorrespondingMessageId,
  TimeCreated,
  Type
FROM Ens.MessageHeader
WHERE SessionId = 1584253
  AND MessageBodyClassName <> 'HS.Util.Trace.Request'
ORDER BY ID;

-- Notes:
-- - These snippets align with docs/prd/40-data-sources-and-mapping.md#2-canonical-sql
-- - The story ST-002 now formalizes the loader signature and normalized row schema.
-- - Use the fallback ORDER BY ID path to validate deterministic behavior in tests that force ID-only ordering.
