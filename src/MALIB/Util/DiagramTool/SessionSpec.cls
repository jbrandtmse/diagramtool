Include (%occInclude, Ensemble)

Class MALIB.Util.DiagramTool.SessionSpec Extends %RegisteredObject
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
    Set tList = ..ParseSessionSpec(pSelector)
    Set s = ""
    Set len = $LISTLENGTH(tList)
    For i=1:1:len {
        If i>1 Set s = s_"," 
        Set s = s_$LISTGET(tList,i)
    }
    Quit s
}

}
