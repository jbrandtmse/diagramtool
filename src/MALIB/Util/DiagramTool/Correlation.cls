Include (%occInclude, Ensemble)

Class MALIB.Util.DiagramTool.Correlation Extends %RegisteredObject
{

/// Map Invocation to Mermaid arrow semantics. Unknown -> default sync (->>)
ClassMethod ArrowForInvocation(pInvocation As %String = "") As %String
{
        Set tRaw = $Get(pInvocation)
        Set tInv = $ZCONVERT(tRaw,"U")

        ; Handle numeric enum values (Ens.DataType.MessageInvocation: 1=Queue, 2=Inproc)
        If tInv?1.N {
            Set tNum = +tInv
            If tNum=1 {
                Set tInv = "QUEUE"
            } ElseIf tNum=2 {
                Set tInv = "INPROC"
            }
        }

        If tInv = "INPROC" {
            Quit "->>"
        }
        If tInv = "QUEUE" {
            Quit "-->>"
        }
        Quit "->>"
}

/// Normalize a row's Type to logical "REQUEST"/"RESPONSE" (uppercase).
/// Handles string forms, numeric enum values (Ens.DataType.MessageType), and a
/// heuristic fallback (rows with CorrespondingMessageId are treated as responses).
ClassMethod NormalizeTypeU(pRow As %DynamicObject) As %String
{
        Quit:'$IsObject(pRow) ""
        Set tType = pRow.%Get("Type")
        Set tTypeU = $ZCONVERT(tType,"U")
        If (tTypeU="REQUEST")!(tTypeU="RESPONSE") {
            Quit tTypeU
        }
        Set tTypeNum = +tType
        If tTypeNum=$$$eMessageTypeRequest {
            Quit "REQUEST"
        }
        If tTypeNum=$$$eMessageTypeResponse {
            Quit "RESPONSE"
        }
        ; Heuristic fallback for SQL-loaded rows: infer from CorrMsgId
        If pRow.%Get("CorrespondingMessageId")'="" {
            Quit "RESPONSE"
        }
        Quit "REQUEST"
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
            Set tTypeU = ..NormalizeTypeU(r)

            ; Handle Requests
            If (tTypeU="REQUEST") {
                Set inv = r.%Get("Invocation")
                Set invU = $ZCONVERT(inv,"U")
                ; Normalize numeric invocation codes (Ens.DataType.MessageInvocation: 1=Queue, 2=Inproc)
                If invU?1.N {
                    Set invNum = +invU
                    If invNum=2 {
                        Set invU = "INPROC"
                    } ElseIf invNum=1 {
                        Set invU = "QUEUE"
                    }
                }

                ; Strict enum-based mode (PRD: Inproc -> sync, Queue -> async, unknown -> sync + warning)
                Set mode = invU

                Set arrowReq = ..ArrowForInvocation(mode)
                Set note = ""
                If (mode'="INPROC")&&(mode'="QUEUE") {
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

                ; Inproc (and unknown modes defaulted to sync): mark first reversed-endpoint response ahead
                If mode'="QUEUE" {
                    Set found=0
                    For j=i+1:1:len-1 {
                        Set c = pRows.%Get(j)
                        Continue:'$IsObject(c)
                        Continue:..NormalizeTypeU(c)'="RESPONSE"
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
                                Do evReq.%Set("PairWithID",cID)
                                Do evReq.%Set("PairId",nextPairId)
                                Set nextPairId = nextPairId + 1
                                Set usedResp(cID)=1
                                Set found=1
                                Quit
                            }
                        }
                    }
                } ElseIf mode="QUEUE" {
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
                        Continue:..NormalizeTypeU(c)'="RESPONSE"
                        Set cID = c.%Get("ID")
                        Continue:$Get(usedResp(cID))
                        Set cCorr = c.%Get("CorrespondingMessageId")
                        If (cCorr'="")&(+cCorr=+reqID) {
                            Set pairReqByResp(cID) = reqID
                            Set pairArrowByResp(cID) = "-->>"
                            Set pairIdByResp(cID) = nextPairId
                            Set pairIdByReq(reqID) = nextPairId
                            Do evReq.%Set("PairWithID",cID)
                            Do evReq.%Set("PairId",nextPairId)
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
                            Continue:..NormalizeTypeU(c)'="RESPONSE"
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
                                Do evReq.%Set("PairWithID",cID)
                                Do evReq.%Set("PairId",nextPairId)
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
                    ; Best-effort standalone response (never silently drop a message row)
                    Set invU = $ZCONVERT(r.%Get("Invocation"),"U")
                    ; Normalize numeric invocation codes here as well (Ens.DataType.MessageInvocation: 1=Queue, 2=Inproc)
                    If invU?1.N {
                        Set invNum = +invU
                        If invNum=2 {
                            Set invU = "INPROC"
                        } ElseIf invNum=1 {
                            Set invU = "QUEUE"
                        }
                    }
                    If invU="QUEUE" {
                        Set respArrow = "-->>"
                        Set respWarn = "Warning: Unpaired queued response at ID="_r.%Get("ID")_"; no matching request found"
                    } Else {
                        Set respArrow = "->>"
                        Set respWarn = "Warning: Unpaired inproc response at ID="_r.%Get("ID")_"; no matching request found"
                    }
                    Set evResp = ##class(%DynamicObject).%New()
                    Do evResp.%Set("EventType","Response")
                    Do evResp.%Set("Src",r.%Get("SourceConfigName"))
                    Do evResp.%Set("Dst",r.%Get("TargetConfigName"))
                    Do evResp.%Set("Label",r.%Get("MessageBodyClassName"))
                    Do evResp.%Set("Arrow",respArrow)
                    Do evResp.%Set("Invocation",r.%Get("Invocation"))
                    Do evResp.%Set("ID",r.%Get("ID"))
                    Do evResp.%Set("PairWithID","")
                    Do evResp.%Set("CorrespondingMessageId",r.%Get("CorrespondingMessageId"))
                    Do evResp.%Set("ReturnQueueName",r.%Get("ReturnQueueName"))
                    Do evResp.%Set("SessionId",r.%Get("SessionId"))
                    Do evResp.%Set("Notes",respWarn)
                    Do evResp.%Set("PairId","")
                    Do pEvents.%Push(evResp)
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
