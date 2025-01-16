class_name Leaderboard
extends Node

signal first_place_changed(new_first : Car, prev_first : Car)

@export var free_labels_when_hidden := false
@export var show_labels := true : set = set_show_labels

var leaderboard : Array[Car] = []
var first_place_car : Car

var _index_update_queue : Array[Car] = []

var _position_labels : Array[UprightLabel] = []


func _process(delta: float) -> void:
	_update_labels()
	set_process(false)


func _physics_process(delta: float) -> void:
	if leaderboard.is_empty():
		return
	
	for car in _index_update_queue:
		checkpoint_updated(car)
	_index_update_queue.clear()
	
	#leaderboard.sort_custom(_sort_ascending)
	#for i in range(leaderboard.size()):
		#if leaderboard[i] is NeuralCar:
			#leaderboard[i].label.set_text(str(leaderboard.size() - i))
	
	var current_first = leaderboard.back()
	if current_first != first_place_car:
		first_place_changed.emit(current_first, first_place_car)
		first_place_car = current_first
	
	set_process(true)
	set_physics_process(false)


func checkpoint_updated(car : Car):
	var prev_idx := leaderboard.find(car)
	if prev_idx == -1:
		push_warning("Attempted to update checkpoint for car not on the leaderboard.")
		return
	
	
	var new_idx := _get_new_index(prev_idx, car.checkpoint_index)
	if new_idx < 0:
		new_idx = 0
	
	new_idx = _move_entry(prev_idx, new_idx)


func _on_car_checkpoint_changed(car : Car):
	if not _index_update_queue.has(car):
		_index_update_queue.append(car)
	if not is_physics_processing(): set_physics_process(true)


func _get_new_index(list_idx : int, checkpoint_idx) -> int:
	var search_idx := list_idx
	if leaderboard[search_idx].checkpoint_index >= checkpoint_idx:
		search_idx = 0
	while leaderboard[search_idx].checkpoint_index < checkpoint_idx:
		search_idx += 1
		if search_idx == leaderboard.size():
			break
	if search_idx > list_idx:
		search_idx -= 1
	#assert(search_idx == 0 or checkpoint_idx > checkpoint_idxs[search_idx])
	return search_idx


func _move_entry(index : int, new_index : int) -> int:
	if index < 0 or index >= leaderboard.size():
		push_error("Index out of bounds: index %d is out of bounds for leaderboard of size %d." %[index, leaderboard.size()])
		return -1
	if  new_index < 0 or new_index >= leaderboard.size():
		push_error("Index out of bounds: new_index %d is out of bounds for leaderboard of size %d." %[new_index, leaderboard.size()])
		return -1
	
	var direction : int = 1 if index < new_index else -1
	
	var temp_car := leaderboard[index]
	
	while(index != new_index):
		leaderboard[index] = leaderboard[index + direction]
		index += direction
	
	leaderboard[new_index] = temp_car
	
	#var first_place_index := leaderboard.size() - 1
	#
	#if new_index == first_place_index or index == first_place_index:
		#set_process(true)
	
	return new_index


func add_array(cars : Array[Car]):
	for car : Car in cars:
		add(car)


func add(car : Car):
	var insert_index := leaderboard.bsearch_custom(car, func(x, y): return x.checkpoint_index < y.checkpoint_index, true)
	leaderboard.insert(insert_index, car)
	car.respawned.connect(_on_car_respawned.bind(car), CONNECT_DEFERRED)
	car.checkpoint_updated.connect(_on_car_checkpoint_changed.bind(car).unbind(1), CONNECT_DEFERRED)
	
	if show_labels:
		set_process(true)
	elif free_labels_when_hidden:
		return
	
	var label := _instanciate_label()
	label.set_text(str(insert_index))
	_attach_label(car, label)


func remove(car : NeuralCar) -> bool:
	var index := get_current_leaderboard_idx(car)
	if index < 0:
		return false
	leaderboard.remove_at(index)
	if not free_labels_when_hidden:
		_free_label(car)
	return true


func refresh():
	leaderboard.sort_custom(sort_cars_ascending)
	set_process(true)


func get_current_leaderboard_idx(car : Car, checkpoint_index := car.checkpoint_index) -> int:
	var search_idx := leaderboard.bsearch_custom(car, sort_cars_ascending, true)
	var index = leaderboard.find(car, search_idx)
	
	if index >= 0:
		return index
	else:
		return leaderboard.rfind(car, search_idx)


func set_show_labels(enabled := true) -> void:
	show_labels = enabled
	
	if show_labels: 
		if _position_labels.size() != leaderboard.size():
			_free_labels()
			for car in leaderboard:
				_attach_label(car)
	if not show_labels and free_labels_when_hidden:
		_free_labels()
		return
	
	for label in _position_labels:
		label.visible = enabled


func set_free_labels_when_hidden(enabled := true):
	if free_labels_when_hidden == enabled:
		return
	
	free_labels_when_hidden = enabled
	
	if free_labels_when_hidden:
		_free_labels()


func sort_cars_ascending(a : Car, b : Car) -> bool:
	return a.checkpoint_index < b.checkpoint_index


func _update_labels(labels := _position_labels):
	for label in labels:
		var parent := label.get_parent()
		if parent is Car:
			var index := get_current_leaderboard_idx(parent)
			label.set_text(str(leaderboard.size() - index))
		else:
			label.set_text("N/A")


func _on_car_respawned(car : Car):
	_on_car_checkpoint_changed(car)


func _attach_label(car : Car, label : UprightLabel = _instanciate_label()):
	car.add_child(label)


func _instanciate_label() -> UprightLabel:
	var label := UprightLabel.new()
	_position_labels.append(label)
	return label


func _free_label(car : Car) -> bool:
	var labels := _position_labels.filter(func(x): x.get_parent() == car)
	if labels.is_empty():
		return false
	for label in labels:
		label.queue_free()
	return true


func _instanciate_labels(n : int = leaderboard.size()) -> Array[UprightLabel]:
	var labels : Array[UprightLabel] = []
	labels.resize(n)
	for i in range(n):
		labels[i] = UprightLabel.new()
	return labels


func _free_labels(n : int = _position_labels.size()) -> void:
	for i in range(_position_labels.size() - n, _position_labels.size(), -1):
		_position_labels[i].queue_free()
	_position_labels.resize(_position_labels.size() - n)
