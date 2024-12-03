class_name IDManager
extends RefCounted

var counter : int = -1
var available_ids : Array = []

func next() -> int:
	if available_ids.size() > 0:
		return available_ids.pop_front()
	
	counter += 1
	return counter

func release(id : int) -> void:
	available_ids.append(id)
