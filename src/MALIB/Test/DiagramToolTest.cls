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

/// ST-002: Fully filtered session (only HS.Util.Trace.Request) yields empty results
Method TestST002AllRowsFilteredYieldsEmpty() As %Status
{
    Set sid = 9000010
    Do ..CleanupSession(sid)

    Set idx1 = ..InsertHeader(sid, "2024-01-01 08:00:00", "HS.Util.Trace.Request")
    Set idx2 = ..InsertHeader(sid, "2024-01-01 08:05:00", "HS.Util.Trace.Request")

    Set rows = ""
    Set tSC = ##class(MALIB.Util.DiagramTool).LoadHeadersForSession(sid, .rows)
    Do $$$AssertStatusOK(tSC, "OK on fully filtered session")
    Do $$$AssertEquals($Select($IsObject(rows):rows.%Size(),1:0), 0, "Fully filtered session returns empty set")

    Do ..CleanupSession(sid)
    Quit $$$OK
}

/// ST-002: Invalid sessionId = 0 returns OK and empty results
Method TestST002InvalidSessionIdZero() As %Status
{
    Set rows = ""
    Set tSC = ##class(MALIB.Util.DiagramTool).LoadHeadersForSession(0, .rows)
    Do $$$AssertStatusOK(tSC, "OK status for sessionId 0")
    Do $$$AssertEquals($Select($IsObject(rows):rows.%Size(),1:0), 0, "Zero sessionId returns empty results")
    Quit $$$OK
}

/// ST-002: Invalid sessionId < 0 returns OK and empty results
Method TestST002InvalidSessionIdNegative() As %Status
{
    Set rows = ""
    Set tSC = ##class(MALIB.Util.DiagramTool).LoadHeadersForSession(-1, .rows)
    Do $$$AssertStatusOK(tSC, "OK status for negative sessionId")
    Do $$$AssertEquals($Select($IsObject(rows):rows.%Size(),1:0), 0, "Negative sessionId returns empty results")
    Quit $$$OK
}

/// ST-002: Empty-string sessionId returns OK and empty results
Method TestST002InvalidSessionIdEmptyString() As %Status
{
    Set rows = ""
    Set tSC = ##class(MALIB.Util.DiagramTool).LoadHeadersForSession("", .rows)
    Do $$$AssertStatusOK(tSC, "OK status for empty sessionId")
    Do $$$AssertEquals($Select($IsObject(rows):rows.%Size(),1:0), 0, "Empty sessionId returns empty results")
    Quit $$$OK
}

/// ST-002: Null normalization for optional fields (ReturnQueueName, CorrespondingMessageId)
Method TestST002NullNormalizationForOptionalFields() As %Status
{
    Set sid = 9000011
    Do ..CleanupSession(sid)

    Set id1 = ..InsertHeader(sid, "2024-01-01 10:00:00")
    Set rows = ""
    Set tSC = ##class(MALIB.Util.DiagramTool).LoadHeadersForSession(sid, .rows)
    Do $$$AssertStatusOK(tSC, "Load OK")
    Do $$$AssertEquals($Select($IsObject(rows):rows.%Size(),1:0), 1, "One row returned")

    Set obj = $Select($IsObject(rows):rows.%Get(0),1:"")
    Do $$$AssertTrue($IsObject(obj), "Row 0 is an object")
    Do $$$AssertEquals(obj.%Get("ReturnQueueName"), "", "ReturnQueueName normalized to empty string")
    Do $$$AssertEquals(obj.%Get("CorrespondingMessageId"), "", "CorrespondingMessageId normalized to empty string")

    Do ..CleanupSession(sid)
    Quit $$$OK
}

/// ST-002: Determinism across multiple calls over unchanged data
Method TestST002DeterminismAcrossCalls() As %Status
{
    Set sid = 9000012
    Do ..CleanupSession(sid)

    Set id1 = ..InsertHeader(sid, "2024-01-01 10:00:00", "Unit.Test.Body.A")
    Set id2 = ..InsertHeader(sid, "2024-01-01 11:00:00", "Unit.Test.Body.B")
    Set id3 = ..InsertHeader(sid, "2024-01-01 11:30:00", "Unit.Test.Body.C")
    Set idx = ..InsertHeader(sid, "2024-01-01 09:00:00", "HS.Util.Trace.Request")

    Set rows1 = "", rows2 = ""
    Set tSC1 = ##class(MALIB.Util.DiagramTool).LoadHeadersForSession(sid, .rows1)
    Set tSC2 = ##class(MALIB.Util.DiagramTool).LoadHeadersForSession(sid, .rows2)
    Do $$$AssertStatusOK(tSC1, "First load OK")
    Do $$$AssertStatusOK(tSC2, "Second load OK")
    Do $$$AssertEquals(..JoinIdsFromRows(rows1), ..JoinIdsFromRows(rows2), "Deterministic order across calls")

    Do ..CleanupSession(sid)
    Quit $$$OK
}

/// ST-002: Many rows with identical TimeCreated tie-break by ID ascending
Method TestST002LargeTieBreakByID() As %Status
{
    Set sid = 9000013
    Do ..CleanupSession(sid)

    Set tSame = "2024-01-01 12:00:00"
    Set idA = ..InsertHeader(sid, tSame, "Unit.Test.Body.A")
    Set idB = ..InsertHeader(sid, tSame, "Unit.Test.Body.B")
    Set idC = ..InsertHeader(sid, tSame, "Unit.Test.Body.C")
    Set idD = ..InsertHeader(sid, tSame, "Unit.Test.Body.D")
    Set idE = ..InsertHeader(sid, tSame, "Unit.Test.Body.E")

    Set rows = ""
    Set tSC = ##class(MALIB.Util.DiagramTool).LoadHeadersForSession(sid, .rows)
    Do $$$AssertStatusOK(tSC, "Load OK")

    ; Build expected ascending ID list
    Kill asc
    Set asc(idA)="", asc(idB)="", asc(idC)="", asc(idD)="", asc(idE)=""
    Set sExp = "", first = 1, k = ""
    For {
        Set k = $Order(asc(k))
        Quit:k=""
        If 'first Set sExp = sExp_","
        Set sExp = sExp_k
        Set first = 0
    }

    Do $$$AssertEquals(..JoinIdsFromRows(rows), sExp, "IDs ascending when TimeCreated identical")

    Do ..CleanupSession(sid)
    Quit $$$OK
}

/// ST-002: Invocation values are preserved (no transformation by loader)
Method TestST002InvocationPreserved() As %Status
{
    Set sid = 9000014
    Do ..CleanupSession(sid)

    ; Insert three rows in increasing TimeCreated so order is deterministic
    Set idA = ..InsertHeader(sid, "2024-01-01 10:00:00", "Unit.Test.Body.A")
    Set idB = ..InsertHeader(sid, "2024-01-01 11:00:00", "Unit.Test.Body.B")
    Set idC = ..InsertHeader(sid, "2024-01-01 12:00:00", "Unit.Test.Body.C")

    ; Set Invocation values in the table (actual logical values depend on datatype)
    &sql(UPDATE Ens.MessageHeader SET Invocation='Inproc' WHERE ID = :idA)
    &sql(UPDATE Ens.MessageHeader SET Invocation='Queue' WHERE ID = :idB)
    &sql(UPDATE Ens.MessageHeader SET Invocation='Other' WHERE ID = :idC)

    ; Read back the stored logical values to compare with loader output
    Set invA="", invB="", invC=""
    &sql(SELECT Invocation INTO :invA FROM Ens.MessageHeader WHERE ID = :idA)
    &sql(SELECT Invocation INTO :invB FROM Ens.MessageHeader WHERE ID = :idB)
    &sql(SELECT Invocation INTO :invC FROM Ens.MessageHeader WHERE ID = :idC)

    Set rows = ""
    Set tSC = ##class(MALIB.Util.DiagramTool).LoadHeadersForSession(sid, .rows)
    Do $$$AssertStatusOK(tSC, "Load OK")
    Do $$$AssertEquals($Select($IsObject(rows):rows.%Size(),1:0), 3, "3 rows returned")

    ; Expect order by TimeCreated then ID: idA, idB, idC
    Set r0 = rows.%Get(0), r1 = rows.%Get(1), r2 = rows.%Get(2)
    Do $$$AssertEquals(r0.%Get("ID"), idA, "First row is the earliest by TimeCreated")
    Do $$$AssertEquals(r1.%Get("ID"), idB, "Second row is next by TimeCreated")
    Do $$$AssertEquals(r2.%Get("ID"), idC, "Third row is latest by TimeCreated")

    ; Verify loader preserves Invocation exactly as stored in SQL (no transformation)
    Do $$$AssertEquals(r0.%Get("Invocation"), invA, "Invocation preserved for first row")
    Do $$$AssertEquals(r1.%Get("Invocation"), invB, "Invocation preserved for second row")
    Do $$$AssertEquals(r2.%Get("Invocation"), invC, "Invocation preserved for third row")

    Do ..CleanupSession(sid)
    Quit $$$OK
}

/// Helper: create a %DynamicObject row with required fields for correlation tests
Method NewRow(pID As %Integer, pInvocation As %String, pType As %String, pSrc As %String, pDst As %String, pRQN As %String = "", pCorr As %String = "", pLabel As %String = "Unit.Test.Body", pSess As %Integer = 1) As %RegisteredObject
{
        Set row = ##class(%DynamicObject).%New()
        Do row.%Set("ID", pID)
        Do row.%Set("Invocation", pInvocation)
        Do row.%Set("MessageBodyClassName", pLabel)
        Do row.%Set("SessionId", pSess)
        Do row.%Set("SourceConfigName", pSrc)
        Do row.%Set("TargetConfigName", pDst)
        Do row.%Set("ReturnQueueName", $Get(pRQN,""))
        Do row.%Set("CorrespondingMessageId", $Get(pCorr,""))
        Do row.%Set("TimeCreated", "")
        Do row.%Set("Type", pType)
        Quit row
}

/// Helper: make a new %DynamicArray
Method NewRowsArray() As %RegisteredObject
{
        Quit ##class(%DynamicArray).%New()
}

/// Helper: push a row into an array
Method PushRow(ByRef pArr As %DynamicArray, pRow As %RegisteredObject) As %Status
{
        Do pArr.%Push(pRow)
        Quit $$$OK
}

/// Helper: run CorrelateEvents
Method Correlate(pRows As %DynamicArray, Output pEvents As %DynamicArray) As %Status
{
        Quit ##class(MALIB.Util.DiagramTool).CorrelateEvents(pRows, .pEvents)
}

/// Helper: find an event in pEvents by ID (and optional type)
Method FindEventByID(pEvents As %DynamicArray, pID As %Integer, pType As %String = "") As %RegisteredObject
{
        Set ev=""
        Quit:'$IsObject(pEvents) ev
        Set len = pEvents.%Size()
        For i=0:1:len-1 {
            Set e = pEvents.%Get(i)
            Continue:'$IsObject(e)
            Set tID = e.%Get("ID")
            If (tID=pID) {
                Set tET = e.%Get("EventType")
                If (pType="")!(($ZCONVERT(tET,"U")=$ZCONVERT(pType,"U"))) {
                    Set ev=e
                    Quit
                }
            }
        }
        Quit ev
}

/// AC-05: Invocation handling and unknown defaulting/warning
Method TestAC05InvocationHandling() As %Status
{
        ; Direct mapping checks
        Do $$$AssertEquals(##class(MALIB.Util.DiagramTool).ArrowForInvocation("Inproc"), "->>", "Inproc maps to ->>")
        Do $$$AssertEquals(##class(MALIB.Util.DiagramTool).ArrowForInvocation("QUEUE"), "-->>", "Queue maps to -->>")
        Do $$$AssertEquals(##class(MALIB.Util.DiagramTool).ArrowForInvocation("ASYNCFAST"), "->>", "Unknown maps to ->>")

        ; Event-level warning for unknown
        Set rows = ..NewRowsArray()
        Do ..PushRow(rows, ..NewRow(1,"ASYNCFAST","Request","A","B"))
        Set events=""
        Set tSC = ..Correlate(rows, .events)
        Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")
        Set ev = ..FindEventByID(events,1,"Request")
        Do $$$AssertTrue($IsObject(ev), "Request event found")
        Do $$$AssertEquals(ev.%Get("Arrow"), "->>", "Unknown invocation defaults to ->>")
        Set notes = ""
        If ev.%IsDefined("Notes") Set notes = ev.%Get("Notes")
        Do $$$AssertTrue(notes["Unknown Invocation", "Unknown invocation warning present")
        Quit $$$OK
}

/// AC-06: Inproc correlation basic (reversed endpoints, forward-only)
Method TestAC06InprocCorrelationBasic() As %Status
{
        Set rows = ..NewRowsArray()
        Do ..PushRow(rows, ..NewRow(100,"Inproc","Request","A","B"))
        Do ..PushRow(rows, ..NewRow(101,"Inproc","Response","B","A"))
        Set events=""
        Set tSC = ..Correlate(rows, .events)
        Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")
        Do $$$AssertEquals($Select($IsObject(events):events.%Size(),1:0), 2, "Two events emitted")
        Set req = ..FindEventByID(events,100,"Request")
        Set resp = ..FindEventByID(events,101,"Response")
        Do $$$AssertTrue($IsObject(req), "Request event found")
        Do $$$AssertTrue($IsObject(resp), "Response event found")
        Do $$$AssertEquals(req.%Get("Arrow"), "->>", "Inproc request arrow")
        Do $$$AssertEquals(resp.%Get("Arrow"), "->>", "Inproc response arrow")
        Do $$$AssertEquals(resp.%Get("PairWithID"), 100, "Response pairs with request")
        Quit $$$OK
}

/// AC-06: CorrMsgId confirm and conflict handling
Method TestAC06InprocCorrMsgIdConfirmAndConflict() As %Status
{
        Set rows = ..NewRowsArray()
        ; Confirm case: CorrMsgId matches request ID
        Do ..PushRow(rows, ..NewRow(110,"Inproc","Request","A","B"))
        Do ..PushRow(rows, ..NewRow(111,"Inproc","Response","B","A","",110))
        ; Conflict case: CorrMsgId conflicts, still pair by order and warn
        Do ..PushRow(rows, ..NewRow(120,"Inproc","Request","C","D"))
        Do ..PushRow(rows, ..NewRow(121,"Inproc","Response","D","C","",999))
        Set events=""
        Set tSC = ..Correlate(rows, .events)
        Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")

        Set r111 = ..FindEventByID(events,111,"Response")
        Do $$$AssertTrue($IsObject(r111), "Confirm response found")
        Do $$$AssertEquals(r111.%Get("PairWithID"), 110, "Confirmed pairing uses CorrMsgId match")
        Set notes111 = ""
        If r111.%IsDefined("Notes") Set notes111 = r111.%Get("Notes")
        Do $$$AssertEquals(notes111, "", "No warning on confirm")

        Set r121 = ..FindEventByID(events,121,"Response")
        Do $$$AssertTrue($IsObject(r121), "Conflict response found")
        Do $$$AssertEquals(r121.%Get("PairWithID"), 120, "Conflict still pairs by order")
        Set notes121 = ""
        If r121.%IsDefined("Notes") Set notes121 = r121.%Get("Notes")
        Do $$$AssertTrue(notes121["CorrMsgId conflict", "Conflict warning present")
        Quit $$$OK
}

/// AC-07: Queued correlation (primary CorrMsgId)
Method TestAC07QueuedPrimaryCorrMsgId() As %Status
{
        Set rows = ..NewRowsArray()
        Do ..PushRow(rows, ..NewRow(200,"Queue","Request","A","B","R1",""))
        Do ..PushRow(rows, ..NewRow(201,"Queue","Response","B","A","",200))
        Set events=""
        Set tSC = ..Correlate(rows, .events)
        Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")
        Set resp = ..FindEventByID(events,201,"Response")
        Do $$$AssertTrue($IsObject(resp), "Response found")
        Do $$$AssertEquals(resp.%Get("PairWithID"), 200, "Paired by CorrMsgId")
        Do $$$AssertEquals(resp.%Get("Arrow"), "-->>", "Queued response arrow -->>")
        Quit $$$OK
}

/// AC-07: Queued correlation (fallback ReturnQueueName with reversed endpoints)
Method TestAC07QueuedFallbackReturnQueueName() As %Status
{
        Set rows = ..NewRowsArray()
        Do ..PushRow(rows, ..NewRow(210,"Queue","Request","C","D","R2",""))
        Do ..PushRow(rows, ..NewRow(211,"Queue","Response","D","C","R2",""))
        Set events=""
        Set tSC = ..Correlate(rows, .events)
        Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")
        Set resp = ..FindEventByID(events,211,"Response")
        Do $$$AssertTrue($IsObject(resp), "Response found")
        Do $$$AssertEquals(resp.%Get("PairWithID"), 210, "Paired by ReturnQueueName fallback and reversed endpoints")
        Do $$$AssertEquals(resp.%Get("Arrow"), "-->>", "Queued response arrow -->>")
        Quit $$$OK
}

/// AC-07/AC-13: Queued unpaired request emits warning (best-effort)
Method TestAC07QueuedUnpairedWarning() As %Status
{
        Set rows = ..NewRowsArray()
        Do ..PushRow(rows, ..NewRow(220,"Queue","Request","E","F","",""))
        ; Add unrelated response that does not match CorrMsgId or fallback
        Do ..PushRow(rows, ..NewRow(221,"Queue","Response","X","Y","RZ",""))
        Set events=""
        Set tSC = ..Correlate(rows, .events)
        Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")
        Set req = ..FindEventByID(events,220,"Request")
        Do $$$AssertTrue($IsObject(req), "Queued request event found")
        Set notes = ""
        If req.%IsDefined("Notes") Set notes = req.%Get("Notes")
        Do $$$AssertTrue(notes["Unpaired queued request", "Unpaired queued warning present")
        Quit $$$OK
}

/// AC-07: Queued - mismatched CorrMsgId must NOT fallback even if RQN matches and endpoints reversed
Method TestAC07QueuedNoFallbackWhenCorrMsgIdMismatched() As %Status
{
        Set rows = ..NewRowsArray()
        Do ..PushRow(rows, ..NewRow(300,"Queue","Request","A","B","R3",""))
        Do ..PushRow(rows, ..NewRow(301,"Queue","Response","B","A","R3",999))
        Set events = ""
        Set tSC = ..Correlate(rows, .events)
        Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")
        Set req = ..FindEventByID(events,300,"Request")
        Do $$$AssertTrue($IsObject(req), "Request found")
        Set resp = ..FindEventByID(events,301,"Response")
        Do $$$AssertTrue('$IsObject(resp), "Mismatched CorrMsgId should not pair and response not emitted")
        Set notes = ""
        If req.%IsDefined("Notes") Set notes = req.%Get("Notes")
        Do $$$AssertTrue(notes["Unpaired queued request", "Request noted unpaired queued warning")
        Quit $$$OK
}

/// AC-06: Inproc two requests, responses arrive out-of-order; forward-only pairing
Method TestAC06InprocTwoRequestsOutOfOrderResponses() As %Status
{
        Set rows = ..NewRowsArray()
        Do ..PushRow(rows, ..NewRow(400,"Inproc","Request","A","B"))
        Do ..PushRow(rows, ..NewRow(401,"Inproc","Request","A","B"))
        Do ..PushRow(rows, ..NewRow(402,"Inproc","Response","B","A"))
        Do ..PushRow(rows, ..NewRow(403,"Inproc","Response","B","A"))
        Set events = ""
        Set tSC = ..Correlate(rows, .events)
        Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")
        Set r402 = ..FindEventByID(events,402,"Response")
        Set r403 = ..FindEventByID(events,403,"Response")
        Do $$$AssertTrue($IsObject(r402), "Response 402 found")
        Do $$$AssertTrue($IsObject(r403), "Response 403 found")
        Do $$$AssertEquals(r402.%Get("PairWithID"), 400, "First response pairs with first request")
        Do $$$AssertEquals(r403.%Get("PairWithID"), 401, "Second response pairs with second request")
        Quit $$$OK
}

/// AC-07: Queued fallback requires reversed endpoints even if RQN matches
Method TestAC07QueuedFallbackRequiresReversedEndpoints() As %Status
{
        Set rows = ..NewRowsArray()
        Do ..PushRow(rows, ..NewRow(500,"Queue","Request","A","B","R4",""))
        Do ..PushRow(rows, ..NewRow(501,"Queue","Response","B","X","R4",""))
        Set events = ""
        Set tSC = ..Correlate(rows, .events)
        Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")
        Set req = ..FindEventByID(events,500,"Request")
        Do $$$AssertTrue($IsObject(req), "Request found")
        Set resp = ..FindEventByID(events,501,"Response")
        Do $$$AssertTrue('$IsObject(resp), "Fallback requires reversed endpoints; no response emitted")
        Set notes = ""
        If req.%IsDefined("Notes") Set notes = req.%Get("Notes")
        Do $$$AssertTrue(notes["Unpaired queued request", "Unpaired queued warning present")
        Quit $$$OK
}

}
