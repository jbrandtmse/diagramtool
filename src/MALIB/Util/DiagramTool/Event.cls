Include (%occInclude, Ensemble)

Class MALIB.Util.DiagramTool.Event Extends %RegisteredObject
{

Property EventType As %String;

Property Src As %String;

Property Dst As %String;

Property Label As %String;

Property Arrow As %String;

Property Invocation As %String;

Property ID As %Integer;

Property PairWithID As %Integer;

Property CorrespondingMessageId As %Integer;

Property ReturnQueueName As %String;

Property SessionId As %Integer;

Property Notes As %String;

Property PairId As %Integer;

/// Loop-specific fields when EventType="Loop"
Property LoopCount As %Integer;

Property ReqSrc As %String;

Property ReqDst As %String;

Property ReqLabel As %String;

Property ReqArrow As %String;

Property RespSrc As %String;

Property RespDst As %String;

Property RespLabel As %String;

Property RespArrow As %String;

}
