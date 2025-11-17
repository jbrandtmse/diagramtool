Include (%occInclude, Ensemble)

Class MALIB.Util.DiagramTool.Output Extends %RegisteredObject
{

/// ST-006 helper — Build a single-session Mermaid diagram from loaded rows
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

        ; Correlate events from rows
        Set tEvents = ""
        Set tSC = ##class(MALIB.Util.DiagramTool.Correlation).CorrelateEvents(pRows, .tEvents)
        If $$$ISERR(tSC) {
            Quit tSC
        }

        ; Apply loop detection/compression (placeholder for ST-004)
        Set tLooped = ""
        Set tSC = ..ApplyLoopCompression(tEvents, .tLooped)
        If $$$ISERR(tSC) {
            Quit tSC
        }

        ; Header and session comment
        Set lines = "sequenceDiagram"_$Char(13,10)_"%% Session "_pSessionId

        ; Collect participants (fallback to header rows if Src/Dst missing)
        Kill tPart
        Set len = tLooped.%Size()
        For i=0:1:len-1 {
            Set ev = tLooped.%Get(i)
            Continue:'$IsObject(ev)
            Set src = ev.%Get("Src")
            Set dst = ev.%Get("Dst")
            Set ^ClineDebug2 = ^ClineDebug2_"evID="_ev.%Get("ID")_" src0="_$Get(src,"")_" dst0="_$Get(dst,"")_"; "

            ; Fallback: look up original header row by ID if endpoints missing
            If (src="")!(dst="") {
                Set evId = ev.%Get("ID")
                If $IsObject(pRows) {
                    Set k=""
                    For k=0:1:pRows.%Size()-1 {
                        Set row = pRows.%Get(k)
                        Continue:'$IsObject(row)
                        If row.%Get("ID")=evId {
                            If src="" Set src = row.%Get("SourceConfigName")
                            If dst="" Set dst = row.%Get("TargetConfigName")
                            Quit
                        }
                    }
                }
            }
            Set ^ClineDebug2 = ^ClineDebug2_"evID="_ev.%Get("ID")_" src1="_$Get(src,"")_" dst1="_$Get(dst,"")_"; "

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

        ; Emit events as Mermaid arrows (with same fallback)
        For i=0:1:len-1 {
            Set ev = tLooped.%Get(i)
            Continue:'$IsObject(ev)

            ; Emit notes as %% comments when present
            Set note = ""
            If ev.%IsDefined("Notes") {
                Set note = ev.%Get("Notes")
            }
            If note'="" {
                Set lines = lines_$Char(13,10)_"%% "_note
            }

            Set src = ev.%Get("Src")
            Set dst = ev.%Get("Dst")

            ; Fallback for missing endpoints
            If (src="")!(dst="") {
                Set evId = ev.%Get("ID")
                If $IsObject(pRows) {
                    Set k=""
                    For k=0:1:pRows.%Size()-1 {
                        Set row = pRows.%Get(k)
                        Continue:'$IsObject(row)
                        If row.%Get("ID")=evId {
                            If src="" Set src = row.%Get("SourceConfigName")
                            If dst="" Set dst = row.%Get("TargetConfigName")
                            Quit
                        }
                    }
                }
            }

            Set arrow = ev.%Get("Arrow")
            Set label = ..LabelForEvent(ev, pLabelMode)

            If (src="")&&(dst="")&&(arrow="")&&(label="") {
                Continue
            }

            Set lines = lines_$Char(13,10)_src_" "_arrow_" "_dst_" : "_label
        }

        Set pDiagram = lines
        Quit tSC
}

/// ST-006 helper — Placeholder for loop detection/compression (ST-004)
ClassMethod ApplyLoopCompression(pEvents As %DynamicArray, Output pOutEvents As %DynamicArray) As %Status
{
        Set tSC = $$$OK
        If '$IsObject(pEvents) {
            Set pOutEvents = ##class(%DynamicArray).%New()
            Quit tSC
        }
        ; For now, simply pass events through. ST-004 will implement real loop grouping.
        Set pOutEvents = pEvents
        Quit tSC
}

/// ST-006 helper — Label selection based on label mode
ClassMethod LabelForEvent(pEvent As %DynamicObject, pLabelMode As %String = "full") As %String
{
        Set lbl = ""
        Quit:'$IsObject(pEvent) lbl

        Set base = pEvent.%Get("Label")
        Set mode = $ZCONVERT($Get(pLabelMode,"full"),"L")

        If mode="short" {
            ; Use the trailing segment after the last '.' in the class name
            Set parts = $Length(base,".")
            If parts>1 {
                Set lbl = $Piece(base,".",parts)
            } Else {
                Set lbl = base
            }
        } Else {
            Set lbl = base
        }

        Quit lbl
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
