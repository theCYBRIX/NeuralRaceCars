@tool

class_name EvolutionManager
extends NeuralCarManager


signal randomizing_networks
signal networks_randomized

signal new_generation(generation : int)


@export_group("Training Parameters")
@export_range(0, Util.INT_32_MAX_VALUE) var num_networks : int : set = set_num_networks
@export var gens_without_improvement_limit : int = 100
@export_color_no_alpha var batch_colors : Array[Color] = [Color.GREEN]
@export var parent_selection : NeuralAPIClient.ParentSelection

@export_group("Autosave")
@export var save_failed_networks := true
@export var failed_gen_score_thresh : float = 2.1
@export var network_save_count : int = 200


var generation : int = 0
var gens_without_improvement : int = 0
var improvement_flag : bool = false

var initial_networks : Array = []

var network_scores : Dictionary = {}

var highest_score : float = 0
var highscore_mutex : Mutex = Mutex.new()

var id_queue_index : int = 0

var api_configured : bool = false


func _ready() -> void:
	super._ready()
	
	_api_client.call_deferred("start")


func on_network_score_changed(score : float):
	highscore_mutex.lock()
	if score > highest_score:
		if highest_score >= 2.0 and score > 2.0:
			get_tree().call_group("Cars", "set_deactivate_on_contact", false) 
		highest_score = score
		improvement_flag = true
	highscore_mutex.unlock()


func on_new_generation_populated() -> void:
	generation += 1
	new_generation.emit(generation)


func _on_car_deactivated(car : NeuralCar):
	register_score(car)
	
	super._on_car_deactivated(car)
	
	if id_queue_index < _api_client.training_network_ids.size():
		var batch_index : int = id_queue_index / num_cars
		car.respawned.connect(car.set_body_color.bind(batch_colors[batch_index % batch_colors.size()]), CONNECT_ONE_SHOT)
		activate_neural_car(_api_client.training_network_ids[id_queue_index])
		id_queue_index += 1
		return
	
	if active_cars.is_empty():
		start_next_batch()


func start_training() -> void:
	if not api_configured:
		var error := await _api_client.setup_session(num_networks, parent_selection,  initial_networks)
		
		if error == OK:
			_on_server_configured()


func _on_server_configured() -> void:
	api_configured = true
	reset_neural_cars()
	set_process(true)


func set_num_networks(n : int):
	num_networks = n


func reset_neural_cars():
	
	deactivate_all()
	
	var batch_ids : Array = _api_client.training_network_ids.slice(0, num_cars)
	id_queue_index = batch_ids.size()
	
	if batch_ids.is_empty(): return
	
	for index in range(batch_ids.size()):
		var network_id := int(batch_ids[index])
		var error := activate_neural_car(network_id)
		if error != OK:
			push_warning("Unable to activate neural car: " + error_string(error))


func get_reward(car : NeuralCar) -> float:
	var score : float = car.score_adjustment
	var track_progress : float
	
	if car.active:
		track_progress = track.get_absolute_progress(car.global_position, car.checkpoint_index)
	else:
		track_progress = track.get_absolute_progress(car.final_pos, car.checkpoint_index)
	
	score += track_progress
	return score


func register_score(car : NeuralCar):
	network_scores[str(car.id)] = get_reward(car)


func start_next_batch():
	
	if improvement_flag:
		gens_without_improvement = 0
	else:
		gens_without_improvement += 1
	
	improvement_flag = false
	
	if gens_without_improvement >= gens_without_improvement_limit:
		await populate_random_generation()
	else:
		await populate_new_generation()
	
	reset_neural_cars()


func populate_new_generation():
	var error := await _api_client.populate_new_generation(network_scores)
	network_scores.clear()
	
	if error == OK:
		generation += 1
		on_new_generation_populated()


func populate_random_generation():
	randomizing_networks.emit()
	
	if save_failed_networks:
		if highest_score >= failed_gen_score_thresh:
			var networks := await get_best_networks(network_save_count)
			SaveManager.save_networks(networks)
	
	var error := await _api_client.populate_random_generation()
	network_scores.clear()
	
	if error == OK:
		networks_randomized.emit()
	
		gens_without_improvement = 0
		highest_score = 0
		generation = 0
		
		on_new_generation_populated()
		
		get_tree().call_group("Cars", "set_deactivate_on_contact", true)


func get_best_networks(n := num_networks) -> Array:
	return await _api_client.get_best_networks(n)


func _on_api_client_connected():
	super._on_api_client_connected()
	
	if not api_configured:
		start_training()
