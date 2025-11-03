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

}
