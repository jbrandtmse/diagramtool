Include %occInclude

Class MALIB.Test.DiagramToolTest Extends %UnitTest.TestCase
{

Method %OnNew(initvalue As %String = "") As %Status
{
    Quit ##super(initvalue)
}

Method JoinList(pList) As %String
{
    Set s = "", first = 1
    Set len = $LISTLENGTH(pList)
    For i=1:1:len {
        Set val = $LISTGET(pList,i)
        Continue:val=""  ; skip empty elements
        If 'first Set s = s_","
        Set s = s_val
        Set first = 0
    }
    Quit s
}

/// AC-01 canonical example: "1, 5-7, 12" -> [1,5,6,7,12]
Method TestAC01Canonical() As %Status
{
    Set t = ##class(MALIB.Util.DiagramTool).ParseSessionSpec("1, 5-7, 12")
    Do $$$AssertEquals(..JoinList(t), "1,5,6,7,12", "AC-01 canonical")
    Quit $$$OK
}

/// "  10  " -> [10]
Method TestWhitespaceSingle() As %Status
{
    Set t = ##class(MALIB.Util.DiagramTool).ParseSessionSpec("  10  ")
    Do $$$AssertEquals(..JoinList(t), "10", "Trim whitespace single")
    Quit $$$OK
}

/// "2-2" -> [2]
Method TestRangeEqualBounds() As %Status
{
    Set t = ##class(MALIB.Util.DiagramTool).ParseSessionSpec("2-2")
    Do $$$AssertEquals(..JoinList(t), "2", "Equal bounds range")
    Quit $$$OK
}

/// "3-1" -> [] (invalid range ignored results in empty)
Method TestInvalidRangeDescending() As %Status
{
    Set t = ##class(MALIB.Util.DiagramTool).ParseSessionSpec("3-1")
    Do $$$AssertEquals(..JoinList(t), "", "Invalid descending range yields empty")
    Quit $$$OK
}

/// "1,,4" -> [1,4]
Method TestEmptyTokensIgnored() As %Status
{
    Set t = ##class(MALIB.Util.DiagramTool).ParseSessionSpec("1,,4")
    Do $$$AssertEquals(..JoinList(t), "1,4", "Empty tokens ignored")
    Quit $$$OK
}

/// "a,1,2-b,9" -> [1,9]
Method TestAlphaAndInvalidRangeIgnored() As %Status
{
    Set t = ##class(MALIB.Util.DiagramTool).ParseSessionSpec("a,1,2-b,9")
    Do $$$AssertEquals(..JoinList(t), "1,9", "Alpha and invalid range ignored")
    Quit $$$OK
}

/// "" -> []
Method TestEmptyStringYieldsEmpty() As %Status
{
    Set t = ##class(MALIB.Util.DiagramTool).ParseSessionSpec("")
    Do $$$AssertEquals(..JoinList(t), "", "Empty string yields empty list")
    Quit $$$OK
}

/// "  " -> []
Method TestWhitespaceOnlyYieldsEmpty() As %Status
{
    Set t = ##class(MALIB.Util.DiagramTool).ParseSessionSpec("  ")
    Do $$$AssertEquals(..JoinList(t), "", "Whitespace-only yields empty list")
    Quit $$$OK
}

/// "1 , 5-7 , 12 , 100-102" -> [1,5,6,7,12,100,101,102]
Method TestMixedWithSpaces() As %Status
{
    Set t = ##class(MALIB.Util.DiagramTool).ParseSessionSpec("1 , 5-7 , 12 , 100-102")
    Do $$$AssertEquals(..JoinList(t), "1,5,6,7,12,100,101,102", "Mixed with spaces")
    Quit $$$OK
}

/// Duplicates preserved: "1,1,2-3,2" -> [1,1,2,2,3]
Method TestDuplicatesPreserved() As %Status
{
    Set t = ##class(MALIB.Util.DiagramTool).ParseSessionSpec("1,1,2-3,2")
    Do $$$AssertEquals(..JoinList(t), "1,1,2,2,3", "Duplicates preserved")
    Quit $$$OK
}

/// Determinism: same input yields same output
Method TestDeterminism() As %Status
{
    Set in = "1 , 5-7 , 12 , 100-102"
    Set a = ##class(MALIB.Util.DiagramTool).ParseSessionSpec(in)
    Set b = ##class(MALIB.Util.DiagramTool).ParseSessionSpec(in)
    Do $$$AssertEquals(..JoinList(a), ..JoinList(b), "Deterministic output")
    Quit $$$OK
}

/// Helper: join IDs from %DynamicArray rows
Method JoinIdsFromRows(pRows As %DynamicArray) As %String
{
    Set s = "", first = 1
    Quit:('$IsObject(pRows)) s
    Set len = pRows.%Size()
    For i=0:1:len-1 {
        Set obj = pRows.%Get(i)
        Set id = ""
        If $IsObject(obj) Set id = obj.%Get("ID")
        Continue:id=""
        If 'first Set s = s_","
        Set s = s_id
        Set first = 0
    }
    Quit s
}

/// Helper: insert a header row and return its ID
Method InsertHeader(pSessionId As %Integer, pTime As %String, pBody As %String = "Unit.Test.Body") As %Integer
{
    Set tID = ""
    &sql(INSERT INTO Ens.MessageHeader (SessionId, MessageBodyClassName, TimeCreated) VALUES (:pSessionId, :pBody, :pTime))
    &sql(SELECT MAX(ID) INTO :tID FROM Ens.MessageHeader WHERE SessionId = :pSessionId AND MessageBodyClassName = :pBody AND TimeCreated = :pTime)
    Quit +$Get(tID,0)
}

/// Helper: cleanup all rows for a session
Method CleanupSession(pSessionId As %Integer) As %Status
{
    &sql(DELETE FROM Ens.MessageHeader WHERE SessionId = :pSessionId)
    Quit $$$OK
}

/// ST-002: Empty session yields empty results
Method TestST002EmptySessionYieldsEmpty() As %Status
{
    Set sid = 9000003
    Do ..CleanupSession(sid)
    Set rows = ""
    Set tSC = ##class(MALIB.Util.DiagramTool).LoadHeadersForSession(sid, .rows)
    Do $$$AssertStatusOK(tSC, "LoadHeadersForSession returned OK for empty session")
    Set cnt = $Select($IsObject(rows):rows.%Size(),1:0)
    Do $$$AssertEquals(cnt, 0, "Empty session yields empty results")
    Quit $$$OK
}

/// ST-002: Primary ordering by TimeCreated then ID, with filtering
Method TestST002PrimaryOrderingAndFilter() As %Status
{
    Set sid = 9000001
    Do ..CleanupSession(sid)

    Set id1 = ..InsertHeader(sid, "2024-01-01 10:00:00", "Unit.Test.Body.A")
    Set id2 = ..InsertHeader(sid, "2024-01-01 11:00:00", "Unit.Test.Body.B")
    Set id3 = ..InsertHeader(sid, "2024-01-01 11:00:00", "Unit.Test.Body.C")
    Set idx = ..InsertHeader(sid, "2024-01-01 09:59:00", "HS.Util.Trace.Request")
    Set id4 = ..InsertHeader(sid, "2024-01-01 12:00:00", "Unit.Test.Body.D")

    Set rows = ""
    Set tSC = ##class(MALIB.Util.DiagramTool).LoadHeadersForSession(sid, .rows)
    Do $$$AssertStatusOK(tSC, "Primary ordering returned OK")
    Do $$$AssertEquals($Select($IsObject(rows):rows.%Size(),1:0), 4, "Filtered row excluded")

    Set firstTie = id2, secondTie = id3
    If id3<id2 {
        Set firstTie = id3
        Set secondTie = id2
    }
    Set expected = id1_","_firstTie_","_secondTie_","_id4
    Do $$$AssertEquals(..JoinIdsFromRows(rows), expected, "Ordered by TimeCreated then ID")

    Do ..CleanupSession(sid)
    Quit $$$OK
}

/// ST-002: Fallback ordering by ID only when forced
Method TestST002FallbackIdOnlyOrdering() As %Status
{
    Set sid = 9000002
    Do ..CleanupSession(sid)

    Set idA = ..InsertHeader(sid, "2024-01-01 12:00:00", "Unit.Test.Body.A")
    Set idB = ..InsertHeader(sid, "2024-01-01 09:00:00", "Unit.Test.Body.B")
    Set idC = ..InsertHeader(sid, "2024-01-01 11:00:00", "Unit.Test.Body.C")
    Set idx = ..InsertHeader(sid, "2024-01-01 08:00:00", "HS.Util.Trace.Request")

    Set rows = ""
    Set tSC = ##class(MALIB.Util.DiagramTool).LoadHeadersForSession(sid, .rows, 1)
    Do $$$AssertStatusOK(tSC, "Fallback ordering returned OK")
    Do $$$AssertEquals($Select($IsObject(rows):rows.%Size(),1:0), 3, "Filtered row excluded")

    Set expected = idA_","_idB_","_idC
    Do $$$AssertEquals(..JoinIdsFromRows(rows), expected, "Ordered by ID only")

    Do ..CleanupSession(sid)
    Quit $$$OK
}

}
