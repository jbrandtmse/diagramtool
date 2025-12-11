Include (%occInclude, Ensemble)

Class MALIB.Util.DiagramTool.Episode Extends %RegisteredObject
{

/// Collection of events that belong to this episode (in order)
Property Events As %DynamicArray;

/// Whether this episode is eligible for episode-level compression
Property Compressible As %Boolean;

/// Root source participant for this episode (first business Request Src)
Property RootSrc As %String;

/// Root destination participant for this episode (first business Request Dst)
Property RootDst As %String;

/// Business-only signature used for equality/compression
Property Signature As %String;

/// Representative business label for this episode (used in loop headers)
Property RepLabel As %String;

}
