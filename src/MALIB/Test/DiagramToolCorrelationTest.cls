Include (%occInclude, Ensemble)

Class MALIB.Test.DiagramToolCorrelationTest Extends %UnitTest.TestCase
{

Method %OnNew(initvalue As %String = "") As %Status
{
    Quit ##super(initvalue)
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
    Do row.%Set("ReturnQueueName", $Get(pRQN, ""))
    Do row.%Set("CorrespondingMessageId", $Get(pCorr, ""))
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
    Set ev = ""
    Quit:'$IsObject(pEvents) ev
    Set len = pEvents.%Size()
    For i=0:1:len-1 {
        Set e = pEvents.%Get(i)
        Continue:'$IsObject(e)
        Set tID = e.%Get("ID")
        If (tID = pID) {
            Set tET = e.%Get("EventType")
            If (pType = "")!(($ZCONVERT(tET, "U") = $ZCONVERT(pType, "U"))) {
                Set ev = e
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
    Do ..PushRow(rows, ..NewRow(1, "ASYNCFAST", "Request", "A", "B"))
    Set events = ""
    Set tSC = ..Correlate(rows, .events)
    Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")
    Set ev = ..FindEventByID(events, 1, "Request")
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
    Do ..PushRow(rows, ..NewRow(100, "Inproc", "Request", "A", "B"))
    Do ..PushRow(rows, ..NewRow(101, "Inproc", "Response", "B", "A"))
    Set events = ""
    Set tSC = ..Correlate(rows, .events)
    Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")
    Do $$$AssertEquals($Select($IsObject(events):events.%Size(), 1:0), 2, "Two events emitted")
    Set req = ..FindEventByID(events, 100, "Request")
    Set resp = ..FindEventByID(events, 101, "Response")
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
    Do ..PushRow(rows, ..NewRow(110, "Inproc", "Request", "A", "B"))
    Do ..PushRow(rows, ..NewRow(111, "Inproc", "Response", "B", "A", "", 110))
    ; Conflict case: CorrMsgId conflicts, still pair by order and warn
    Do ..PushRow(rows, ..NewRow(120, "Inproc", "Request", "C", "D"))
    Do ..PushRow(rows, ..NewRow(121, "Inproc", "Response", "D", "C", "", 999))
    Set events = ""
    Set tSC = ..Correlate(rows, .events)
    Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")

    Set r111 = ..FindEventByID(events, 111, "Response")
    Do $$$AssertTrue($IsObject(r111), "Confirm response found")
    Do $$$AssertEquals(r111.%Get("PairWithID"), 110, "Confirmed pairing uses CorrMsgId match")
    Set notes111 = ""
    If r111.%IsDefined("Notes") Set notes111 = r111.%Get("Notes")
    Do $$$AssertEquals(notes111, "", "No warning on confirm")

    Set r121 = ..FindEventByID(events, 121, "Response")
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
    Do ..PushRow(rows, ..NewRow(200, "Queue", "Request", "A", "B", "R1", ""))
    Do ..PushRow(rows, ..NewRow(201, "Queue", "Response", "B", "A", "", 200))
    Set events = ""
    Set tSC = ..Correlate(rows, .events)
    Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")
    Set resp = ..FindEventByID(events, 201, "Response")
    Do $$$AssertTrue($IsObject(resp), "Response found")
    Do $$$AssertEquals(resp.%Get("PairWithID"), 200, "Paired by CorrMsgId")
    Do $$$AssertEquals(resp.%Get("Arrow"), "-->>", "Queued response arrow -->>")
    Quit $$$OK
}

/// AC-07: Queued correlation (fallback ReturnQueueName with reversed endpoints)
Method TestAC07QueuedFallbackReturnQueueName() As %Status
{
    Set rows = ..NewRowsArray()
    Do ..PushRow(rows, ..NewRow(210, "Queue", "Request", "C", "D", "R2", ""))
    Do ..PushRow(rows, ..NewRow(211, "Queue", "Response", "D", "C", "R2", ""))
    Set events = ""
    Set tSC = ..Correlate(rows, .events)
    Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")
    Set resp = ..FindEventByID(events, 211, "Response")
    Do $$$AssertTrue($IsObject(resp), "Response found")
    Do $$$AssertEquals(resp.%Get("PairWithID"), 210, "Paired by ReturnQueueName fallback and reversed endpoints")
    Do $$$AssertEquals(resp.%Get("Arrow"), "-->>", "Queued response arrow -->>")
    Quit $$$OK
}

/// AC-07/AC-13: Queued unpaired request emits warning (best-effort)
Method TestAC07QueuedUnpairedWarning() As %Status
{
    Set rows = ..NewRowsArray()
    Do ..PushRow(rows, ..NewRow(220, "Queue", "Request", "E", "F", "", ""))
    ; Add unrelated response that does not match CorrMsgId or fallback
    Do ..PushRow(rows, ..NewRow(221, "Queue", "Response", "X", "Y", "RZ", ""))
    Set events = ""
    Set tSC = ..Correlate(rows, .events)
    Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")
    Set req = ..FindEventByID(events, 220, "Request")
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
    Do ..PushRow(rows, ..NewRow(300, "Queue", "Request", "A", "B", "R3", ""))
    Do ..PushRow(rows, ..NewRow(301, "Queue", "Response", "B", "A", "R3", 999))
    Set events = ""
    Set tSC = ..Correlate(rows, .events)
    Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")
    Set req = ..FindEventByID(events, 300, "Request")
    Do $$$AssertTrue($IsObject(req), "Request found")
    Set resp = ..FindEventByID(events, 301, "Response")
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
    Do ..PushRow(rows, ..NewRow(400, "Inproc", "Request", "A", "B"))
    Do ..PushRow(rows, ..NewRow(401, "Inproc", "Request", "A", "B"))
    Do ..PushRow(rows, ..NewRow(402, "Inproc", "Response", "B", "A"))
    Do ..PushRow(rows, ..NewRow(403, "Inproc", "Response", "B", "A"))
    Set events = ""
    Set tSC = ..Correlate(rows, .events)
    Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")
    Set r402 = ..FindEventByID(events, 402, "Response")
    Set r403 = ..FindEventByID(events, 403, "Response")
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
    Do ..PushRow(rows, ..NewRow(500, "Queue", "Request", "A", "B", "R4", ""))
    Do ..PushRow(rows, ..NewRow(501, "Queue", "Response", "B", "X", "R4", ""))
    Set events = ""
    Set tSC = ..Correlate(rows, .events)
    Do $$$AssertStatusOK(tSC, "CorrelateEvents OK")
    Set req = ..FindEventByID(events, 500, "Request")
    Do $$$AssertTrue($IsObject(req), "Request found")
    Set resp = ..FindEventByID(events, 501, "Response")
    Do $$$AssertTrue('$IsObject(resp), "Fallback requires reversed endpoints; no response emitted")
    Set notes = ""
    If req.%IsDefined("Notes") Set notes = req.%Get("Notes")
    Do $$$AssertTrue(notes["Unpaired queued request", "Unpaired queued warning present")
    Quit $$$OK
}

}
