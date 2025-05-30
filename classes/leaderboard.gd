class_name Leaderboard
extends Node

signal first_place_changed(new_first : Car, prev_first : Car)

@export var track : BaseTrack
@export var free_labels_when_hidden := false
@export var show_labels := true : set = set_show_labels

var leaderboard : Array[Node2D] = []
var first_place : Node2D

var _checkpoint_reached_order : Dictionary = {}

var _should_update := false

var _position_labels : Dictionary = {}

var _progress_dict : Dictionary[Node2D, float] = {}
var _progress_update_task : int = -1
var _leaderboard_update_task : int = -1
#TODO: remake 
func update_progress(index : int):
	var node : Node2D = leaderboard[index]
	var check_pos := track.get_checkpoint(node.checkpoint_tracker.checkpoint_index).global_position
	var next_check_pos := track.get_checkpoint(node.checkpoint_tracker.checkpoint_index + 1).global_position
	var check_to_check_dist := check_pos.distance_squared_to(next_check_pos)
	_progress_dict[node] = node.checkpoint_tracker.checkpoint_index - node.global_position.distance_squared_to(next_check_pos) / check_to_check_dist

func update_leaderboard() -> void:
	if _progress_update_task != -1:
		WorkerThreadPool.wait_for_group_task_completion(_progress_update_task)
		_progress_update_task = -1
	
	leaderboard.sort_custom(sort_new)
	var current_first = leaderboard.back()
	if current_first != first_place:
		emit_signal.call_deferred("first_place_changed", current_first, first_place)
		first_place = current_first

func sort_new(a : Node2D, b : Node2D) -> bool:
	return _progress_dict[a] < _progress_dict[b]

func _process(delta: float) -> void:
	if _leaderboard_update_task != -1:
		if not WorkerThreadPool.is_task_completed(_leaderboard_update_task):
			return
		WorkerThreadPool.wait_for_task_completion(_leaderboard_update_task)
		_leaderboard_update_task = -1
	_update_labels()
	set_process(false)


func _physics_process(delta: float) -> void:
	refresh()


func add_array(nodes : Array[Node2D]):
	for node : Node2D in nodes:
		add(node)


func add(node : Node2D) -> bool:
	if not node.is_node_ready():
		await node.ready
	
	var checkpoint_tracker : CheckpointTracker = node.get_node_or_null("CheckpointTracker")
	
	if not checkpoint_tracker:
		return false
	
	_checkpoint_entered(checkpoint_tracker.checkpoint_index, node)
	checkpoint_tracker.checkpoint_updated.connect(_on_checkpoint_changed.bind(node))
	
	leaderboard.append(node)
	_queue_update()
	
	if show_labels:
		set_process(true)
	elif free_labels_when_hidden:
		return true
	
	_attach_label(node)
	
	return true


func remove(node : Node2D) -> void:
	leaderboard.erase(node)
	_free_label(node)
	Util.disconnect_from_signal(_on_checkpoint_changed, node.get_node("CheckpointTracker").checkpoint_updated)


func refresh():
	if not track or not track.is_node_ready():
		return
	
	if not leaderboard.is_empty():
		if _progress_update_task != -1 or _leaderboard_update_task != -1:
			return
		
		#_progress_update_task = WorkerThreadPool.add_group_task(update_progress, leaderboard.size(), -1, false, "Update Progress")
		for i in range(leaderboard.size()):
			update_progress(i)
		_leaderboard_update_task = WorkerThreadPool.add_task(update_leaderboard, false, "Update Leaderboard")
			
		#leaderboard.sort_custom(_sort_ascending)
		#
		#var current_first = leaderboard.back()
		#if current_first != first_place:
			#emit_signal.call_deferred("first_place_changed", current_first, first_place)
			#first_place = current_first
	#
		set_process(true)
	_updated()


func get_current_leaderboard_idx(node : Node) -> int:
	return leaderboard.find(node)


func set_show_labels(enabled := true) -> void:
	show_labels = enabled
	
	if free_labels_when_hidden:
		if show_labels:
			_instanciate_labels()
		else:
			_free_labels()
			return
	
	for label in _position_labels.values():
		label.visible = enabled


func set_free_labels_when_hidden(enabled := true):
	if free_labels_when_hidden == enabled:
		return
	
	free_labels_when_hidden = enabled
	
	if free_labels_when_hidden and not show_labels:
		_free_labels()


func _queue_update() -> void:
	if _should_update:
		return
	
	_should_update = true
	set_physics_process(true)


func _updated() -> void:
	set_physics_process(false)
	_should_update = false


func _on_checkpoint_changed(prev_idx : int, new_idx : int, node : Node2D) -> void:
	_checkpoint_exited(prev_idx, node)
	_checkpoint_entered(new_idx, node)
	_queue_update()


func _checkpoint_exited(checkpoint_idx : int, node : Node2D) -> void:
	if checkpoint_idx in _checkpoint_reached_order:
		var array : Array =  _checkpoint_reached_order[checkpoint_idx]
		array.erase(node)
		if array.is_empty():
			_checkpoint_reached_order.erase(checkpoint_idx)


func _checkpoint_entered(checkpoint_idx : int, node : Node2D) -> void:
	if checkpoint_idx in _checkpoint_reached_order:
		_checkpoint_reached_order[checkpoint_idx].append(node)
	else:
		_checkpoint_reached_order[checkpoint_idx] = [node]


func _sort_ascending(a : Node2D, b : Node2D) -> bool:
	var index_a : int = a.checkpoint_tracker.checkpoint_index
	var index_b : int = b.checkpoint_tracker.checkpoint_index
	if index_a == index_b:
		return _checkpoint_reached_order[index_a].find(a) > _checkpoint_reached_order[index_b].find(b)
	else:
		return index_a < index_b


func _update_labels():
	for node in _position_labels.keys():
		var index := get_current_leaderboard_idx(node)
		var label : UprightLabel = _position_labels[node]
		if index >= 0:
			label.set_text.call_deferred(str(leaderboard.size() - index))
		else:
			label.set_text.call_deferred("N/A")


func _attach_label(node : Node2D) -> UprightLabel:
	var label := UprightLabel.new()
	_position_labels[node] = label
	label.set_text(str(leaderboard.size()))
	node.add_child(label)
	return label


func _free_label(node : Node2D) -> bool:
	var label : UprightLabel = _position_labels[node]
	if not label:
		return false
	label.queue_free()
	_position_labels.erase(node)
	return true


func _instanciate_labels() -> void:
	for node in leaderboard:
		_attach_label(node)


func _free_labels() -> void:
	for label in _position_labels.values():
		label.queue_free()
	_position_labels.clear()
