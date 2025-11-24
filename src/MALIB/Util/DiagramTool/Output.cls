Include (%occInclude, Ensemble)

Class MALIB.Util.DiagramTool.Output Extends %RegisteredObject
{

/// ST-006 helper — Build a single-session Mermaid diagram from loaded rows
/// ST-004 — Applies loop compression over correlated events before rendering
ClassMethod BuildDiagramForSession(pSessionId As %Integer, pRows As %DynamicArray, pLabelMode As %String, Output pDiagram As %String) As %Status
{
    Set tSC = $$$OK
    Set pDiagram = ""
    Set ^ClineDebug2 = "BuildDiag sid="_pSessionId_"; "

    ; Empty or invalid rows -> minimal diagram
    If '$IsObject(pRows) {
        Set pDiagram = "sequenceDiagram"_$Char(13,10)_
                       "%% Session "_pSessionId_$Char(13,10)_
                       "%% No data available (filtered or empty)"
        Quit tSC
    }
    If 'pRows.%Size() {
        Set pDiagram = "sequenceDiagram"_$Char(13,10)_
                       "%% Session "_pSessionId_$Char(13,10)_
                       "%% No data available (filtered or empty)"
        Quit tSC
    }

    ; Log raw rows for debugging (size and endpoints)
    Set ^ClineDebug2 = ^ClineDebug2_"rowsz="_pRows.%Size()_"; "
    Set k=""
    For k=0:1:pRows.%Size()-1 {
        Set row = pRows.%Get(k)
        Continue:'$IsObject(row)
        Set ^ClineDebug2 = ^ClineDebug2_"rowID="_row.%Get("ID")_" src="_row.%Get("SourceConfigName")_" dst="_row.%Get("TargetConfigName")_"; "
    }

    ; Correlate events from rows (dynamic objects)
    Set tEventsDyn = ""
    Set tSC = ##class(MALIB.Util.DiagramTool.Correlation).CorrelateEvents(pRows, .tEventsDyn)
    If $$$ISERR(tSC) {
        Quit tSC
    }

    ; Convert dynamic events to typed Event objects
    Set tEvents = ""
    Set tSC = ..ConvertDynamicToEvents(tEventsDyn, .tEvents)
    If $$$ISERR(tSC) {
        Quit tSC
    }

    ; Apply loop detection/compression (ST-004) over typed events
    Set tLooped = ""
    Set tSC = ..ApplyLoopCompression(tEvents, .tLooped)
    If $$$ISERR(tSC) {
        Quit tSC
    }

    ; Header and session comment
    Set lines = "sequenceDiagram"_$Char(13,10)_"%% Session "_pSessionId

    ; Collect participants solely from loaded rows (independent of loop compression)
    Kill tPart
    Set lenRows = pRows.%Size()
    For i=0:1:lenRows-1 {
        Set row = pRows.%Get(i)
        Continue:'$IsObject(row)
        Set src = row.%Get("SourceConfigName")
        Set dst = row.%Get("TargetConfigName")
        If src'="" Set tPart(src)=""
        If dst'="" Set tPart(dst)=""
    }

    ; Emit participants
    Set name=""
    For {
        Set name = $Order(tPart(name))
        Quit:name=""
        Set lines = lines_$Char(13,10)_"participant "_name
    }

    ; Emit events and loop blocks as Mermaid arrows
    If '$IsObject(tLooped) {
        Set pDiagram = lines
        Quit tSC
    }

    Set len = tLooped.%Size()
    For i=0:1:len-1 {
        Set ev = tLooped.%Get(i)
        Continue:'$IsObject(ev)

        Set evType = $ZCONVERT(ev.EventType,"U")

        ; Loop block
        If evType="LOOP" {
            Set count = +ev.LoopCount
            ; Defensive: if LoopCount<2, fall back to plain lines
            If count<2 {
                Do ..EmitLoopAsPlain(.lines, ev, pLabelMode)
                Continue
            }

            ; Loop header label respects label mode
            Set loopLabel = ..NormalizeLabelForMode(ev.Label, pLabelMode)
            If loopLabel="" {
                Set loopLabel = "loop"
            }

            ; Emit loop header
            Set lines = lines_$Char(13,10)_"loop "_count_" times "_loopLabel

            ; Emit inner request/response lines with indentation
            Do ..EmitLoopInnerLines(.lines, ev, pLabelMode, 1)

            ; Close loop block
            Set lines = lines_$Char(13,10)_"end"
            Continue
        }

        ; Non-loop event — existing arrow emission behavior
        Do ..EmitEventLine(.lines, ev, pRows, pLabelMode, 0)
    }

    Set pDiagram = lines
    Quit tSC
}

/// Helper — convert correlated %DynamicObject events into typed Event objects
ClassMethod ConvertDynamicToEvents(pIn As %DynamicArray, Output pOut As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set pOut = ##class(%DynamicArray).%New()

    If '$IsObject(pIn) {
        Quit tSC
    }

    Set len = pIn.%Size()
    For i=0:1:len-1 {
        Set d = pIn.%Get(i)
        Continue:'$IsObject(d)

        Set ev = ##class(MALIB.Util.DiagramTool.Event).%New()
        Set ev.EventType              = d.%Get("EventType")
        Set ev.Src                    = d.%Get("Src")
        Set ev.Dst                    = d.%Get("Dst")
        Set ev.Label                  = d.%Get("Label")
        Set ev.Arrow                  = d.%Get("Arrow")
        Set ev.Invocation             = d.%Get("Invocation")
        Set ev.ID                     = +d.%Get("ID")
        Set ev.PairWithID             = +d.%Get("PairWithID")
        Set ev.CorrespondingMessageId = +d.%Get("CorrespondingMessageId")
        Set ev.ReturnQueueName        = d.%Get("ReturnQueueName")
        Set ev.SessionId              = +d.%Get("SessionId")
        Set ev.Notes                  = d.%Get("Notes")
        Set ev.PairId                 = +d.%Get("PairId")

        Do pOut.%Push(ev)
    }

    Quit tSC
}

/// ST-004 helper — Apply loop detection/compression over typed events
ClassMethod ApplyLoopCompression(pEvents As %DynamicArray, Output pOutEvents As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set pOutEvents = ##class(%DynamicArray).%New()

    ; Non-object or empty input -> empty output (best-effort pass-through)
    If '$IsObject(pEvents) {
        Quit tSC
    }
    If 'pEvents.%Size() {
        Quit tSC
    }

    Set len = pEvents.%Size()
    Set i = 0

    While (i<len) {
        Set ev = pEvents.%Get(i)
        If '$IsObject(ev) {
            Set i = i + 1
            Continue
        }

        Set evType = $ZCONVERT(ev.EventType,"U")

        ; Only Requests can start a compressed pair sequence
        If evType'="REQUEST" {
            Do pOutEvents.%Push(ev)
            Set i = i + 1
            Continue
        }

        ; Need a following Response to form at least one pair
        If (i+1)>(len-1) {
            Do pOutEvents.%Push(ev)
            Set i = i + 1
            Continue
        }

        Set evNext = pEvents.%Get(i+1)
        If '$IsObject(evNext) {
            Do pOutEvents.%Push(ev)
            Set i = i + 1
            Continue
        }

        Set evNextType = $ZCONVERT(evNext.EventType,"U")
        If evNextType'="RESPONSE" {
            ; Not a request/response pair — emit the request alone
            Do pOutEvents.%Push(ev)
            Set i = i + 1
            Continue
        }

        ; Response must explicitly pair with this request
        Set pairWith = +evNext.PairWithID
        If pairWith'=(+ev.ID) {
            Do pOutEvents.%Push(ev)
            Set i = i + 1
            Continue
        }

        ; Build base signature for this pair
        Set baseSig = ..PairSignature(ev, evNext)
        If baseSig="" {
            ; Signature could not be computed (missing endpoints/labels) — degrade gracefully
            Do pOutEvents.%Push(ev)
            Set i = i + 1
            Continue
        }

        ; We have at least one well-formed pair
        Set count = 1

        ; Look ahead for additional contiguous identical pairs
        Set j = i + 2
        While (j+1<len) {
            Set nextReq = pEvents.%Get(j)
            Set nextResp = pEvents.%Get(j+1)
            If '$IsObject(nextReq)!'$IsObject(nextResp) {
                Quit
            }

            Set tReqType = $ZCONVERT(nextReq.EventType,"U")
            Set tRespType = $ZCONVERT(nextResp.EventType,"U")

            If (tReqType'="REQUEST")!(tRespType'="RESPONSE") {
                Quit
            }

            Set pairWith = +nextResp.PairWithID
            If pairWith'=(+nextReq.ID) {
                Quit
            }

            Set sig = ..PairSignature(nextReq, nextResp)
            If sig'=baseSig {
                Quit
            }

            Set count = count + 1
            Set j = j + 2
        }

        ; If we only saw a single pair, do not compress — emit as-is
        If count=1 {
            Do pOutEvents.%Push(ev)
            Do pOutEvents.%Push(evNext)
            Set i = i + 2
            Continue
        }

        ; Build a synthetic Loop event representing this contiguous region.
        Set evLoop = ##class(MALIB.Util.DiagramTool.Event).%New()
        Set evLoop.EventType = "Loop"
        Set evLoop.LoopCount = count

        ; Capture request/response endpoints, labels, and arrows
        Set evLoop.ReqSrc   = ev.Src
        Set evLoop.ReqDst   = ev.Dst
        Set evLoop.ReqLabel = ev.Label
        Set evLoop.ReqArrow = ev.Arrow

        Set evLoop.RespSrc   = evNext.Src
        Set evLoop.RespDst   = evNext.Dst
        Set evLoop.RespLabel = evNext.Label
        Set evLoop.RespArrow = evNext.Arrow

        ; Primary Label used for loop header; request label is canonical
        Set evLoop.Label = ev.Label

        Do pOutEvents.%Push(evLoop)
        Set i = i + (2*count)
    }

    Quit tSC
}

/// ST-004 helper — Compute a stable signature for a Request/Response pair
ClassMethod PairSignature(pReq As MALIB.Util.DiagramTool.Event, pResp As MALIB.Util.DiagramTool.Event) As %String
{
    Set sig = ""
    Quit:'$IsObject(pReq) sig
    Quit:'$IsObject(pResp) sig

    Set reqSrc   = pReq.Src
    Set reqDst   = pReq.Dst
    Set reqLbl   = pReq.Label
    Set reqArrow = pReq.Arrow
    Set respSrc   = pResp.Src
    Set respDst   = pResp.Dst
    Set respLbl   = pResp.Label
    Set respArrow = pResp.Arrow

    ; Require endpoints to be present; missing data degrades to no compression
    If (reqSrc="")!(reqDst="")!(respSrc="")!(respDst="") {
        Quit sig
    }

    ; Signature includes arrow semantics to distinguish Inproc vs Queue
    Set sig = reqSrc_"|"_reqDst_"|"_reqLbl_"|"_reqArrow_"||"_respSrc_"|"_respDst_"|"_respLbl_"|"_respArrow
    Quit sig
}

/// ST-006 helper — Label selection based on label mode (for dynamic callers)
ClassMethod LabelForEvent(pEvent As %DynamicObject, pLabelMode As %String = "full") As %String
{
    Quit ..NormalizeLabelForMode($Select($IsObject(pEvent):pEvent.%Get("Label"), 1:""), pLabelMode)
}

/// Shared helper — apply labelMode to arbitrary label text
ClassMethod NormalizeLabelForMode(pText As %String, pLabelMode As %String = "full") As %String
{
    Set base = $Get(pText,"")
    Set mode = $ZCONVERT($Get(pLabelMode,"full"),"L")

    If mode="short" {
        ; Use the trailing segment after the last '.' in the class name
        Set parts = $Length(base,".")
        If parts>1 {
            Quit $Piece(base,".",parts)
        }
    }

    Quit base
}

/// ST-006 helper — Emit a single event as a Mermaid line (with optional indentation)
ClassMethod EmitEventLine(ByRef pLines As %String, pEvent As MALIB.Util.DiagramTool.Event, pRows As %DynamicArray, pLabelMode As %String, pIndent As %Integer = 0) As %Status
{
    Set tSC = $$$OK
    Quit:'$IsObject(pEvent) tSC

    Set pad = ""
    If +$Get(pIndent,0)>0 {
        ; Two spaces per indent level
        Set pad = $Justify("", (pIndent*2), " ")
    }

    ; Emit notes as %% comments when present
    Set note = pEvent.Notes
    If note'="" {
        Set pLines = pLines_$Char(13,10)_pad_"%% "_note
    }

    Set src = pEvent.Src
    Set dst = pEvent.Dst

    ; Fallback for missing endpoints based on original header rows
    If (src="")!(dst="") {
        Set evId = +pEvent.ID
        If $IsObject(pRows) {
            Set k=""
            For k=0:1:pRows.%Size()-1 {
                Set row = pRows.%Get(k)
                Continue:'$IsObject(row)
                If +row.%Get("ID")=evId {
                    If src="" Set src = row.%Get("SourceConfigName")
                    If dst="" Set dst = row.%Get("TargetConfigName")
                    Quit
                }
            }
        }
    }

    Set arrow = pEvent.Arrow
    Set label = ..NormalizeLabelForMode(pEvent.Label, pLabelMode)

    ; Skip completely empty/placeholder events
    If (src="")&&(dst="")&&(arrow="")&&(label="") {
        Quit tSC
    }

    Set pLines = pLines_$Char(13,10)_pad_src_" "_arrow_" "_dst_" : "_label
    Quit tSC
}

/// ST-004 helper — Emit loop request/response lines as plain arrows (no loop header)
ClassMethod EmitLoopAsPlain(ByRef pLines As %String, pLoopEvent As MALIB.Util.DiagramTool.Event, pLabelMode As %String) As %Status
{
    Set tSC = $$$OK
    Quit:'$IsObject(pLoopEvent) tSC

    ; Treat as a single pair: emit request then response lines without loop
    Set reqSrc   = pLoopEvent.ReqSrc
    Set reqDst   = pLoopEvent.ReqDst
    Set reqLbl   = ..NormalizeLabelForMode(pLoopEvent.ReqLabel, pLabelMode)
    Set reqArrow = pLoopEvent.ReqArrow

    Set respSrc   = pLoopEvent.RespSrc
    Set respDst   = pLoopEvent.RespDst
    Set respLbl   = ..NormalizeLabelForMode(pLoopEvent.RespLabel, pLabelMode)
    Set respArrow = pLoopEvent.RespArrow

    If (reqSrc'="")&&(reqDst'="") {
        Set pLines = pLines_$Char(13,10)_reqSrc_" "_reqArrow_" "_reqDst_" : "_reqLbl
    }
    If (respSrc'="")&&(respDst'="") {
        Set pLines = pLines_$Char(13,10)_respSrc_" "_respArrow_" "_respDst_" : "_respLbl
    }

    Quit tSC
}

/// ST-004 helper — Emit inner loop lines (indented request/response pair)
ClassMethod EmitLoopInnerLines(ByRef pLines As %String, pLoopEvent As MALIB.Util.DiagramTool.Event, pLabelMode As %String, pIndent As %Integer = 1) As %Status
{
    Set tSC = $$$OK
    Quit:'$IsObject(pLoopEvent) tSC

    Set pad = ""
    If +$Get(pIndent,0)>0 {
        Set pad = $Justify("", (pIndent*2), " ")
    }

    Set reqSrc   = pLoopEvent.ReqSrc
    Set reqDst   = pLoopEvent.ReqDst
    Set reqLbl   = ..NormalizeLabelForMode(pLoopEvent.ReqLabel, pLabelMode)
    Set reqArrow = pLoopEvent.ReqArrow

    Set respSrc   = pLoopEvent.RespSrc
    Set respDst   = pLoopEvent.RespDst
    Set respLbl   = ..NormalizeLabelForMode(pLoopEvent.RespLabel, pLabelMode)
    Set respArrow = pLoopEvent.RespArrow

    If (reqSrc'="")&&(reqDst'="") {
        Set pLines = pLines_$Char(13,10)_pad_reqSrc_" "_reqArrow_" "_reqDst_" : "_reqLbl
    }
    If (respSrc'="")&&(respDst'="") {
        Set pLines = pLines_$Char(13,10)_pad_respSrc_" "_respArrow_" "_respDst_" : "_respLbl
    }

    Quit tSC
}

/// ST-006 helper — Append diagrams to a file with %% --- dividers
ClassMethod AppendDiagramsToFile(pOutFile As %String, ByRef pDiagMap) As %Status
{
    Set tSC = $$$OK
    If pOutFile="" {
        Quit tSC
    }

    Set stream = ##class(%Stream.FileCharacter).%New()
    Set tSC = stream.LinkToFile(pOutFile)
    If $$$ISERR(tSC) {
        Quit tSC
    }

    Do stream.MoveToEnd()

    Set idx = ""
    For {
        Set idx = $Order(pDiagMap(idx))
        Quit:idx=""

        If idx>1 {
            Do stream.WriteLine("%% ---")
        }

        Set diag = pDiagMap(idx)
        If diag'="" {
            Do stream.Write(diag)
        }

        ; Ensure there is at least one line break after each diagram block
        Do stream.WriteLine("")
    }

    Do stream.Flush()
    Quit tSC
}

}
