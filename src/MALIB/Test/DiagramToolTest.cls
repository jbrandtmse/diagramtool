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

}
