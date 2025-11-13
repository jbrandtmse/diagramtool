Include %occInclude

Class MALIB.Util.DiagramTool Extends %RegisteredObject
{

/// <p>Parse a session selector string into a %List of positive integer session IDs.</p>
/// <ul>
/// <li>Accepts single integers (e.g., "15")</li>
/// <li>Accepts ranges "a-b" where a ≤ b and both positive integers</li>
/// <li>Whitespace-insensitive; invalid tokens ignored without error</li>
/// <li>Returns deterministic ascending-ordered list; duplicates preserved</li>
/// </ul>
/// <p>Examples:</p>
/// <pre>
/// "1, 5-7, 12" -> $LB(1,5,6,7,12)
/// "2-2"        -> $LB(2)
/// "3-1"        -> $LB()
/// "1,,4"       -> $LB(1,4)
/// "a,1,2-b,9"  -> $LB(1,9)
/// </pre>
ClassMethod ParseSessionSpec(pSelector As %String = "") As %List
{
    Set ^ClineDebug = ""
    Set ^ClineDebug = ^ClineDebug _ "start; "
    Set tOut = $LISTBUILD()
    Set ^ClineDebug = ^ClineDebug _ "after out; "
    Set tSelector = $GET(pSelector)
    Set ^ClineDebug = ^ClineDebug _ "after selector; "
    If tSelector = "" Quit tOut

    ; Collect counts for each number to preserve duplicates, then sort
    ; Use local array: tMap(num) = count
    ; Tokenize by comma
    Set tTokens = $LISTFROMSTRING(tSelector, ",")
    For tI=1:1:$LISTLENGTH(tTokens) {
        Set tTok = $ZSTRIP($LISTGET(tTokens, tI), "<>W")
        If tTok = "" {
            ; ignore empty tokens like "1,,4"
        } Else {
            ; Range detection: token contains a hyphen between two numeric parts
            If tTok [ "-" {
                Set tParts = $LISTFROMSTRING(tTok, "-")
                If $LISTLENGTH(tParts) = 2 {
                    Set tStartStr = $ZSTRIP($LISTGET(tParts, 1), "<>W")
                    Set tEndStr   = $ZSTRIP($LISTGET(tParts, 2), "<>W")
                    If (tStartStr ? 1.N) && (tEndStr ? 1.N) {
                        Set tStart = +tStartStr, tEnd = +tEndStr
                        If (tStart > 0) && (tEnd > 0) && (tStart <= tEnd) {
                            For tN=tStart:1:tEnd {
                                Set tMap(tN) = $GET(tMap(tN), 0) + 1
                            }
                        }
                    }
                }
            } Else {
                ; Single integer token
                If tTok ? 1.N {
                    Set tN = +tTok
                    If tN > 0 {
                        Set tMap(tN) = $GET(tMap(tN), 0) + 1
                    }
                }
            }
        }
    }

    ; Rebuild ascending-ordered list with duplicates preserved
    Set tNum = ""
    For {
        Set tNum = $ORDER(tMap(tNum))
        Quit:(tNum = "")
        Set tCount = +$GET(tMap(tNum), 0)
        If tCount > 0 {
            For tJ=1:1:tCount {
                ; Append item using explicit position append (avoid leading empty)
                Set tPos = $LISTLENGTH(tOut) + 1
                Set $LIST(tOut,tPos) = +tNum
            }
        }
    }

    ; Clean any accidental empty elements
    Set tClean = $LISTBUILD()
    For tK=1:1:$LISTLENGTH(tOut) {
        Set tVal = $LISTGET(tOut,tK)
        If tVal'="" {
            Set tPos = $LISTLENGTH(tClean) + 1
            Set $LIST(tClean,tPos) = tVal
        }
    }
    Quit tClean
}

ClassMethod DebugParseSessionSpecToString(pSelector As %String = "") As %String
{
    Set tList = ##class(MALIB.Util.DiagramTool).ParseSessionSpec(pSelector)
    Set s = ""
    Set len = $LISTLENGTH(tList)
    For i=1:1:len {
        If i>1 Set s = s_","
        Set s = s_$LISTGET(tList,i)
    }
    Quit s
}

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
        Set row.Type = $Get(tType)
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

/// Map Invocation to Mermaid arrow semantics. Unknown -> default sync (->>)
ClassMethod ArrowForInvocation(pInvocation As %String = "") As %String
{
        Set tInv = $ZCONVERT($Get(pInvocation),"U")
        If tInv = "INPROC" {
            Quit "->>"
        }
        If tInv = "QUEUE" {
            Quit "-->>"
        }
        Quit "->>"
}

/// Correlate request/response events according to ST-003 rules.
/// Forward-only scan; warnings recorded in Notes; preserves row order by emitting responses when encountered.
ClassMethod CorrelateEvents(pRows As %DynamicArray, Output pEvents As %DynamicArray) As %Status
{
        Set tSC = $$$OK
        Set pEvents = ##class(%DynamicArray).%New()
        Quit:'$IsObject(pRows) tSC

        Set len = pRows.%Size()
        Kill usedResp, pairReqByResp, pairArrowByResp, pairNoteByResp, pairIdByResp, pairIdByReq
        Set nextPairId = 1

        For i=0:1:len-1 {
            Set r = pRows.%Get(i)
            Continue:'$IsObject(r)
            Set tType = r.%Get("Type")
            Set tTypeU = $ZCONVERT(tType,"U")

            ; Handle Requests
            If (tTypeU="REQUEST") {
                Set inv = r.%Get("Invocation")
                Set invU = $ZCONVERT(inv,"U")
                Set arrowReq = ..ArrowForInvocation(inv)
                Set note = ""
                If (invU'="INPROC")&&(invU'="QUEUE") {
                    Set note = "Warning: Unknown Invocation '"_inv_"' at ID="_r.%Get("ID")_"; defaulting to sync (->>)"
                }

                ; Emit Request event
                Set evReq = ##class(%DynamicObject).%New()
                Do evReq.%Set("EventType","Request")
                Do evReq.%Set("Src",r.%Get("SourceConfigName"))
                Do evReq.%Set("Dst",r.%Get("TargetConfigName"))
                Do evReq.%Set("Label",r.%Get("MessageBodyClassName"))
                Do evReq.%Set("Arrow",arrowReq)
                Do evReq.%Set("Invocation",inv)
                Do evReq.%Set("ID",r.%Get("ID"))
                Do evReq.%Set("PairWithID","")
                Do evReq.%Set("CorrespondingMessageId",r.%Get("CorrespondingMessageId"))
                Do evReq.%Set("ReturnQueueName",r.%Get("ReturnQueueName"))
                Do evReq.%Set("SessionId",r.%Get("SessionId"))
                If note'="" Do evReq.%Set("Notes",note)
                Do evReq.%Set("PairId","")
                Do pEvents.%Push(evReq)

                ; Inproc: mark first reversed-endpoint response ahead
                If invU="INPROC" {
                    Set found=0
                    For j=i+1:1:len-1 {
                        Set c = pRows.%Get(j)
                        Continue:'$IsObject(c)
                        Set cTypeU = $ZCONVERT(c.%Get("Type"),"U")
                        Continue:cTypeU'="RESPONSE"
                        Set cSrc = c.%Get("SourceConfigName")
                        Set cDst = c.%Get("TargetConfigName")
                        If (cSrc=r.%Get("TargetConfigName"))&(cDst=r.%Get("SourceConfigName")) {
                            Set cID = c.%Get("ID")
                            If '$Get(usedResp(cID)) {
                                ; CorrMsgId conflict check (still pair by order)
                                Set cCorr = c.%Get("CorrespondingMessageId")
                                If (cCorr'="") {
                                    If (cCorr=r.%Get("ID")) {
                                        ; confirmed match - no warning
                                    } Else {
                                        Set pairNoteByResp(cID) = "Warning: CorrMsgId conflict between ReqID="_r.%Get("ID")_" and RespID="_cID_"; using order-based pairing"
                                    }
                                }
                                Set pairReqByResp(cID) = r.%Get("ID")
                                Set pairArrowByResp(cID) = "->>"
                                Set pairIdByResp(cID) = nextPairId
                                Set pairIdByReq(r.%Get("ID")) = nextPairId
                                Set nextPairId = nextPairId + 1
                                Set usedResp(cID)=1
                                Set found=1
                                Quit
                            }
                        }
                    }
                } ElseIf invU="QUEUE" {
                    ; Queue: CorrMsgId primary, ReturnQueueName fallback with reversed endpoints
                    Set reqID = r.%Get("ID")
                    Set reqRQN = r.%Get("ReturnQueueName")
                    Set reqSrc = r.%Get("SourceConfigName")
                    Set reqDst = r.%Get("TargetConfigName")
                    Set found=0

                    ; Primary: CorrMsgId
                    For j=i+1:1:len-1 {
                        Set c = pRows.%Get(j)
                        Continue:'$IsObject(c)
                        Set cTypeU = $ZCONVERT(c.%Get("Type"),"U")
                        Continue:cTypeU'="RESPONSE"
                        Set cID = c.%Get("ID")
                        Continue:$Get(usedResp(cID))
                        Set cCorr = c.%Get("CorrespondingMessageId")
                        If (cCorr'="")&(cCorr=reqID) {
                            Set pairReqByResp(cID) = reqID
                            Set pairArrowByResp(cID) = "-->>"
                            Set pairIdByResp(cID) = nextPairId
                            Set pairIdByReq(reqID) = nextPairId
                            Set nextPairId = nextPairId + 1
                            Set usedResp(cID)=1
                            Set found=1
                            Quit
                        }
                    }

                    ; Fallback: ReturnQueueName + reversed endpoints
                    If 'found {
                        For j=i+1:1:len-1 {
                            Set c = pRows.%Get(j)
                            Continue:'$IsObject(c)
                            Set cTypeU = $ZCONVERT(c.%Get("Type"),"U")
                            Continue:cTypeU'="RESPONSE"
                            Set cID = c.%Get("ID")
                            Continue:$Get(usedResp(cID))
                            Set cRQN = c.%Get("ReturnQueueName")
                            Set cSrc = c.%Get("SourceConfigName")
                            Set cDst = c.%Get("TargetConfigName")
                            Set cCorr = c.%Get("CorrespondingMessageId")
                            If (cCorr="")&(cRQN'="")&(cRQN=reqRQN)&(cSrc=reqDst)&(cDst=reqSrc) {
                                Set pairReqByResp(cID) = reqID
                                Set pairArrowByResp(cID) = "-->>"
                                Set pairIdByResp(cID) = nextPairId
                                Set pairIdByReq(reqID) = nextPairId
                                Set nextPairId = nextPairId + 1
                                Set usedResp(cID)=1
                                Set found=1
                                Quit
                            }
                        }
                    }

                    ; Unpaired queued request warning
                    If 'found {
                        Set warn = "Warning: Unpaired queued request at ID="_reqID_"; missing or unmatched CorrMsgId/ReturnQueueName"
                        If evReq.%IsDefined("Notes") {
                            Set prev = evReq.%Get("Notes")
                            Do evReq.%Set("Notes",prev_" | "_warn)
                        } Else {
                            Do evReq.%Set("Notes",warn)
                        }
                    }
                }
            }
            ; Handle Responses as we encounter them (preserve order)
            ElseIf (tTypeU="RESPONSE") {
                Set respID = r.%Get("ID")
                If $Data(pairReqByResp(respID)) {
                    Set reqID = pairReqByResp(respID)
                    Set respArrow = $Get(pairArrowByResp(respID),"->>")
                    Set evResp = ##class(%DynamicObject).%New()
                    Do evResp.%Set("EventType","Response")
                    Do evResp.%Set("Src",r.%Get("SourceConfigName"))
                    Do evResp.%Set("Dst",r.%Get("TargetConfigName"))
                    Do evResp.%Set("Label",r.%Get("MessageBodyClassName"))
                    Do evResp.%Set("Arrow",respArrow)
                    Do evResp.%Set("Invocation",r.%Get("Invocation"))
                    Do evResp.%Set("ID",respID)
                    Do evResp.%Set("PairWithID",reqID)
                    Do evResp.%Set("CorrespondingMessageId",r.%Get("CorrespondingMessageId"))
                    Do evResp.%Set("ReturnQueueName",r.%Get("ReturnQueueName"))
                    Do evResp.%Set("SessionId",r.%Get("SessionId"))
                    If $Data(pairNoteByResp(respID)) {
                        Do evResp.%Set("Notes",pairNoteByResp(respID))
                    }
                    Do evResp.%Set("PairId",$Get(pairIdByResp(respID),""))
                    Do pEvents.%Push(evResp)
                } Else {
                    ; Best-effort standalone Inproc response
                    Set invU = $ZCONVERT(r.%Get("Invocation"),"U")
                    If invU="INPROC" {
                        Set evResp = ##class(%DynamicObject).%New()
                        Do evResp.%Set("EventType","Response")
                        Do evResp.%Set("Src",r.%Get("SourceConfigName"))
                        Do evResp.%Set("Dst",r.%Get("TargetConfigName"))
                        Do evResp.%Set("Label",r.%Get("MessageBodyClassName"))
                        Do evResp.%Set("Arrow","->>")
                        Do evResp.%Set("Invocation",r.%Get("Invocation"))
                        Do evResp.%Set("ID",r.%Get("ID"))
                        Do evResp.%Set("PairWithID","")
                        Do evResp.%Set("CorrespondingMessageId",r.%Get("CorrespondingMessageId"))
                        Do evResp.%Set("ReturnQueueName",r.%Get("ReturnQueueName"))
                        Do evResp.%Set("SessionId",r.%Get("SessionId"))
                        Do evResp.%Set("Notes","Warning: Unpaired inproc response at ID="_r.%Get("ID")_"; no matching request found")
                        Do evResp.%Set("PairId","")
                        Do pEvents.%Push(evResp)
                    }
                }
            }
        }

        Quit tSC
}

/// Helper to extract inproc pairs from CorrelateEvents results
ClassMethod PairInproc(pRows As %DynamicArray, Output pPairs As %DynamicArray) As %Status
{
        Set pPairs = ##class(%DynamicArray).%New()
        Set evs = ""
        Set tSC = ..CorrelateEvents(pRows, .evs)
        Quit:$$$ISERR(tSC) tSC
        Set len = evs.%Size()
        For i=0:1:len-1 {
            Set ev = evs.%Get(i)
            Continue:'$IsObject(ev)
            If ev.%Get("EventType")="Response", $ZCONVERT(ev.%Get("Invocation"),"U")="INPROC", ev.%Get("PairWithID")'="" {
                Set pair = ##class(%DynamicObject).%New()
                Do pair.%Set("RequestID",ev.%Get("PairWithID"))
                Do pair.%Set("ResponseID",ev.%Get("ID"))
                Do pair.%Set("PairId",ev.%Get("PairId"))
                Do pPairs.%Push(pair)
            }
        }
        Quit tSC
}

/// Helper to extract queued pairs from CorrelateEvents results
ClassMethod PairQueued(pRows As %DynamicArray, Output pPairs As %DynamicArray) As %Status
{
        Set pPairs = ##class(%DynamicArray).%New()
        Set evs = ""
        Set tSC = ..CorrelateEvents(pRows, .evs)
        Quit:$$$ISERR(tSC) tSC
        Set len = evs.%Size()
        For i=0:1:len-1 {
            Set ev = evs.%Get(i)
            Continue:'$IsObject(ev)
            If ev.%Get("EventType")="Response", $ZCONVERT(ev.%Get("Invocation"),"U")="QUEUE", ev.%Get("PairWithID")'="" {
                Set pair = ##class(%DynamicObject).%New()
                Do pair.%Set("RequestID",ev.%Get("PairWithID"))
                Do pair.%Set("ResponseID",ev.%Get("ID"))
                Do pair.%Set("PairId",ev.%Get("PairId"))
                Do pPairs.%Push(pair)
            }
        }
        Quit tSC
}

}
