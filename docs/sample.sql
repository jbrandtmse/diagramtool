SELECT 
ID, Banked, BusinessProcessId, CorrespondingMessageId, Description, ErrorStatus, Invocation, IsError, MessageBodyClassName, MessageBodyId, Priority, Resent, ReturnQueueName, SessionId, SourceBusinessType, SourceConfigName, Status, SuperSession, TargetBusinessType, TargetConfigName, TargetQueueName, TimeCreated, TimeProcessed, Type
FROM Ens.MessageHeader
WHERE SessionId = 1584253
And MessageBodyClassName != 'HS.Util.Trace.Request'