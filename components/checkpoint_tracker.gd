class_name CheckpointTracker
extends Node


signal checkpoint_updated(prev_idx : int, new_idx : int)


@export var default_value : int = -1 : set = set_default_value
@export var checkpoint_index : int = default_value : set = set_checkpoint


func _init() -> void:
	name = "CheckpointTracker"


func reset() -> void:
	checkpoint_index = default_value


func checkpoint(idx : int) -> bool:
	if idx != (checkpoint_index + 1):
		return false
	checkpoint_index += 1
	return true


func set_checkpoint(idx : int) -> void:
	if idx == checkpoint_index: return
	var prev_idx := checkpoint_index
	checkpoint_index = idx
	checkpoint_updated.emit(prev_idx, checkpoint_index)


func set_default_value(value : int) -> void:
	if value == default_value:
		return
	if checkpoint_index == default_value:
		checkpoint_index = value
	default_value = value
