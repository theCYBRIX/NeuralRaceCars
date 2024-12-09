class_name BatchManager
extends RefCounted

var batch_size : int
var batch_start_index : int = 0 : get = get_current_index
var elements : Array : set = set_elements


func _init(batch_size : int = 0, elements : Array = []) -> void:
	self.batch_size = batch_size
	self.elements = elements


func next_batch() -> Array:
	if not has_next():
		push_error("No next batch available.")
		return []
	
	var current_batch_size = min(elements.size() - batch_start_index, batch_size)
	
	var batch := elements.slice(batch_start_index, batch_start_index + current_batch_size)
	
	batch_start_index += current_batch_size
	
	return batch


func has_next() -> bool:
	return  batch_start_index < elements.size()


func get_current_index() -> int:
	return batch_start_index


func get_size() -> int:
	return elements.size()


func get_progress() -> float:
	return float(batch_start_index) / elements.size()


func set_elements(array : Array) -> void:
	elements = array
	reset()


func reset() -> void:
	batch_start_index = 0
