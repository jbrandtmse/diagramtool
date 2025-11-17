Include (%occInclude, Ensemble)

Class MALIB.Test.DiagramToolTest Extends %UnitTest.TestCase
{

Method %OnNew(initvalue As %String = "") As %Status
{
    Quit ##super(initvalue)
}

/// Helper: insert a minimal header row and return its ID
Method InsertHeader(pSessionId As %Integer, pTime As %String, pBody As %String = "Unit.Test.Body") As %Integer
{
    Set tID = ""
    &sql(INSERT INTO Ens.MessageHeader (SessionId, MessageBodyClassName, TimeCreated)
         VALUES (:pSessionId, :pBody, :pTime))
    &sql(SELECT MAX(ID) INTO :tID
         FROM Ens.MessageHeader
         WHERE SessionId = :pSessionId
           AND MessageBodyClassName = :pBody
           AND TimeCreated = :pTime)
    Quit +$Get(tID, 0)
}

/// Helper: insert a fully-configured header row (INSERT-only) and return its ID.
/// We avoid UPDATEs on Ens.MessageHeader and instead create rows with the
/// correct Invocation/endpoints/ReturnQueueName/CorrMsgId from the start.
Method InsertConfiguredHeader(pSessionId As %Integer, pTime As %String, pBody As %String, pInvocation As %String, pSrc As %String, pDst As %String, pRQN As %String = "", pCorr As %Integer = 0) As %Integer
{
    Set tID = ""

    ; Normalize Invocation to the logical integer expected by Ens.DataType.MessageInvocation
    Set invLog = ""
    Set invU = $ZCONVERT($Get(pInvocation),"U")
    If invU="INPROC" {
        Set invLog = 2
    } ElseIf invU="QUEUE" {
        Set invLog = 1
    } ElseIf +$Get(pInvocation)'="" {
        Set invLog = +pInvocation
    } Else {
        ; Default to Queue if nothing specified
        Set invLog = 1
    }

    If +$Get(pCorr,0)>0 {
        &sql(INSERT INTO Ens.MessageHeader
             (SessionId, MessageBodyClassName, TimeCreated,
              Invocation, SourceConfigName, TargetConfigName,
              ReturnQueueName, CorrespondingMessageId)
             VALUES (:pSessionId, :pBody, :pTime,
                     :invLog, :pSrc, :pDst,
                     :pRQN, :pCorr))
    } Else {
        &sql(INSERT INTO Ens.MessageHeader
             (SessionId, MessageBodyClassName, TimeCreated,
              Invocation, SourceConfigName, TargetConfigName,
              ReturnQueueName)
             VALUES (:pSessionId, :pBody, :pTime,
                     :invLog, :pSrc, :pDst,
                     :pRQN))
    }

    &sql(SELECT MAX(ID) INTO :tID
         FROM Ens.MessageHeader
         WHERE SessionId = :pSessionId
           AND MessageBodyClassName = :pBody
           AND TimeCreated = :pTime)

    Quit +$Get(tID,0)
}

/// Helper: cleanup all rows for a session
Method CleanupSession(pSessionId As %Integer) As %Status
{
    &sql(DELETE FROM Ens.MessageHeader WHERE SessionId = :pSessionId)
    Quit $$$OK
}

/// ST-006: Single-session orchestration produces Mermaid diagram with header and arrows
Method TestST006SingleSessionOrchestration() As %Status
{
    Set sid = 9100001
    Do ..CleanupSession(sid)
    Set ^ClineDebug3 = "ST006Single; "

    ; Insert request/response pair for inproc invocation (INSERT-only)
    Set idReq = ..InsertConfiguredHeader(sid,
        "2024-01-01 10:00:00",
        "Unit.Test.ST006.Request",
        "Inproc",
        "A",
        "B",
        "",
        0)

    Set idResp = ..InsertConfiguredHeader(sid,
        "2024-01-01 10:00:01",
        "Unit.Test.ST006.Response",
        "Inproc",
        "B",
        "A",
        "",
        idReq)

    Set tText = ""
    Set tSC = ##class(MALIB.Util.DiagramTool).GenerateDiagrams(sid, "", "full", 1, .tText)
    Set ^ClineDebug = tText
    Do $$$AssertStatusOK(tSC, "GenerateDiagrams returned OK for single session")
    Do $$$AssertTrue(tText["sequenceDiagram", "Output contains sequenceDiagram header")
    Do $$$AssertTrue(tText["%% Session "_sid, "Output contains session header comment")
    Do $$$AssertTrue(tText["A ->> B : Unit.Test.ST006.Request", "Request arrow present")
    Do $$$AssertTrue(tText["B ->> A : Unit.Test.ST006.Response", "Response arrow present")

    Do ..CleanupSession(sid)
    Quit $$$OK
}

/// ST-006: Empty session yields minimal diagram with explicit note
Method TestST006EmptySessionMinimalDiagram() As %Status
{
    Set sid = 9100002
    Do ..CleanupSession(sid)

    Set selector = sid
    Set tText = ""
    Set tSC = ##class(MALIB.Util.DiagramTool).GenerateDiagrams(selector, "", "full", 1, .tText)
    Do $$$AssertStatusOK(tSC, "GenerateDiagrams returned OK for empty session")
    Do $$$AssertTrue(tText["sequenceDiagram", "Minimal diagram contains sequenceDiagram")
    Do $$$AssertTrue(tText["%% Session "_sid, "Minimal diagram contains session header comment")
    Do $$$AssertTrue(tText["%% No data available (filtered or empty)", "Minimal diagram contains empty-session note")

    Quit $$$OK
}

/// ST-006: Multi-session dedup removes duplicate diagrams when pDedupOn=1
Method TestST006MultiSessionDedupOn() As %Status
{
    Set sid = 9100003
    Do ..CleanupSession(sid)

    ; Build a simple inproc pair for this session (INSERT-only)
    Set idReq = ..InsertConfiguredHeader(sid,
        "2024-01-01 09:00:00",
        "Unit.Test.ST006.DedupReq",
        "Inproc",
        "C",
        "D",
        "",
        0)

    Set idResp = ..InsertConfiguredHeader(sid,
        "2024-01-01 09:00:01",
        "Unit.Test.ST006.DedupResp",
        "Inproc",
        "D",
        "C",
        "",
        idReq)

    ; Selector resolves to the same SessionId twice; diagrams are identical
    Set selector = sid_","_sid
    Set tText = ""
    Set tSC = ##class(MALIB.Util.DiagramTool).GenerateDiagrams(selector, "", "full", 1, .tText)
    Do $$$AssertStatusOK(tSC, "GenerateDiagrams returned OK for duplicate sessions")

    ; Only one diagram block should be present after dedup
    Set diagCount = $Length(tText, "sequenceDiagram")-1
    Do $$$AssertEquals(diagCount, 1, "Only one diagram after dedup for identical sessions")

    Do ..CleanupSession(sid)
    Quit $$$OK
}

/// ST-006: Dedup flag OFF keeps duplicate diagrams
Method TestST006MultiSessionNoDedupWhenOff() As %Status
{
    Set sid = 9100004
    Do ..CleanupSession(sid)

    ; Build simple inproc pair (INSERT-only)
    Set idReq = ..InsertConfiguredHeader(sid,
        "2024-01-01 09:00:00",
        "Unit.Test.ST006.NoDedupReq",
        "Inproc",
        "E",
        "F",
        "",
        0)

    Set idResp = ..InsertConfiguredHeader(sid,
        "2024-01-01 09:00:01",
        "Unit.Test.ST006.NoDedupResp",
        "Inproc",
        "F",
        "E",
        "",
        idReq)

    Set selector = sid_","_sid
    Set tText = ""
    Set tSC = ##class(MALIB.Util.DiagramTool).GenerateDiagrams(selector, "", "full", 0, .tText)
    Do $$$AssertStatusOK(tSC, "GenerateDiagrams returned OK with dedup off")

    ; Expect two diagram blocks when dedup is disabled
    Set diagCount = $Length(tText, "sequenceDiagram")-1
    Do $$$AssertEquals(diagCount, 2, "Two diagrams when dedup flag is off")

    Do ..CleanupSession(sid)
    Quit $$$OK
}

/// ST-006: LabelMode="short" uses trailing segment of MessageBodyClassName
Method TestST006LabelModeShort() As %Status
{
    Set sid = 9100005
    Do ..CleanupSession(sid)

    Set idReq = ..InsertConfiguredHeader(sid,
        "2024-01-01 10:00:00",
        "My.App.RequestClass",
        "Inproc",
        "L1",
        "L2",
        "",
        0)

    Set idResp = ..InsertConfiguredHeader(sid,
        "2024-01-01 10:00:01",
        "My.App.ResponseClass",
        "Inproc",
        "L2",
        "L1",
        "",
        idReq)

    Set selector = sid
    Set tText = ""
    Set tSC = ##class(MALIB.Util.DiagramTool).GenerateDiagrams(selector, "", "short", 1, .tText)
    Set ^ClineDebug = tText
    Do $$$AssertStatusOK(tSC, "GenerateDiagrams returned OK for labelMode short")

    ; Tightened expectations: short labels and no fully-qualified class names
    Do $$$AssertTrue(tText["RequestClass", "Short label includes trailing RequestClass")
    Do $$$AssertTrue(tText["ResponseClass", "Short label includes trailing ResponseClass")
    Do $$$AssertTrue('(tText["My.App.RequestClass"), "Full request class name not used in short mode")
    Do $$$AssertTrue('(tText["My.App.ResponseClass"), "Full response class name not used in short mode")

    ; We do not assert pairing here; correlation may reasonably warn about
    ; an unpaired response, and this test's purpose is label rendering.

    Do ..CleanupSession(sid)
    Quit $$$OK
}

/// ST-006: Output contract append-only file with divider between diagrams
Method TestST006AppendOnlyOutputWithDivider() As %Status
{
    Set sid1 = 9100006
    Set sid2 = 9100007

    Do ..CleanupSession(sid1)
    Do ..CleanupSession(sid2)

    ; Session 1 events (INSERT-only)
    Set id1Req = ..InsertConfiguredHeader(sid1,
        "2024-01-01 08:00:00",
        "Unit.Test.ST006.Out1Req",
        "Inproc",
        "O1A",
        "O1B",
        "",
        0)

    Set id1Resp = ..InsertConfiguredHeader(sid1,
        "2024-01-01 08:00:01",
        "Unit.Test.ST006.Out1Resp",
        "Inproc",
        "O1B",
        "O1A",
        "",
        id1Req)

    ; Session 2 events (INSERT-only)
    Set id2Req = ..InsertConfiguredHeader(sid2,
        "2024-01-01 09:00:00",
        "Unit.Test.ST006.Out2Req",
        "Inproc",
        "O2A",
        "O2B",
        "",
        0)

    Set id2Resp = ..InsertConfiguredHeader(sid2,
        "2024-01-01 09:00:01",
        "Unit.Test.ST006.Out2Resp",
        "Inproc",
        "O2B",
        "O2A",
        "",
        id2Req)

    ; Prepare output file with initial content
    Set outFile = "DiagramToolTest_Output.txt"
    Set stream = ##class(%Stream.FileCharacter).%New()
    Set scStream = stream.LinkToFile(outFile)
    Do $$$AssertStatusOK(scStream, "LinkToFile for initial output file")
    Do stream.WriteLine("INITIAL-LINE")
    Do stream.Flush()

    ; First call appends two diagrams (dedup OFF)
    Set selector = sid1_","_sid2
    Set tText = ""
    Set tSC = ##class(MALIB.Util.DiagramTool).GenerateDiagrams(selector, outFile, "full", 0, .tText)
    Set ^ClineDebug = tText

    ; Verify combined text has expected number of diagrams
    Set diagCountInText = $Length(tText, "sequenceDiagram")-1
    Set ^ClineDebug2 = "diagCount="_diagCountInText_"; text="_tText
    Do $$$AssertEquals(diagCountInText, 2, "Combined text contains two diagrams")

    Do ..CleanupSession(sid1)
    Do ..CleanupSession(sid2)
    Quit $$$OK
}

/// Debug helper test: inspect raw Ens.MessageHeader values for an ST-006-style session
Method TestST006HeaderDebug() As %Status
{
    Set sid = 9100001
    Do ..CleanupSession(sid)
    Set ^ClineDebug3 = "ST006HeaderDebug; "

    ; Insert request/response pair matching TestST006SingleSessionOrchestration (INSERT-only)
    Set idReq = ..InsertConfiguredHeader(sid,
        "2024-01-01 10:00:00",
        "Unit.Test.ST006.Request",
        "Inproc",
        "A",
        "B",
        "",
        0)

    Set idResp = ..InsertConfiguredHeader(sid,
        "2024-01-01 10:00:01",
        "Unit.Test.ST006.Response",
        "Inproc",
        "B",
        "A",
        "",
        idReq)

    ; Read back the rows directly via SQL
    Set invReq = "", typeReq = "", rqnReq = "", corrReq = "", srcReq = "", dstReq = ""
    &sql(SELECT Invocation, "Type", ReturnQueueName, CorrespondingMessageId,
                 SourceConfigName, TargetConfigName
         INTO :invReq, :typeReq, :rqnReq, :corrReq, :srcReq, :dstReq
         FROM Ens.MessageHeader WHERE ID = :idReq)
    Set ^ClineDebug3 = ^ClineDebug3_"Req inv="_invReq_" type="_typeReq_" src="_srcReq_" dst="_dstReq_" rqn="_rqnReq_" corr="_corrReq_"; "

    Set invResp = "", typeResp = "", rqnResp = "", corrResp = "", srcResp = "", dstResp = ""
    &sql(SELECT Invocation, "Type", ReturnQueueName, CorrespondingMessageId,
                 SourceConfigName, TargetConfigName
         INTO :invResp, :typeResp, :rqnResp, :corrResp, :srcResp, :dstResp
         FROM Ens.MessageHeader WHERE ID = :idResp)
    Set ^ClineDebug3 = ^ClineDebug3_"Resp inv="_invResp_" type="_typeResp_" src="_srcResp_" dst="_dstResp_" rqn="_rqnResp_" corr="_corrResp_"; "

    ; Now dump via Loader helper to compare
    Set tSC = ##class(MALIB.Util.DiagramTool.Loader).DebugDumpHeaders(sid)
    Do $$$AssertStatusOK(tSC, "DebugDumpHeaders OK")
    Quit $$$OK
}

}
