class_name Summary
extends RefCounted

var generation: int
var highest_score: float
var input_map: Array[int] = []
var network_count: int
var layout: Dictionary
var time_elapsed: float

static func from_dict(data: Dictionary) -> Summary:
	var summary = Summary.new()
	
	summary.generation = data.get("generation", 0)
	summary.highest_score = data.get("highest_score", 0.0)
	summary.input_map.assign(data.get("input_map", []))
	summary.network_count = data.get("network_count", 0)
	summary.layout = data.get("layout", {})
	summary.time_elapsed = data.get("time_elapsed", 0.0)
	
	return summary
