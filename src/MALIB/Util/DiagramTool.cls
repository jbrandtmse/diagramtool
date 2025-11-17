Include (%occInclude, Ensemble)

Class MALIB.Util.DiagramTool Extends %RegisteredObject
{

/// <p>Parse a session selector string into a %List of positive integer session IDs.</p>
/// <p>Facade that delegates to MALIB.Util.DiagramTool.SessionSpec.</p>
ClassMethod ParseSessionSpec(pSelector As %String = "") As %List
{
    Quit ##class(MALIB.Util.DiagramTool.SessionSpec).ParseSessionSpec(pSelector)
}

ClassMethod DebugParseSessionSpecToString(pSelector As %String = "") As %String
{
    Quit ##class(MALIB.Util.DiagramTool.SessionSpec).DebugParseSessionSpecToString(pSelector)
}

/// <h3>ST-002 — Data Load & Deterministic Ordering (SQL-only)</h3>
/// Facade that delegates to MALIB.Util.DiagramTool.Loader.
ClassMethod LoadHeadersForSession(pSessionId As %Integer, Output pRows As %DynamicArray, pForceIdOnlyOrder As %Boolean = 0) As %Status
{
    Quit ##class(MALIB.Util.DiagramTool.Loader).LoadHeadersForSession(pSessionId, .pRows, pForceIdOnlyOrder)
}

/// Map Invocation to Mermaid arrow semantics. Unknown -> default sync (->>)
/// Facade that delegates to MALIB.Util.DiagramTool.Correlation.
ClassMethod ArrowForInvocation(pInvocation As %String = "") As %String
{
    Quit ##class(MALIB.Util.DiagramTool.Correlation).ArrowForInvocation(pInvocation)
}

/// Correlate request/response events according to ST-003 rules.
/// Facade that delegates to MALIB.Util.DiagramTool.Correlation.
ClassMethod CorrelateEvents(pRows As %DynamicArray, Output pEvents As %DynamicArray) As %Status
{
    Quit ##class(MALIB.Util.DiagramTool.Correlation).CorrelateEvents(pRows, .pEvents)
}

/// Helper to extract inproc pairs from CorrelateEvents results (ST-003 helpers facade)
ClassMethod PairInproc(pRows As %DynamicArray, Output pPairs As %DynamicArray) As %Status
{
    Quit ##class(MALIB.Util.DiagramTool.Correlation).PairInproc(pRows, .pPairs)
}

/// Helper to extract queued pairs from CorrelateEvents results (ST-003 helpers facade)
ClassMethod PairQueued(pRows As %DynamicArray, Output pPairs As %DynamicArray) As %Status
{
    Quit ##class(MALIB.Util.DiagramTool.Correlation).PairQueued(pRows, .pPairs)
}

/// ST-006 — Main orchestration entrypoint
/// Generate Mermaid diagrams for one or more sessions selected by pSelector.
ClassMethod GenerateDiagrams(pSelector As %String, pOutFile As %String = "", pLabelMode As %String = "full", pDedupOn As %Boolean = 1, Output pText As %String) As %Status
{
        Set tSC = $$$OK
        Set pText = ""

        ; Normalize label mode
        Set tLabelMode = $ZCONVERT($Get(pLabelMode,"full"),"L")
        If (tLabelMode'="full")&&(tLabelMode'="short") {
            Set tLabelMode = "full"
        }

        ; Parse selector into a %List of SessionIds
        Set tList = ..ParseSessionSpec($Get(pSelector,""))
        Set tCount = $LISTLENGTH(tList)

        Kill tDiag
        Set tIndex = 0

        ; No sessions resolved -> nothing to do (best-effort)
        If tCount=0 {
            Quit tSC
        }

        ; Build per-session diagrams
        For i=1:1:tCount {
            Set tSessId = $LISTGET(tList,i)
            Continue:(tSessId="")

            Set tRows = ""
            Set tSC1 = ..LoadHeadersForSession(tSessId, .tRows)
            If $$$ISERR(tSC1) {
                Set tSC = tSC1
                Continue
            }

            Set tDiagText = ""
            Set tSC1 = ..BuildDiagramForSession(tSessId, tRows, tLabelMode, .tDiagText)
            If $$$ISERR(tSC1) {
                Set tSC = tSC1
                Continue
            }

            Continue:(tDiagText="")

            Set tIndex = tIndex + 1
            Set tDiag(tIndex) = tDiagText
        }

        ; If no diagrams were produced, return with empty text
        If tIndex=0 {
            Quit tSC
        }

        ; Deduplicate diagrams when requested
        Kill tSeen, tOutDiag
        Set tOutIndex = 0
        For i=1:1:tIndex {
            Set diag = tDiag(i)
            If pDedupOn {
                Set h = $ZCRC(diag,4)
                If $Data(tSeen(h)) {
                    ; Potential hash collision - only treat as duplicate when text is identical
                    If tSeen(h)=diag {
                        Continue
                    }
                }
                Set tSeen(h) = diag
            }
            Set tOutIndex = tOutIndex + 1
            Set tOutDiag(tOutIndex) = diag
        }

        ; Build combined text with blank line between diagrams
        Set pText = ""
        For i=1:1:tOutIndex {
            If i>1 {
                Set pText = pText_$Char(13,10)_$Char(13,10)
            }
            Set pText = pText_tOutDiag(i)
        }

        ; Append to file if requested
        If (pOutFile'=""),(pText'="") {
            Set tSC1 = ..AppendDiagramsToFile(pOutFile, .tOutDiag)
            If $$$ISERR(tSC1) {
                Set tSC = tSC1
            }
        }

        ; Echo combined text to current device (best-effort)
        If pText'="" {
            Write pText, !
        }

        Quit tSC
}

/// ST-006 helper — Build a single-session Mermaid diagram from loaded rows (facade)
ClassMethod BuildDiagramForSession(pSessionId As %Integer, pRows As %DynamicArray, pLabelMode As %String, Output pDiagram As %String) As %Status
{
    Quit ##class(MALIB.Util.DiagramTool.Output).BuildDiagramForSession(pSessionId, pRows, pLabelMode, .pDiagram)
}

/// ST-006 helper — Placeholder for loop detection/compression (ST-004) (facade)
ClassMethod ApplyLoopCompression(pEvents As %DynamicArray, Output pOutEvents As %DynamicArray) As %Status
{
    Quit ##class(MALIB.Util.DiagramTool.Output).ApplyLoopCompression(pEvents, .pOutEvents)
}

/// ST-006 helper — Label selection based on label mode (facade)
ClassMethod LabelForEvent(pEvent As %DynamicObject, pLabelMode As %String = "full") As %String
{
    Quit ##class(MALIB.Util.DiagramTool.Output).LabelForEvent(pEvent, pLabelMode)
}

/// ST-006 helper — Append diagrams to a file with %% --- dividers (facade)
ClassMethod AppendDiagramsToFile(pOutFile As %String, ByRef pDiagMap) As %Status
{
    Quit ##class(MALIB.Util.DiagramTool.Output).AppendDiagramsToFile(pOutFile, .pDiagMap)
}

}
