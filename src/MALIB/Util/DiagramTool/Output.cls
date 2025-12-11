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

    ; ST-008: Episode-based grouping and loop compression over the ST-004 event stream
    Set tEpisodes = ""
    Set tBlocks = ""
    Set tSC = ..BuildEpisodes(tLooped, .tEpisodes)
    If $$$ISERR(tSC) {
        Quit tSC
    }
    Set tSC = ..ComputeEpisodeSignatures(tEpisodes)
    If $$$ISERR(tSC) {
        Quit tSC
    }
    Set tSC = ..CompressEpisodesToBlocks(tEpisodes, .tBlocks)
    If $$$ISERR(tSC) {
        Quit tSC
    }

    ; Header and session comment
    Set lines = "sequenceDiagram"_$Char(13,10)_"%% Session "_pSessionId

    ; ST-007: Collect participants based on order-of-first-appearance
    ; in the final correlated/loop-compressed event sequence
    Kill tPartSeen
    Set tPartList = ##class(%DynamicArray).%New()

    If $IsObject(tLooped) {
        Set lenLoop = tLooped.%Size()
        For i=0:1:lenLoop-1 {
            Set ev = tLooped.%Get(i)
            Continue:'$IsObject(ev)

            Set evType = $ZCONVERT(ev.EventType,"U")

            ; Loop events carry request/response endpoints separately
            If evType="LOOP" {
                Do ..RecordParticipant(.tPartSeen, .tPartList, ev.ReqSrc)
                Do ..RecordParticipant(.tPartSeen, .tPartList, ev.ReqDst)
                Do ..RecordParticipant(.tPartSeen, .tPartList, ev.RespSrc)
                Do ..RecordParticipant(.tPartSeen, .tPartList, ev.RespDst)
                Continue
            }

            ; Non-loop events use Src/Dst endpoints
            Do ..RecordParticipant(.tPartSeen, .tPartList, ev.Src)
            Do ..RecordParticipant(.tPartSeen, .tPartList, ev.Dst)
        }
    }

    ; Emit participants in order-of-first-appearance (per session)
    If $IsObject(tPartList) {
        Set lenParts = tPartList.%Size()
        For i=0:1:lenParts-1 {
            Set name = tPartList.%Get(i)
            Continue:name=""
            Set lines = lines_$Char(13,10)_"participant "_name
        }
    }

    ; Emit events and loop blocks (pair-level and episode-level) as Mermaid arrows
    If '$IsObject(tBlocks) {
        ; Fallback: emit raw ST-004 looped events when no episode blocks are available
        If '$IsObject(tLooped) {
            Set pDiagram = lines
            Quit tSC
        }

        Set len = tLooped.%Size()
        For i=0:1:len-1 {
            Set ev = tLooped.%Get(i)
            Continue:'$IsObject(ev)
            Do ..EmitEventOrLoop(.lines, ev, pRows, pLabelMode, 0)
        }

        Set pDiagram = lines
        Quit tSC
    }

    Set tSC = ..EmitEpisodeBlocks(.lines, tBlocks, pRows, pLabelMode)
    If $$$ISERR(tSC) {
        Quit tSC
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

/// ST-007 helper — track participants by order-of-first-appearance
ClassMethod RecordParticipant(ByRef pSeen, ByRef pList As %DynamicArray, pName As %String) As %Status
{
    Set tSC = $$$OK

    ; Ignore empty participant names
    If pName="" {
        Quit tSC
    }

    ; If already seen, do nothing
    If $Data(pSeen(pName)) {
        Quit tSC
    }

    Set pSeen(pName) = 1

    ; Ensure list exists before pushing
    If '$IsObject(pList) {
        Set pList = ##class(%DynamicArray).%New()
    }

    Do pList.%Push(pName)
    Quit tSC
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
ClassMethod EmitLoopAsPlain(ByRef pLines As %String, pLoopEvent As MALIB.Util.DiagramTool.Event, pLabelMode As %String, pIndent As %Integer = 0) As %Status
{
    Set tSC = $$$OK
    Quit:'$IsObject(pLoopEvent) tSC

    Set pad = ""
    If +$Get(pIndent,0)>0 {
        ; Two spaces per indent level
        Set pad = $Justify("", (pIndent*2), " ")
    }

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
        Set pLines = pLines_$Char(13,10)_pad_reqSrc_" "_reqArrow_" "_reqDst_" : "_reqLbl
    }
    If (respSrc'="")&&(respDst'="") {
        Set pLines = pLines_$Char(13,10)_pad_respSrc_" "_respArrow_" "_respDst_" : "_respLbl
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

/// ST-008 helper — Emit a single event or ST-004 loop with optional indentation
ClassMethod EmitEventOrLoop(ByRef pLines As %String, pEvent As MALIB.Util.DiagramTool.Event, pRows As %DynamicArray, pLabelMode As %String, pIndent As %Integer = 0) As %Status
{
    Set tSC = $$$OK
    Quit:'$IsObject(pEvent) tSC

    Set evType = $ZCONVERT(pEvent.EventType,"U")
    Set pad = ""
    If +$Get(pIndent,0)>0 {
        ; Two spaces per indent level
        Set pad = $Justify("", (pIndent*2), " ")
    }

    ; ST-004 pair-level loop event
    If evType="LOOP" {
        Set count = +pEvent.LoopCount
        ; Defensive: if LoopCount<2, fall back to plain lines
        If count<2 {
            Do ..EmitLoopAsPlain(.pLines, pEvent, pLabelMode, pIndent)
            Quit tSC
        }

        ; Loop header label respects label mode
        Set loopLabel = ..NormalizeLabelForMode(pEvent.Label, pLabelMode)
        If loopLabel="" {
            Set loopLabel = "loop"
        }

        ; Emit loop header with indentation
        Set pLines = pLines_$Char(13,10)_pad_"loop "_count_" times "_loopLabel

        ; Emit inner request/response lines with indentation relative to this block
        Do ..EmitLoopInnerLines(.pLines, pEvent, pLabelMode, pIndent+1)

        ; Close loop block
        Set pLines = pLines_$Char(13,10)_pad_"end"
        Quit tSC
    }

    ; Non-loop event — existing arrow emission behavior
    Do ..EmitEventLine(.pLines, pEvent, pRows, pLabelMode, pIndent)
    Quit tSC
}

/// ST-008 helper — Classify an event as trace/log vs business
ClassMethod IsTraceEvent(pEvent As MALIB.Util.DiagramTool.Event) As %Boolean
{
    Quit:'$IsObject(pEvent) 0

    Set label = pEvent.Label
    Set ulabel = $ZCONVERT(label,"U")

    ; Treat HS.Util.Trace.* message classes as trace/log noise
    If ulabel?1"HS.UTIL.TRACE.".E {
        Quit 1
    }

    Quit 0
}

/// ST-008 helper — Build per-event signature fragment for business events
ClassMethod BuildEpisodeSignatureFragment(pEvent As MALIB.Util.DiagramTool.Event, Output pFrag As %String) As %Status
{
    Set tSC = $$$OK
    Set pFrag = ""
    Quit:'$IsObject(pEvent) tSC

    Set evType = $ZCONVERT(pEvent.EventType,"U")
    ; LOOP events represent a request/response pair; expand into two logical lines for signatures
    If evType="LOOP" {
        Set reqSrc   = pEvent.ReqSrc
        Set reqDst   = pEvent.ReqDst
        Set reqLbl   = ..NormalizeLabelForMode(pEvent.ReqLabel, "full")
        Set reqArrow = pEvent.ReqArrow

        Set respSrc   = pEvent.RespSrc
        Set respDst   = pEvent.RespDst
        Set respLbl   = ..NormalizeLabelForMode(pEvent.RespLabel, "full")
        Set respArrow = pEvent.RespArrow

        ; Require endpoints for both legs; otherwise degrade to no fragment
        If (reqSrc="")!(reqDst="")!(respSrc="")!(respDst="") {
            Quit tSC
        }

        Set line1 = reqSrc_"|"_reqArrow_"|"_reqDst_"|"_reqLbl_"|"_"LOOPREQ"_"|"_"LOOP"
        Set line2 = respSrc_"|"_respArrow_"|"_respDst_"|"_respLbl_"|"_"LOOPRESP"_"|"_"LOOP"
        Set pFrag = line1_"||"_line2
        Quit tSC
    }

    ; Standard Request/Response business lines
    Set src   = pEvent.Src
    Set dst   = pEvent.Dst
    Set lbl   = ..NormalizeLabelForMode(pEvent.Label, "full")
    Set arrow = pEvent.Arrow
    Set inv   = pEvent.Invocation
    If (src="")!(dst="") {
        Quit tSC
    }

    Set pFrag = src_"|"_arrow_"|"_dst_"|"_lbl_"|"_inv_"|"_evType
    Quit tSC
}

/// ST-008 helper — Episode accessors for concrete Episode instances
ClassMethod GetEpisodeEvents(pEpisode As %RegisteredObject) As %DynamicArray
{
    If '$IsObject(pEpisode) {
        Quit ""
    }
    If $ClassName(pEpisode)'="MALIB.Util.DiagramTool.Episode" {
        Quit ""
    }
    Quit pEpisode.Events
}

ClassMethod GetEpisodeSignature(pEpisode As %RegisteredObject) As %String
{
    If '$IsObject(pEpisode) {
        Quit ""
    }
    If $ClassName(pEpisode)'="MALIB.Util.DiagramTool.Episode" {
        Quit ""
    }
    Quit pEpisode.Signature
}

ClassMethod GetEpisodeCompressible(pEpisode As %RegisteredObject) As %Boolean
{
    If '$IsObject(pEpisode) {
        Quit 0
    }
    If $ClassName(pEpisode)'="MALIB.Util.DiagramTool.Episode" {
        Quit 0
    }
    Quit +pEpisode.Compressible
}

ClassMethod SetEpisodeSignature(pEpisode As %RegisteredObject, pSignature As %String, pRepLabel As %String = "") As %Status
{
    Set tSC = $$$OK
    If '$IsObject(pEpisode) {
        Quit tSC
    }
    If $ClassName(pEpisode)'="MALIB.Util.DiagramTool.Episode" {
        Quit tSC
    }

    Set pEpisode.Signature = $Get(pSignature,"")
    Set pEpisode.RepLabel  = $Get(pRepLabel,"")
    Quit tSC
}

/// ST-008 helper — Compute business-only episode signatures
ClassMethod ComputeEpisodeSignatures(pEpisodes As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Quit:'$IsObject(pEpisodes) tSC

    Set len = pEpisodes.%Size()
    For i=0:1:len-1 {
        Set ep = pEpisodes.%Get(i)
        Continue:'$IsObject(ep)

        Set evArr = ..GetEpisodeEvents(ep)
        If '$IsObject(evArr) {
            Do ..SetEpisodeSignature(ep, "", "")
            Continue
        }

        Set sig = ""
        Set repLabel = ""
        Set evCount = evArr.%Size()
        For j=0:1:evCount-1 {
            Set ev = evArr.%Get(j)
            Continue:'$IsObject(ev)

            ; Skip trace/log events for signature purposes
            If ..IsTraceEvent(ev) {
                Continue
            }

            ; Capture representative business label from the first business event
            If repLabel="", ev.Label'="" {
                Set repLabel = ev.Label
            }

            Set frag = ""
            Set tSC1 = ..BuildEpisodeSignatureFragment(ev, .frag)
            If $$$ISERR(tSC1) {
                Quit
            }
            Continue:frag=""

            If sig="" {
                Set sig = frag
            } Else {
                Set sig = sig_"||"_frag
            }
        }

        ; Episodes with no business events do not participate in compression
        If sig="" {
            Do ..SetEpisodeSignature(ep, "", "")
        } Else {
            Do ..SetEpisodeSignature(ep, sig, repLabel)
        }
    }

    Quit tSC
}

/// ST-008 helper — Build episodes from the ST-004 loop-compressed event stream
ClassMethod BuildEpisodes(pEvents As %DynamicArray, Output pEpisodes As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set pEpisodes = ##class(%DynamicArray).%New()

    If '$IsObject(pEvents) {
        Quit tSC
    }

    Set len = pEvents.%Size()
    Set i = 0

    While (i<len) {
        Set ev = pEvents.%Get(i)
        Set i = i + 1
        Continue:'$IsObject(ev)

        Set evType = $ZCONVERT(ev.EventType,"U")
        Set isTrace = ..IsTraceEvent(ev)

        ; Only Requests for business events can start multi-event episodes
        If 'isTrace, evType="REQUEST" {
            Set ep = ##class(MALIB.Util.DiagramTool.Episode).%New()
            Set ep.Events = ##class(%DynamicArray).%New()
            Set ep.Compressible = 1
            Set ep.RootSrc = ev.Src
            Set ep.RootDst = ev.Dst

            Do pEpisodes.%Push(ep)

            Set evArr = ep.Events
            Do evArr.%Push(ev)

            ; Consume subsequent events until we see a terminal response back to the root
            For {
                Quit:(i>=len)
                Set nextEv = pEvents.%Get(i)
                Set i = i + 1
                Quit:'$IsObject(nextEv)

                Do evArr.%Push(nextEv)

                Set nType = $ZCONVERT(nextEv.EventType,"U")
                Set rootSrc = ep.RootSrc
                Set rootDst = ep.RootDst

                ; Episode terminates when a Response returns from RootDst back to RootSrc
                If (nType="RESPONSE"), (rootSrc'=""), (rootDst'=""), (nextEv.Src=rootDst), (nextEv.Dst=rootSrc) {
                    Quit
                }
            }

            Continue
        }

        ; Non-request or trace-only events become single-event, non-compressible episodes
        Set epSingle = ##class(MALIB.Util.DiagramTool.Episode).%New()
        Set epSingle.Events = ##class(%DynamicArray).%New()
        Set epSingle.Compressible = 0
        Set arr = epSingle.Events
        Do arr.%Push(ev)
        Do pEpisodes.%Push(epSingle)
    }

    Quit tSC
}

/// ST-008 helper — Compress contiguous identical episodes into loop blocks
ClassMethod CompressEpisodesToBlocks(pEpisodes As %DynamicArray, Output pBlocks As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set pBlocks = ##class(%DynamicArray).%New()

    If '$IsObject(pEpisodes) {
        Quit tSC
    }

    Set len = pEpisodes.%Size()
    Set i = 0
    Set ^ClineDebug3 = "CompressEpisodesToBlocks: len="_len_"; "

    While (i<len) {
        Set ep = pEpisodes.%Get(i)
        If '$IsObject(ep) {
            Set i = i + 1
            Continue
        }

        Set clsEp = $ClassName(ep)
        Set ^ClineDebug3 = $Get(^ClineDebug3)_"i="_i_", clsEp="_clsEp_"; "

        ; Defensive: only operate on concrete Episode instances; skip anything else
        If clsEp'="MALIB.Util.DiagramTool.Episode" {
            Set i = i + 1
            Continue
        }

        ; From here ep is guaranteed to be a MALIB.Util.DiagramTool.Episode instance
        Set sig = ..GetEpisodeSignature(ep)
        Set compressible = ..GetEpisodeCompressible(ep)

        ; Episodes without business signature or non-compressible are emitted as-is
        If (sig="")!'compressible {
            Set blk = ##class(MALIB.Util.DiagramTool.EpisodeBlock).%New()
            Set blk.Type = "EPISODE"
            Set blk.LoopCount = 1
            Set blk.Episode = ep
            Do pBlocks.%Push(blk)
            Set i = i + 1
            Continue
        }

        ; Count contiguous run of identical episode signatures
        Set count = 1
        Set j = i + 1
        While (j<len) {
            Set epNext = pEpisodes.%Get(j)
            Quit:'$IsObject(epNext)
            Set clsEpNext = $ClassName(epNext)
            Set ^ClineDebug3 = $Get(^ClineDebug3)_"j="_j_", clsEpNext="_clsEpNext_"; "
            If clsEpNext'="MALIB.Util.DiagramTool.Episode" {
                Quit
            }

            Set sigNext = ..GetEpisodeSignature(epNext)
            Set compressibleNext = ..GetEpisodeCompressible(epNext)
            If (compressibleNext'=1)!(sigNext'=sig) {
                Quit
            }
            Set count = count + 1
            Set j = j + 1
        }

        If count=1 {
            Set blk = ##class(MALIB.Util.DiagramTool.EpisodeBlock).%New()
            Set blk.Type = "EPISODE"
            Set blk.LoopCount = 1
            Set blk.Episode = ep
            Do pBlocks.%Push(blk)
            Set i = i + 1
            Continue
        }

        ; Build an episode-level loop block for this contiguous run
        Set blk = ##class(MALIB.Util.DiagramTool.EpisodeBlock).%New()
        Set blk.Type = "LOOP"
        Set blk.LoopCount = count
        Set blk.Episode = ep
        Do pBlocks.%Push(blk)

        Set i = i + count
    }

    Quit tSC
}

/// ST-008 debug helper — Reproduce ST-008 loop compression scenario and log episode types
ClassMethod DebugST008EpisodeCompression() As %Status
{
    Set tSC = $$$OK
    Set ^ClineDebug3 = "DebugST008EpisodeCompression; "

    // Recreate the rows for TestST008EpisodeLoopCompressionContiguousAndMixed
    Set rows = ##class(%DynamicArray).%New()
    Set sess = 9108003

    // Episode A (business structure 1) - repeated twice contiguously
    Set row = ##class(%DynamicObject).%New()
    Do row.%Set("ID", 8301)
    Do row.%Set("Invocation", "Inproc")
    Do row.%Set("Type", "Request")
    Do row.%Set("SourceConfigName", "A")
    Do row.%Set("TargetConfigName", "B")
    Do row.%Set("ReturnQueueName", "")
    Do row.%Set("CorrespondingMessageId", "")
    Do row.%Set("MessageBodyClassName", "Unit.Test.ST008.LoopedReqA")
    Do row.%Set("SessionId", sess)
    Do rows.%Push(row)

    Set row = ##class(%DynamicObject).%New()
    Do row.%Set("ID", 8302)
    Do row.%Set("Invocation", "Inproc")
    Do row.%Set("Type", "Request")
    Do row.%Set("SourceConfigName", "B")
    Do row.%Set("TargetConfigName", "C")
    Do row.%Set("ReturnQueueName", "")
    Do row.%Set("CorrespondingMessageId", "")
    Do row.%Set("MessageBodyClassName", "Unit.Test.ST008.LoopedInnerReqA")
    Do row.%Set("SessionId", sess)
    Do rows.%Push(row)

    Set row = ##class(%DynamicObject).%New()
    Do row.%Set("ID", 8303)
    Do row.%Set("Invocation", "Inproc")
    Do row.%Set("Type", "Response")
    Do row.%Set("SourceConfigName", "C")
    Do row.%Set("TargetConfigName", "B")
    Do row.%Set("ReturnQueueName", "")
    Do row.%Set("CorrespondingMessageId", 8302)
    Do row.%Set("MessageBodyClassName", "Unit.Test.ST008.LoopedInnerRespA")
    Do row.%Set("SessionId", sess)
    Do rows.%Push(row)

    Set row = ##class(%DynamicObject).%New()
    Do row.%Set("ID", 8304)
    Do row.%Set("Invocation", "Inproc")
    Do row.%Set("Type", "Response")
    Do row.%Set("SourceConfigName", "B")
    Do row.%Set("TargetConfigName", "A")
    Do row.%Set("ReturnQueueName", "")
    Do row.%Set("CorrespondingMessageId", 8301)
    Do row.%Set("MessageBodyClassName", "Unit.Test.ST008.LoopedRespA")
    Do row.%Set("SessionId", sess)
    Do rows.%Push(row)

    Set row = ##class(%DynamicObject).%New()
    Do row.%Set("ID", 8401)
    Do row.%Set("Invocation", "Inproc")
    Do row.%Set("Type", "Request")
    Do row.%Set("SourceConfigName", "A")
    Do row.%Set("TargetConfigName", "B")
    Do row.%Set("ReturnQueueName", "")
    Do row.%Set("CorrespondingMessageId", "")
    Do row.%Set("MessageBodyClassName", "Unit.Test.ST008.LoopedReqA")
    Do row.%Set("SessionId", sess)
    Do rows.%Push(row)

    Set row = ##class(%DynamicObject).%New()
    Do row.%Set("ID", 8402)
    Do row.%Set("Invocation", "Inproc")
    Do row.%Set("Type", "Request")
    Do row.%Set("SourceConfigName", "B")
    Do row.%Set("TargetConfigName", "C")
    Do row.%Set("ReturnQueueName", "")
    Do row.%Set("CorrespondingMessageId", "")
    Do row.%Set("MessageBodyClassName", "Unit.Test.ST008.LoopedInnerReqA")
    Do row.%Set("SessionId", sess)
    Do rows.%Push(row)

    Set row = ##class(%DynamicObject).%New()
    Do row.%Set("ID", 8403)
    Do row.%Set("Invocation", "Inproc")
    Do row.%Set("Type", "Response")
    Do row.%Set("SourceConfigName", "C")
    Do row.%Set("TargetConfigName", "B")
    Do row.%Set("ReturnQueueName", "")
    Do row.%Set("CorrespondingMessageId", 8402)
    Do row.%Set("MessageBodyClassName", "Unit.Test.ST008.LoopedInnerRespA")
    Do row.%Set("SessionId", sess)
    Do rows.%Push(row)

    Set row = ##class(%DynamicObject).%New()
    Do row.%Set("ID", 8404)
    Do row.%Set("Invocation", "Inproc")
    Do row.%Set("Type", "Response")
    Do row.%Set("SourceConfigName", "B")
    Do row.%Set("TargetConfigName", "A")
    Do row.%Set("ReturnQueueName", "")
    Do row.%Set("CorrespondingMessageId", 8401)
    Do row.%Set("MessageBodyClassName", "Unit.Test.ST008.LoopedRespA")
    Do row.%Set("SessionId", sess)
    Do rows.%Push(row)

    // Episode B (different business structure: different label)
    Set row = ##class(%DynamicObject).%New()
    Do row.%Set("ID", 8501)
    Do row.%Set("Invocation", "Inproc")
    Do row.%Set("Type", "Request")
    Do row.%Set("SourceConfigName", "A")
    Do row.%Set("TargetConfigName", "B")
    Do row.%Set("ReturnQueueName", "")
    Do row.%Set("CorrespondingMessageId", "")
    Do row.%Set("MessageBodyClassName", "Unit.Test.ST008.LoopedReqB")
    Do row.%Set("SessionId", sess)
    Do rows.%Push(row)

    Set row = ##class(%DynamicObject).%New()
    Do row.%Set("ID", 8502)
    Do row.%Set("Invocation", "Inproc")
    Do row.%Set("Type", "Request")
    Do row.%Set("SourceConfigName", "B")
    Do row.%Set("TargetConfigName", "C")
    Do row.%Set("ReturnQueueName", "")
    Do row.%Set("CorrespondingMessageId", "")
    Do row.%Set("MessageBodyClassName", "Unit.Test.ST008.LoopedInnerReqB")
    Do row.%Set("SessionId", sess)
    Do rows.%Push(row)

    Set row = ##class(%DynamicObject).%New()
    Do row.%Set("ID", 8503)
    Do row.%Set("Invocation", "Inproc")
    Do row.%Set("Type", "Response")
    Do row.%Set("SourceConfigName", "C")
    Do row.%Set("TargetConfigName", "B")
    Do row.%Set("ReturnQueueName", "")
    Do row.%Set("CorrespondingMessageId", 8502)
    Do row.%Set("MessageBodyClassName", "Unit.Test.ST008.LoopedInnerRespB")
    Do row.%Set("SessionId", sess)
    Do rows.%Push(row)

    Set row = ##class(%DynamicObject).%New()
    Do row.%Set("ID", 8504)
    Do row.%Set("Invocation", "Inproc")
    Do row.%Set("Type", "Response")
    Do row.%Set("SourceConfigName", "B")
    Do row.%Set("TargetConfigName", "A")
    Do row.%Set("ReturnQueueName", "")
    Do row.%Set("CorrespondingMessageId", 8501)
    Do row.%Set("MessageBodyClassName", "Unit.Test.ST008.LoopedRespB")
    Do row.%Set("SessionId", sess)
    Do rows.%Push(row)

    // Run the same pipeline that BuildDiagramForSession uses
    Set evDyn = ""
    Set tSC = ##class(MALIB.Util.DiagramTool.Correlation).CorrelateEvents(rows, .evDyn)
    If $$$ISERR(tSC) Quit tSC

    Set evTyped = ""
    Set tSC = ..ConvertDynamicToEvents(evDyn, .evTyped)
    If $$$ISERR(tSC) Quit tSC

    Set tLooped = ""
    Set tSC = ..ApplyLoopCompression(evTyped, .tLooped)
    If $$$ISERR(tSC) Quit tSC

    Set episodes = ""
    Set tSC = ..BuildEpisodes(tLooped, .episodes)
    If $$$ISERR(tSC) Quit tSC

    Set tSC = ..ComputeEpisodeSignatures(episodes)
    If $$$ISERR(tSC) Quit tSC

    // Log episode classes and signatures
    If $IsObject(episodes) {
        Set len = episodes.%Size()
        Set ^ClineDebug3 = ^ClineDebug3_"episodesLen="_len_"; "
        For i=0:1:len-1 {
            Set ep = episodes.%Get(i)
            Continue:'$IsObject(ep)
            Set evArr = ..GetEpisodeEvents(ep)
            Set sig = ..GetEpisodeSignature(ep)
            Set comp = ..GetEpisodeCompressible(ep)
            Set evCount = $Select($IsObject(evArr):evArr.%Size(),1:0)
            Set ^ClineDebug3 = ^ClineDebug3_"ep#"_i_": cls="_$ClassName(ep)_" sig="_sig_" comp="_comp_" evCount="_evCount_"; "
        }
    } Else {
        Set ^ClineDebug3 = ^ClineDebug3_"episodes is not object; "
    }

    // Attempt compression but catch any error so we can inspect debug
    Try {
        Set blocks = ""
        Set tSC = ..CompressEpisodesToBlocks(episodes, .blocks)
        If $$$ISERR(tSC) {
            Set ^ClineDebug3 = ^ClineDebug3_"CompressStatus="_$SYSTEM.Status.GetErrorText(tSC)_"; "
        }
    } Catch ex {
        Set ^ClineDebug3 = ^ClineDebug3_"EX="_ex.DisplayString()
    }

    Quit $$$OK
}

/// ST-008 helper — Emit episode blocks (episodes and episode-level loops)
ClassMethod EmitEpisodeBlocks(ByRef pLines As %String, pBlocks As %DynamicArray, pRows As %DynamicArray, pLabelMode As %String) As %Status
{
    Set tSC = $$$OK
    Quit:'$IsObject(pBlocks) tSC

    Set len = pBlocks.%Size()
    For i=0:1:len-1 {
        Set blk = pBlocks.%Get(i)
        Continue:'$IsObject(blk)

        Set bType = blk.Type
        If bType="" {
            Set bType = "EPISODE"
        }
        Set bType = $ZCONVERT(bType,"U")

        ; Episode-level loop block
        If bType="LOOP" {
            Set count = +blk.LoopCount
            If count<2 {
                ; Degrade to expanded episode when count is not meaningful
                Set bType = "EPISODE"
            } Else {
                Set ep = blk.Episode
                If '$IsObject(ep) {
                    Continue
                }

                Set repLabel = ep.RepLabel
                Set loopLabel = ..NormalizeLabelForMode(repLabel, pLabelMode)
                If loopLabel="" {
                    Set loopLabel = "episode"
                }

                ; Emit episode-level loop header
                Set pLines = pLines_$Char(13,10)_"loop "_count_" times "_loopLabel

                ; Emit inner events for one canonical episode (including trace/log events)
                Set evArr = ep.Events
                If $IsObject(evArr) {
                    Set evLen = evArr.%Size()
                    For j=0:1:evLen-1 {
                        Set ev = evArr.%Get(j)
                        Continue:'$IsObject(ev)
                        Do ..EmitEventOrLoop(.pLines, ev, pRows, pLabelMode, 1)
                    }
                }

                ; Close loop block
                Set pLines = pLines_$Char(13,10)_"end"
                Continue
            }
        }

        ; Expanded single episode (or degraded loop)
        If bType="EPISODE" {
            Set ep = blk.Episode
            Continue:'$IsObject(ep)

            Set evArr = ep.Events
            Continue:'$IsObject(evArr)

            Set evLen = evArr.%Size()
            For j=0:1:evLen-1 {
                Set ev = evArr.%Get(j)
                Continue:'$IsObject(ev)
                Do ..EmitEventOrLoop(.pLines, ev, pRows, pLabelMode, 0)
            }
        }
    }

    Quit tSC
}

/// ST-006 helper — Append diagrams to a file with %% --- dividers
/// ST-005 AC-11: Append-only semantics, divider between diagrams, blank-line separation.
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

    ; Determine whether the target file already has content.
    ; For non-empty files we will emit a divider before the first appended diagram
    ; so that diagrams from previous runs are separated from new ones.
    Do stream.Rewind()
    Set tFirstChar = stream.Read(1)
    Set tIsEmpty = (tFirstChar="")
    Do stream.MoveToEnd()

    Set idx = ""
    Set tFirstDiag = 1
    For {
        Set idx = $Order(pDiagMap(idx))
        Quit:idx=""

        Set diag = pDiagMap(idx)
        Continue:diag=""

        ; Write divider lines:
        ;  - For the very first diagram appended to a non-empty file, insert one divider.
        ;  - For subsequent diagrams in this call, always insert a divider between blocks.
        If tFirstDiag {
            If 'tIsEmpty {
                Do stream.WriteLine("%% ---")
            }
            Set tFirstDiag = 0
        } Else {
            Do stream.WriteLine("%% ---")
        }

        ; Write the diagram text followed by a trailing newline to guarantee
        ; at least one blank line between diagrams in the combined text view.
        Do stream.Write(diag)
        Do stream.WriteLine("")
    }

    Do stream.Flush()
    Quit tSC
}

}
