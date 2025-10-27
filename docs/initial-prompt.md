Build a utility class library in MALIB.Util.DiagramTool.cls (with supporting classes in the MALIB.Util.DiagramTool package) that builds mermaid sequence diagrams from IRIS interoperability trace sessions.  Use the Perplexity MCP to research any concept mentioned that you are not familiar with.
Take into consideration the following:
* Records representing IRIS Interoperability traces are in the Ens.MessageHeader table (defined by Ens.MessageHeader.cls and Ens.MessageHeaderBase.cls).   
*Example SQL for retrieving data by session from Ens.MessageHeader can be found in docs/sample.sql.   Sample data for the table can be found in docs/sampledata.csv.
*The actors for the mermaid diagram are defined by SourceConfigName and TargetConfigName.  The message type is defined by MessageBodyClassName
* Utility class library should be written in ObjectScript, using a best practices coding standard for ObjectScript (use Perplexity to research) and the rules defined in .clinerules/iris-objectscript-basics.md, .clinerules/objectscript.debugging.md, and .clinerules/objectscript-testing.md.  When there is a conflict between best practices and the rules in .clinerules, .clinerules should take priority.
* Public method(s) in MALIB.Util.DiagramTool.cls should be provided to specify the session(s) desired and the resulting mermaid sequence diagram(s) should be returned as a string output parameter, with the option to write the results to a specified file.
* Final output should also be written to the terminal.
* Sessions desired can be a single SessionId, ranges of SessionIds and/or a list of SessionIds (i.e. 1, 5-9, 12, 21, 36) passed as a string.
* Diagrams should support synchronous and asynchronous message patterns as indicated in the Invocation column.
* Diagrams should support looping of message requests and responses.  Loops can be identified by looking at that SourceConfigName and TargetConfigName and MessageBodyClassName of the Request name and the same fields of the correlated response message.
* For InProcess request Invocation, the correlated response message is implied based on order (TimeCreated), taking into consideration the SourceConfigName and TargetConfigName.  There may also be a CorrespondingMessageId
* For queued request Invocation, the response messages are correlated using CorrespondingMessageId and/or ReturnQueueName
* One mermaid diagram should be produced per session, the final output of diagrams should be deduplicated when multiple sessions result in the same diagram.
* No UI will be provided as part of MVP, this is strictly a class library that can be used by developers as a utility for documenting Interoperability solutions.
