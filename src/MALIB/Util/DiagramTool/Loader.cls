Include (%occInclude, Ensemble)

Class MALIB.Util.DiagramTool.Loader Extends %RegisteredObject
{

/// <h3>ST-002 — Data Load & Deterministic Ordering (SQL-only)</h3>
/// <p>Load Ens.MessageHeader rows for a single SessionId with filtering and deterministic ordering for downstream correlation.</p>
/// <ul>
///   <li>Filter: exclude MessageBodyClassName = "HS.Util.Trace.Request"</li>
///   <li>Default ordering: ORDER BY TimeCreated, ID</li>
///   <li>Fallback: ORDER BY ID when pForceIdOnlyOrder=1 or primary ordering is unavailable</li>
///   <li>Output: pRows is a %DynamicArray of row objects with normalized fields</li>
/// </ul>
/// <b>Contract</b>:
/// <pre>ClassMethod LoadHeadersForSession(pSessionId As %Integer, Output pRows As %DynamicArray, pForceIdOnlyOrder As %Boolean = 0) As %Status</pre>
ClassMethod LoadHeadersForSession(pSessionId As %Integer, Output pRows As %DynamicArray, pForceIdOnlyOrder As %Boolean = 0) As %Status
{
    ; Initialize status and output
    Set tSC = $$$OK
    Set pRows = ##class(%DynamicArray).%New()

    ; Best-effort: empty result for invalid/non-positive session id
    If (+$Get(pSessionId,0))<1 {
        Quit tSC
    }

    ; Host variables for FETCH
    Set tID="", tInvocation="", tBody="", tSess=0, tSource="", tTarget="", tRet="", tCorr="", tTime="", tType=""

    ; Prepare cursors for both primary and fallback ordering
    &sql(DECLARE C1 CURSOR FOR
        SELECT
          ID, Invocation, MessageBodyClassName, SessionId,
          SourceConfigName, TargetConfigName,
          ReturnQueueName, CorrespondingMessageId,
          TimeCreated, Type
        FROM Ens.MessageHeader
        WHERE SessionId = :pSessionId
          AND MessageBodyClassName <> 'HS.Util.Trace.Request'
        ORDER BY TimeCreated, ID)
    &sql(DECLARE C2 CURSOR FOR
        SELECT
          ID, Invocation, MessageBodyClassName, SessionId,
          SourceConfigName, TargetConfigName,
          ReturnQueueName, CorrespondingMessageId,
          TimeCreated, Type
        FROM Ens.MessageHeader
        WHERE SessionId = :pSessionId
          AND MessageBodyClassName <> 'HS.Util.Trace.Request'
        ORDER BY ID)
    Set tCur = ""
    If 'pForceIdOnlyOrder {
        &sql(OPEN C1)
        If SQLCODE'=0 {
            &sql(OPEN C2)
            Set tCur = "C2"
        } Else {
            Set tCur = "C1"
        }
    } Else {
        &sql(OPEN C2)
        Set tCur = "C2"
    }

    ; Fetch rows and normalize into dynamic objects
    For {
        If tCur="C1" {
            &sql(FETCH C1 INTO :tID, :tInvocation, :tBody, :tSess, :tSource, :tTarget, :tRet, :tCorr, :tTime, :tType)
        } Else {
            &sql(FETCH C2 INTO :tID, :tInvocation, :tBody, :tSess, :tSource, :tTarget, :tRet, :tCorr, :tTime, :tType)
        }
        Quit:SQLCODE

        ; Normalize Type to logical "Request"/"Response" when stored as enum
        Set tTypeLogical = $Get(tType)
        Set tTypeU = $ZCONVERT(tTypeLogical,"U")
        If (tTypeU'="REQUEST")&&(tTypeU'="RESPONSE") {
            Set tTypeNum = +tTypeLogical
            If tTypeNum=$$$eMessageTypeRequest {
                Set tTypeLogical = "Request"
            } ElseIf tTypeNum=$$$eMessageTypeResponse {
                Set tTypeLogical = "Response"
            }
        }

        Set row = ##class(%DynamicObject).%New()
        Set row.ID = tID
        Set row.Invocation = $Get(tInvocation)
        Set row.MessageBodyClassName = $Get(tBody)
        Set row.SessionId = tSess
        Set row.SourceConfigName = $Get(tSource)
        Set row.TargetConfigName = $Get(tTarget)
        Set row.ReturnQueueName = $Get(tRet,"")
        Set row.CorrespondingMessageId = $Get(tCorr,"")
        Set row.TimeCreated = $Get(tTime,"")
        Set row.Type = tTypeLogical
        Do pRows.%Push(row)
    }

    ; Close whichever cursor we used
    If tCur="C1" {
        &sql(CLOSE C1)
    } ElseIf tCur="C2" {
        &sql(CLOSE C2)
    }

    Quit tSC
}

}
