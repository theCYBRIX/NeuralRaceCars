class_name Leaderboard
extends Node

signal first_place_changed(new_first : Car, prev_first : Car)

@export var neural_car_manager : NeuralCarManager : set = set_car_manager

var leaderboard : Array[NeuralCar] = []
var checkpoint_idxs : PackedInt32Array = []
var first_place_car : NeuralCar

func _process(delta: float) -> void:
	var current_first = leaderboard.back()
	if current_first != first_place_car:
		first_place_changed.emit(current_first, first_place_car)
		first_place_car = current_first
	set_process(false)

func checkpoint_updated(car : NeuralCar):
	var prev_idx := get_current_leaderboard_idx(car, car.checkpoint_index - 1)
	if prev_idx == -1:
		push_warning("Attempted to update checkpoint for car not on the leaderboard.")
		return
	
	
	var new_idx := checkpoint_idxs.bsearch(car.checkpoint_index, true) - 1
	if new_idx < 0:
		new_idx = 0
	
	#assert(new_idx == 0 or checkpoint_idxs[new_idx] > checkpoint_idxs[new_idx - 1])
	
	new_idx = _move_entry(prev_idx, new_idx)
	car.label.set_text(str(leaderboard.size() - new_idx))


func _move_entry(index : int, new_index : int) -> int:
	if index < 0 or index >= leaderboard.size():
		push_error("Index out of bounds: index %d is out of bounds for leaderboard of size %d." %[index, leaderboard.size()])
		return -1
	if  new_index < 0 or new_index > leaderboard.size():
		push_error("Index out of bounds: new_index %d is out of bounds for leaderboard of size %d." %[new_index, leaderboard.size()])
		return -1
	
	if index == new_index: return index
	
	var car := leaderboard[index]
	var direction : int = 1 if index < new_index else -1
	
	for i : int in range(index, new_index, direction):
		leaderboard[i] = leaderboard[i + direction]
		leaderboard[i].label.set_text(str(leaderboard.size() - i))
		checkpoint_idxs[i] = checkpoint_idxs[i + direction]
	leaderboard[new_index] = car
	checkpoint_idxs[new_index] = car.checkpoint_index
	
	var first_place_index := leaderboard.size() - 1
	
	if new_index == first_place_index or index == first_place_index:
		set_process(true)
	
	return new_index


func add_array(cars : Array[NeuralCar]):
	for car : NeuralCar in cars:
		add(car)


func add(car : NeuralCar):
	var insert_index := checkpoint_idxs.bsearch(car.checkpoint_index, true)
	leaderboard.insert(insert_index, car)
	checkpoint_idxs.insert(insert_index, car.checkpoint_index)
	car.state_reset.connect(checkpoint_updated.bind(car), CONNECT_DEFERRED)
	car.checkpoint_updated.connect(checkpoint_updated.bind(car).unbind(1), CONNECT_DEFERRED)
	car.label.set_text(str(get_current_leaderboard_idx(car)))


func remove(car : NeuralCar):
	var index := get_current_leaderboard_idx(car)
	leaderboard.remove_at(index)
	checkpoint_idxs.remove_at(index)


func refresh():
	leaderboard.sort_custom(_sort_ascending)
	checkpoint_idxs = leaderboard.map(func(a : NeuralCar) -> int: return a.checkpoint_index)


func _sort_ascending(a : NeuralCar, b : NeuralCar) -> bool:
	if a.checkpoint_index == b.checkpoint_index:
		return leaderboard.find(a) < leaderboard.find(b)
	else: 
		return a.checkpoint_index < b.checkpoint_index


func get_current_leaderboard_idx(car : NeuralCar, checkpoint_index := car.checkpoint_index) -> int:
	var search_idx := checkpoint_idxs.bsearch(checkpoint_index, true)
	
	if search_idx < 0:
		search_idx = 0
	elif search_idx >= leaderboard.size():
		return leaderboard.find(car)
	
	while leaderboard[search_idx] != car:
		search_idx += 1
		if search_idx >= checkpoint_idxs.size() or checkpoint_idxs[search_idx] != checkpoint_index:
			return leaderboard.find(car)
	return search_idx


func _on_car_reset(car : NeuralCar):
	checkpoint_updated(car)


func set_car_manager(manager : NeuralCarManager):
	if neural_car_manager:
		if neural_car_manager.instanciated.is_connected(add):
			neural_car_manager.instanciated.disconnect(add)
		for car : NeuralCar in neural_car_manager.cars:
			if car.state_reset.is_connected(_on_car_reset):
				car.state_reset.disconnect(_on_car_reset)
	
	neural_car_manager = manager
	update_configuration_warnings()
	
	if not neural_car_manager: return
	
	neural_car_manager.instanciated.connect(add)
	add_array(neural_car_manager.cars)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings : PackedStringArray = []
	
	if not (get_parent() is NeuralCarManager):
		warnings.append("Leaderboard must a NeuralCarManager specified.")
	
	return warnings
