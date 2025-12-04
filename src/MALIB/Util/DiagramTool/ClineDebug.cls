/* ===============================================================================================================
*
*   Centralized ClineDebug base class for ^ClineDebug tracing.
*   Default behavior: debug is OFF; Trace() is a no-op unless explicitly enabled.
*
*   This utility is intended for dev/test and focused troubleshooting scenarios.
*   Production flows SHOULD leave debug disabled unless explicitly toggled on
*   for a controlled investigation, to avoid unnecessary overhead and risk of
*   leaking sensitive data.
*
* ================================================================================================================
*/

Include HS.HC

Class MALIB.Util.ClineDebug Extends %RegisteredObject
{

/// <p>
/// Centralized control for ^ClineDebug debug tracing with a default-off toggle.
/// </p>
/// <p>
/// Semantics:
/// <ul>
///   <li>Debug is disabled by default (IsDebugEnabled() returns 0).</li>
///   <li>When disabled, Trace() / ..Trace() are no-ops and do not mutate ^ClineDebug.</li>
///   <li>Use ClearDebug() to explicitly clear ^ClineDebug; SetDebug(0) will also clear
///       the buffer for backward compatibility but should primarily be used to
///       disable tracing.</li>
/// </ul>
/// Usage:
/// <ul>
///   <li>Class-level:
///       <code>Do ##class(MALIB.Util.ClineDebug).SetDebug(1)</code>,
///       <code>Do ##class(MALIB.Util.ClineDebug).Trace("msg; ")</code>,
///       <code>Do ##class(MALIB.Util.ClineDebug).ClearDebug()</code></li>
///   <li>Instance-level (from any instance method in a subclass that
///       <code>Extends MALIB.Util.ClineDebug</code>):
///       <code>Do ..Trace("msg; ")</code> — this uses relative dot syntax to invoke the
///       inherited <code>ClassMethod Trace()</code> directly; there is no separate
///       instance <code>Method Trace()</code> on this base class.</li>
/// </ul>
/// Callers (application code or tests) should enable debug explicitly for a
/// focused run, consume ^ClineDebug via tooling, and then disable it again.
/// </p>
ClassMethod SetDebug(pOn As %Boolean = 1) As %Status
{
    Set tSC = $$$OK
    Try {
        Set ^ClineDebugEnabled = +pOn
        If +pOn=0 {
            Set ^ClineDebug = ""
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>
/// Clear the ^ClineDebug buffer without changing the enabled/disabled toggle.
/// </p>
ClassMethod ClearDebug() As %Status
{
    Set tSC = $$$OK
    Try {
        Set ^ClineDebug = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>
/// Returns 1 when ^ClineDebug tracing is enabled, 0 otherwise.
/// </p>
ClassMethod IsDebugEnabled() As %Boolean
{
    Quit +$Get(^ClineDebugEnabled, 0)
}

/// <p>
/// Append a message to ^ClineDebug only when debug is enabled.
/// </p>
/// <p>
/// This method is safe to call unconditionally from application or test code;
/// when debug is disabled it becomes a no-op and does not touch ^ClineDebug.
/// </p>
ClassMethod Trace(pMsg As %String = "") As %Status
{
    Set tSC = $$$OK
    Try {
        If +..IsDebugEnabled() {
            Set ^ClineDebug = $Get(^ClineDebug) _ pMsg
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
