/// ============================================================================
/// MALIB.Util.DiagramTool
/// Utility to generate Mermaid sequence diagrams from IRIS Ens.MessageHeader
/// trace sessions (one diagram per SessionId), with optional de-duplication
/// across sessions and optional file output.
/// 
/// Key concepts:
/// - Actors = SourceConfigName and TargetConfigName
/// - Message label = MessageBodyClassName (short class name by default)
/// - Sync vs Async: Invocation = "Inproc" (sync), "Queue" (async)
/// - Correlation:
///     • Inproc: Response is implied by order (reversed Source/Target)
///     • Queue: Response correlated via CorrespondingMessageId and/or ReturnQueueName
/// - Loops: contiguous repeated request/response pairs with same endpoints/message
/// 
/// Inputs:
/// - Session spec string supporting single IDs, ranges, and lists (e.g. "1,5-9,12")
/// - Optional output file to write all generated diagrams
/// 
/// Outputs:
/// - Mermaid sequence diagrams text (one per session), returned via output param
/// - Also written to terminal
/// 
/// Standards/Guidance:
/// - ObjectScript practices per .clinerules/
/// - Use $$$OK / $$$ISERR macros and %Status
/// - No QUIT with arguments in Try/Catch (return via variables)
/// - Do NOT edit Storage sections
/// - Avoid underscores in parameter names; use camelCase
/// ============================================================================
/// @package MALIB.Util
Class MALIB.Util.DiagramTool Extends %RegisteredObject
{
Include %occInclude

/// Build diagrams for one or more sessions specified by a spec string (e.g. "1,5-9,12")
/// Returns combined Mermaid output in pResult. Optionally writes to pFilePath.
/// If pDeduplicate=1, identical diagrams (across different sessions) are collapsed.
///
/// Example:
///   Do ##class(MALIB.Util.DiagramTool).BuildFromSessions("1584253", .result, "out.mmd", 1)
///
/// @param pSessionSpec String "1,5-9,12"
/// @param pResult OUT All diagrams combined (with blank line between)
/// @param pFilePath Optional file path to write combined output
/// @param pDeduplicate Default 1 = de-duplicate identical diagrams
/// @return %Status
ClassMethod BuildFromSessions(pSessionSpec As %String, Output pResult As %String, pFilePath As %String = "", pDeduplicate As %Boolean = 1) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        Set tSessions = ..ExpandSessionSpec(pSessionSpec)
        If $LISTLENGTH(tSessions)=0 {
            Set pResult = "sequenceDiagram"_$C(13,10)_"%% No sessions parsed from spec: '"_pSessionSpec_"'"_$C(13,10)
            Write pResult, !
            Quit
        }
Kill tSeen
        Set i = 1
        For i=1:1:$LISTLENGTH(tSessions) {
            Set tSessionId = +$LISTGET(tSessions, i)
            ;skip invalid
            If tSessionId=0 Continue

            Kill tRows
            Set tSC1 = ..FetchSessionRows(tSessionId, .tRows)
            If $$$ISERR(tSC1) {
                Set tSC = tSC1
                Quit
            }
Set tDiagram = ""
            Set tSC1 = ..BuildDiagramForSession(.tRows, .tDiagram, tSessionId)
            If $$$ISERR(tSC1) {
                Set tSC = tSC1
                Quit
            }
If pDeduplicate {
                Set tKey = ..HashDiagram(tDiagram)
                If '$Data(tSeen(tKey)) {
                    Set tSeen(tKey) = 1
                    Set:($LENGTH(pResult)) pResult = pResult _ $C(13,10) _ $C(13,10)
                    Set pResult = pResult _ tDiagram
                }
} Else {
                Set:($LENGTH(pResult)) pResult = pResult _ $C(13,10) _ $C(13,10)
                Set pResult = pResult _ tDiagram
            }
        }

        ; Terminal output
        Write pResult, !

        ; Optional file write
        If (pFilePath'="") {
            Set tSC1 = ..WriteStringToFile(pFilePath, pResult)
            If $$$ISERR(tSC1) {
                Set tSC = tSC1
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// Expand a session spec string into a $LIST of integers
/// Supports tokens: single (12) or range (5-9), comma separated
ClassMethod ExpandSessionSpec(pSpec As %String) As %ListOfDataTypes
{
    Set result = ""
    Set s = $ZSTRIP(pSpec, "<>W")  // trim whitespace
    // remove spaces
    Set s = $REPLACE(s, " ", "")
    If s="" Quit result

    Set i=1
    For i=1:1:$LENGTH(s, ",") {
        Set token = $PIECE(s, ",", i)
        If token="" Continue

        If token?1N.N1"-"1N.N {
            Set a = +$PIECE(token, "-", 1)
            Set b = +$PIECE(token, "-", 2)
            If (a>0)&(b>=a) {
                Set x=a
                For x=a:1:b {
                    Set result = $LIST(result, $LISTLENGTH(result)+1, x)
                }
            }
        } ElseIf token?1N.N {
            Set v=+token
            If v>0 {
                Set result = $LIST(result, $LISTLENGTH(result)+1, v)
            }
        }
    }
    Quit result
}

/// Fetch Ens.MessageHeader rows for a given session, excluding HS.Util.Trace.Request
/// Results are appended as %DynamicObject rows into pRows (%DynamicArray)
/// Ordered by TimeCreated then ID to preserve causal order
ClassMethod FetchSessionRows(pSessionId As %Integer, ByRef pRows) As %Status
{
    Set tSC = $$$OK
    Kill pRows
    Try {
        Set pRows = ##class(%DynamicArray).%New()
        Set sql = "SELECT ID,Invocation,MessageBodyClassName,SessionId,SourceConfigName,TargetConfigName,ReturnQueueName,CorrespondingMessageId,TimeCreated,Type "_
                  "FROM Ens.MessageHeader "_
                  "WHERE SessionId = ? AND MessageBodyClassName <> 'HS.Util.Trace.Request' "_
                  "ORDER BY TimeCreated, ID"
        Set stmt = ##class(%SQL.Statement).%New()
        Set prep = stmt.%Prepare(sql)
        If (prep'=1) {
            ; Fallback try without ORDER BY TimeCreated for compatibility
            Set sql = "SELECT ID,Invocation,MessageBodyClassName,SessionId,SourceConfigName,TargetConfigName,ReturnQueueName,CorrespondingMessageId,TimeCreated,Type "_
                      "FROM Ens.MessageHeader "_
                      "WHERE SessionId = ? AND MessageBodyClassName <> 'HS.Util.Trace.Request' "_
                      "ORDER BY ID"
            Do stmt.%Prepare(sql)
        }
        Set rs = stmt.%Execute(pSessionId)
        For {
            Quit:rs.%Next()=0
            Set row = ##class(%DynamicObject).%New()
            Do row.%Set("ID", rs.%Get("ID"))
            Do row.%Set("Invocation", rs.%Get("Invocation"))
            Do row.%Set("MessageBodyClassName", rs.%Get("MessageBodyClassName"))
            Do row.%Set("SessionId", rs.%Get("SessionId"))
            Do row.%Set("SourceConfigName", rs.%Get("SourceConfigName"))
            Do row.%Set("TargetConfigName", rs.%Get("TargetConfigName"))
            Do row.%Set("ReturnQueueName", rs.%Get("ReturnQueueName"))
            Do row.%Set("CorrespondingMessageId", rs.%Get("CorrespondingMessageId"))
            Do row.%Set("TimeCreated", rs.%Get("TimeCreated"))
            Do row.%Set("Type", rs.%Get("Type"))
            Do pRows.%Push(row)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// Build a Mermaid diagram string for a single session's rows
/// pRows: %DynamicArray of row objects from FetchSessionRows or LoadRowsFromCsv
/// pDiagram: OUT diagram text
/// pSessionId: optional, for comment annotation
ClassMethod BuildDiagramForSession(ByRef pRows, Output pDiagram As %String, pSessionId As %Integer = 0) As %Status
{
    Set tSC = $$$OK
    Set pDiagram = ""
    Try {
        // Collect actors in appearance order
        Set actorMap = ##class(%DynamicObject).%New()
        Set actorOrder = ##class(%DynamicArray).%New()
        Set i=0
        For i=0:1:(pRows.%Size()-1) {
            Set rw = pRows.%Get(i)
            Do ..EnsureActor(actorMap, actorOrder, rw.SourceConfigName)
            Do ..EnsureActor(actorMap, actorOrder, rw.TargetConfigName)
        }

        Set out = "sequenceDiagram"_$C(13,10)
        If pSessionId>0 {
            Set out = out _ "%% Session "_pSessionId_$C(13,10)
        }

        ; Declare participants
        Set i=0
        For i=0:1:(actorOrder.%Size()-1) {
            Set label = actorOrder.%Get(i)
            Set id = ..SanitizeId(label)
            Set out = out _ "participant "_id_" as """_label_""""_$C(13,10)
        }

        ; Build event list
        Set events = ##class(%DynamicArray).%New()
        Set i=0
        For i=0:1:(pRows.%Size()-1) {
            Set rw = pRows.%Get(i)
            Set ev = ##class(%DynamicObject).%New()
            Do ev.%Set("Kind", rw.Type)
            Do ev.%Set("Src", ..SanitizeId(rw.SourceConfigName))
            Do ev.%Set("Dst", ..SanitizeId(rw.TargetConfigName))
            Do ev.%Set("Label", ..ShortClass(rw.MessageBodyClassName))
            Do ev.%Set("Invocation", rw.Invocation)
            Do ev.%Set("ID", rw.ID)
            Do ev.%Set("Corr", rw.CorrespondingMessageId)
            Do ev.%Set("ReturnQueueName", rw.ReturnQueueName)
            Do events.%Push(ev)
        }

        ; Emit messages with naive loop compression for contiguous repeated pairs
        Set i = 0
        While (i<events.%Size()) {
            Set req = events.%Get(i)
            ; Find correlated response
            Set respIndex = ..FindResponseIndex(events, i+1, req)
            If respIndex="":
                ; Emit single request
                Set out = out _ req.Src _ " " _ ..ArrowFor(req.Invocation) _ " " _ req.Dst _ ": " _ req.Label _ $C(13,10)
                Set i = i + 1
            Else {
                Set resp = events.%Get(respIndex)
                ; Determine signature for contiguous repeats
                Set sig = req.Src _ "|" _ req.Dst _ "|" _ req.Label _ "|" _ resp.Src _ "|" _ resp.Dst _ "|" _ resp.Label
                Set pairCount = 1
                Set k = respIndex + 1
                For {
                    Quit:k>=events.%Size()
                    Set req2 = events.%Get(k)
                    Quit:req2.Kind'="Request"
                    Set respIndex2 = ..FindResponseIndex(events, k+1, req2)
                    Quit:respIndex2=""
                    Set resp2 = events.%Get(respIndex2)
                    Set sig2 = req2.Src _ "|" _ req2.Dst _ "|" _ req2.Label _ "|" _ resp2.Src _ "|" _ resp2.Dst _ "|" _ resp2.Label
                    If sig2'=sig Quit
                    Set pairCount = pairCount + 1
                    Set k = respIndex2 + 1
                }

                If pairCount>1 {
                    Set out = out _ "loop "_pairCount_" times "_req.Label_$C(13,10)
                    Set out = out _ req.Src _ " " _ ..ArrowFor(req.Invocation) _ " " _ req.Dst _ ": " _ req.Label _ $C(13,10)
                    Set out = out _ resp.Src _ " " _ ..ArrowFor(resp.Invocation) _ " " _ resp.Dst _ ": " _ resp.Label _ $C(13,10)
                    Set out = out _ "end"_$C(13,10)
                    Set i = k
                } Else {
                    Set out = out _ req.Src _ " " _ ..ArrowFor(req.Invocation) _ " " _ req.Dst _ ": " _ req.Label _ $C(13,10)
                    Set out = out _ resp.Src _ " " _ ..ArrowFor(resp.Invocation) _ " " _ resp.Dst _ ": " _ resp.Label _ $C(13,10)
                    Set i = respIndex + 1
                }
            }
        }

        Set pDiagram = out
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// Ensure an actor is recorded in mapping and order
ClassMethod EnsureActor(ByRef pMap, ByRef pOrder, name As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        If name="" Quit tSC
        If '$IsObject(pMap.%Get(name)) {
            Do pMap.%Set(name, 1)
            Do pOrder.%Push(name)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// Shorten a fully qualified class name to its last piece
ClassMethod ShortClass(full As %String) As %String
{
    Quit $PIECE(full, ".", $LENGTH(full, "."))
}

/// Find the index of the correlated response for a given request starting at startIndex
/// Returns "" if not found.
///
/// Queued: prefer CorrespondingMessageId, fallback to ReturnQueueName
/// Inproc: match reversed Src/Dst and "Response" kind
ClassMethod FindResponseIndex(ByRef events, startIndex As %Integer, req) As %String
{
    Set i = startIndex
    For i=startIndex:1:(events.%Size()-1) {
        Set ev = events.%Get(i)
        If ev.Kind'="Response" Continue

        If $ZCONVERT(req.Invocation,"U")="QUEUE" {
            If +ev.Corr=+req.ID Quit i
            If (ev.ReturnQueueName'=""),(ev.ReturnQueueName=req.ReturnQueueName) Quit i
        } Else {
            If (ev.Src=req.Dst)&(ev.Dst=req.Src) Quit i
        }
    }
    Quit ""
}

/// Choose arrow style for Mermaid based on invocation
/// Mermaid sequence conventions:
///  - Sync:  ->>
///  - Async: -->>
ClassMethod ArrowFor(inv As %String) As %String
{
    Quit $Select($ZCONVERT(inv,"U")="QUEUE":"-->>", 1:"->>")
}

/// Sanitize an actor name into a Mermaid participant identifier
/// Keeps [A-Z][a-z][0-9]_ and replaces others with underscore
ClassMethod SanitizeId(name As %String) As %String
{
    Set res = ""
    Set i=1
    For i=1:1:$LENGTH(name) {
        Set ch = $EXTRACT(name, i)
        Set code = $ASCII(ch)
        If ((code>=48)&(code<=57))!((code>=65)&(code<=90))!((code>=97)&(code<=122))!(ch="_") {
            Set res = res _ ch
        } Else {
            Set res = res _ "_"
        }
    }
    Quit res
}

/// Stable hash of a diagram for de-duplication
ClassMethod HashDiagram(diag As %String) As %String
{
    Quit $SYSTEM.Encryption.MD5Hash(diag)
}

/// Write a whole string to a file path
ClassMethod WriteStringToFile(pFilePath As %String, content As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set stream = ##class(%Stream.FileCharacter).%New()
        Do stream.LinkToFile(pFilePath)
        Do stream.Write(content)
        Do stream.%Save()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// Demo helper: build using the provided CSV in docs/sampledata.csv without hitting SQL
/// Useful when Ens.MessageHeader data isn't available in the current namespace
ClassMethod DemoFromCsv(pCsvPath As %String = "", pSessionSpec As %String = "", Output pResult As %String) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pCsvPath="" Set pCsvPath="docs/sampledata.csv"
        If pSessionSpec="" Set pSessionSpec="1584253"
        Set sessions = ..ExpandSessionSpec(pSessionSpec)
        If $LISTLENGTH(sessions)=0 Quit tSC

        Set i=1 For i=1:1:$LISTLENGTH(sessions) {
            Set sid = +$LISTGET(sessions, i)
            Kill rows
            Set rows = ..LoadRowsFromCsv(pCsvPath, sid)
            Set diag = ""
            Set tSC1 = ..BuildDiagramForSession(.rows, .diag, sid)
            If $$$ISERR(tSC1) { Set tSC = tSC1 Quit }
            Set:($LENGTH(pResult)) pResult = pResult _ $C(13,10)_$C(13,10)
            Set pResult = pResult _ diag
        }
        Write pResult, !
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// Load rows from a CSV file filtered to a SessionId
/// Assumes the header exactly matches docs/sampledata.csv
/// Note: Basic parser; if commas can appear in fields, replace with a robust CSV parser.
ClassMethod LoadRowsFromCsv(pCsvPath As %String, pSessionId As %Integer)
{
    Set arr = ##class(%DynamicArray).%New()
    Try {
        Set fs = ##class(%Stream.FileCharacter).%New()
        Do fs.LinkToFile(pCsvPath)
        Do fs.Rewind()
        ; header
        Set header = fs.ReadLine()
        For {
            Quit:fs.AtEnd
            Set line = fs.ReadLine()
            If line="" Continue
            ; Split on commas (simple case per sample)
            Set id = +$PIECE(line,",",1)
            Set session = +$PIECE(line,",",14)
            If session'=pSessionId Continue

            Set row = ##class(%DynamicObject).%New()
            Do row.%Set("ID", id)
            Do row.%Set("Invocation", $PIECE(line,",",7))
            Do row.%Set("MessageBodyClassName", $PIECE(line,",",9))
            Do row.%Set("SessionId", session)
            Do row.%Set("SourceConfigName", $PIECE(line,",",15))
            Do row.%Set("TargetConfigName", $PIECE(line,",",19))
            Do row.%Set("ReturnQueueName", $PIECE(line,",",13))
            Do row.%Set("CorrespondingMessageId", $PIECE(line,",",4))
            Do row.%Set("TimeCreated", $PIECE(line,",",22))
            Do row.%Set("Type", $PIECE(line,",",24))
            Do arr.%Push(row)
        }
    } Catch ex {
        ; Return what we have so far
    }
    Quit arr
}




}
