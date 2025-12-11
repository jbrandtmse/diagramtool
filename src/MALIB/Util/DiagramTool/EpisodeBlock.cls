Include (%occInclude, Ensemble)

Class MALIB.Util.DiagramTool.EpisodeBlock Extends %RegisteredObject
{

/// Block type: "EPISODE" for a single expanded episode, "LOOP" for an
/// episode-level loop of N contiguous, identical episodes.
Property Type As %String;

/// Loop repetition count for episode-level loops. For Type="EPISODE"
/// this may be left at 0 or 1 and is not used for rendering.
Property LoopCount As %Integer;

/// The underlying episode represented by this block. For Type="LOOP"
/// this is the canonical episode whose Events body is emitted once
/// inside the loop. For Type="EPISODE" this is the single episode to emit.
Property Episode As MALIB.Util.DiagramTool.Episode;

}
