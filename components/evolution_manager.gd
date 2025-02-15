@tool

class_name EvolutionManager
extends NeuralCarManager

signal training_started
signal randomizing_networks
signal networks_randomized
signal training_state_refreshed(training_state : TrainingState)

signal generation_finished(generation : int)
signal new_generation(generation : int)

@export var recording_manager : TrainingRecordingManager

@export_group("Training Parameters")
@export var use_saved_training_state := true
@export_global_file("*.json", "*.res", "*.tres") var training_state_path := SaveManager.DEFAULT_SAVE_FILE_PATH
@export_range(0, Util.INT_32_MAX_VALUE) var num_networks : int : set = set_num_networks
@export var gens_without_improvement_limit : int = 100
@export_color_no_alpha var batch_colors : Array[Color] = []
@export var parent_selection : NeuralAPIClient.ParentSelection
@export var training_state : TrainingState : set = set_training_state

@export_group("Autosave", "autosave")
@export var autosave_enabled := true
@export var autosave_score_thresh : float = 2.1
@export var autosave_path := SaveManager.DEFAULT_SAVE_DIR_PATH + "training_state(autosave)." + SaveManager.TRAINING_STATE_FILE_EXTENSION
@export var autosave_network_count : int = 2000

var gens_without_improvement : int = 0

var improvement_flag : bool = false

var initial_networks : Array = []

var network_scores : Dictionary = {}
var prev_gen_scores : Dictionary = {}

var highscore_mutex : Mutex = Mutex.new()

var id_queue_index : int = 0

var api_configured : bool = false


func _init() -> void:
	_neural_car_scene = preload("res://scenes/training_car.tscn")
	ignore_deactivations = true
	
	if GameSettings.training_state:
		training_state = GameSettings.training_state
		
	elif use_saved_training_state:
		var state : TrainingState = SaveManager.load_training_state(training_state_path)
		if state:
			training_state = state
		else:
			var error : Error = SaveManager.get_load_error()
			push_warning("Unable to load training state: ", training_state_path, "\nReason: ", error_string(error))
			training_state = null
		
	elif not training_state:
		training_state = null


func _ready() -> void:
	super._ready()
	
	if not Engine.is_editor_hint():
		_api_client.call_deferred("start")
	
	if training_state:
		refresh_training_state_properties()
	
	assert(training_state != null)


func _process(delta: float) -> void:
	training_state.time_elapsed += delta


func on_network_score_changed(score : float):
	highscore_mutex.lock()
	if score > training_state.highest_score:
		if training_state.highest_score >= 2.0 and score > 2.0:
			get_tree().call_group("Cars", "set_deactivate_on_contact", false) 
		training_state.highest_score = score
		improvement_flag = true
	highscore_mutex.unlock()


func _on_new_generation_populated() -> void:
	new_generation.emit(training_state.generation)


func _instantiate_neural_car() -> void:
	pass


func _on_car_deactivated(car : NeuralCar):
	if _should_ignore_deactivations():
		return
	assert(_api_client._api_connected)
	register_score(car)
	
	super._on_car_deactivated(car)
	
	if id_queue_index < _api_client.training_network_ids.size():
		var batch_index : int = id_queue_index / num_cars
		#if batch_colors.size() > 0:
			#car.respawned.connect(car.set_body_color.bind(batch_colors[batch_index % batch_colors.size()]), CONNECT_ONE_SHOT)
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
	await reset_neural_cars()
	set_process(true)
	_training_started()


func _training_started() -> void:
	ignore_deactivations = false
	training_started.emit()


func set_num_networks(n : int):
	num_networks = n


func reset_neural_cars():
	
	deactivate_all()
	
	var batch_ids : Array = _api_client.training_network_ids.slice(0, num_cars)
	id_queue_index = batch_ids.size()
	
	if batch_ids.is_empty(): return
	
	for index in range(batch_ids.size()):
		var network_id := int(batch_ids[index])
		var error := await activate_neural_car(network_id)
		if error != OK:
			push_warning("Unable to activate neural car: " + error_string(error))


func get_reward(car : NeuralCar) -> float:
	var score : float = car.score_adjustment
	var track_progress : float = track.get_progress(car)
	
	score += track_progress
	return score


func register_score(car : NeuralCar):
	network_scores[str(car.id)] = get_reward(car)


func get_network_score(network_id : int) -> float:
	var str_id := str(network_id)
	if network_scores.has(str_id):
		return network_scores[str_id]
	else:
		return NAN


func start_next_batch():
	
	if improvement_flag:
		gens_without_improvement = 0
	else:
		gens_without_improvement += 1
	
	generation_finished.emit(training_state.generation)
	
	improvement_flag = false
	
	if gens_without_improvement >= gens_without_improvement_limit:
		await populate_random_generation()
	else:
		await populate_new_generation()
	
	reset_neural_cars()


func populate_new_generation():
	var error := await _api_client.populate_new_generation(network_scores)
	reset_network_scores()
	
	if error == OK:
		training_state.generation += 1
		_on_new_generation_populated()


func populate_random_generation():
	randomizing_networks.emit()
	
	if autosave_enabled:
		if training_state.highest_score >= autosave_score_thresh:
			save_networks(autosave_path, autosave_network_count)
	
	var error := await _api_client.populate_random_generation()
	reset_network_scores()
	
	if error == OK:
		networks_randomized.emit()
	
		gens_without_improvement = 0
		training_state.highest_score = 0
		training_state.generation = 0
		training_state.replays.clear()
		
		_on_new_generation_populated()
		
		get_tree().call_group("Cars", "set_deactivate_on_contact", true)


func reset_network_scores() -> void:
	prev_gen_scores = network_scores
	network_scores = {}


func get_best_networks(n := num_networks) -> Array[Dictionary]:
	var best_ids : Array[int] = get_best_network_ids(n)
	
	var best_networks_dict : Dictionary = await _api_client.get_networks(best_ids)
	var best_networks : Array[Dictionary] = []
	best_networks.resize(best_networks_dict.size())
	
	var index : int = 0
	for id in best_networks_dict.keys():
		best_networks[index] = {
			"id" : id,
			"network" : best_networks_dict[id],
			"score" : prev_gen_scores[id]
		}
		index += 1
	
	return best_networks


func save_networks(save_path : String, network_count : int) -> Error:
	var error := OK
	training_state.networks = await get_best_networks(min(network_count, num_networks))
	
	if _api_client.error_occurred():
		error = FAILED
	
	if error == OK:
		error = SaveManager.save_training_state(training_state, save_path)
	
	if error != OK:
		push_warning("Failed to save state. Reason: ", error_string(error))
	
	if recording_manager and recording_manager.enabled:
		ResourceSaver.save(recording_manager.training_replay_data, Util.make_path_unique(save_path.get_basename() + "(recording).tres"))
	#await evolution_manager.save_networks(save_path, min(200, evolution_manager.num_networks), true)
	return error


func set_training_state(state : TrainingState):
	var new_instance := not state
	if new_instance: state = TrainingState.new()
	training_state = state
	
	if is_node_ready():
		refresh_training_state_properties(not new_instance)
	


func refresh_training_state_properties(override_input_map := false) -> void:
	initial_networks = training_state.networks.map(func(x): return x.network if x.has("network") else x)
	if override_input_map and (training_state.input_map and training_state.input_map.size() > 0):
		input_mapping = training_state.input_map
	else:
		training_state.input_map = input_mapping
	
	training_state_refreshed.emit(training_state)
	
	if _api_client.is_node_ready():
		var io_handler := _api_client.io_handler
		if io_handler and api_configured:
			io_handler.stop()
			api_configured = false
			io_handler.start()


func get_best_network_ids(n := num_networks) -> Array[int]:
	var scores_and_ids : Array[ScoreAndID] = []
	scores_and_ids.resize(prev_gen_scores.size())
	
	var index : int = 0
	for id in prev_gen_scores.keys():
		scores_and_ids[index] = ScoreAndID.new(int(id), prev_gen_scores[id])
		index += 1
	
	scores_and_ids.sort_custom(ScoreAndID.sort_ascending)
	scores_and_ids = scores_and_ids.slice(scores_and_ids.size() - n)
	
	var best_ids : Array[int] = []
	best_ids.append_array(scores_and_ids.map(func(x : ScoreAndID) -> int: return x.id))
	
	return best_ids


func _should_ignore_deactivations() -> bool:
	if super._should_ignore_deactivations():
		return true
	return not api_connected or not api_configured


func _on_api_client_connected():
	super._on_api_client_connected()
	#
	#if not api_configured:
		#start_training()

class ScoreAndID:
	var id : int
	var score : float
	
	@warning_ignore("shadowed_variable")
	func _init(id : int, score : int) -> void:
		self.id = id
		self.score = score
	
	static func sort_ascending(a : ScoreAndID, b : ScoreAndID) -> bool:
		return a.score < b.score
		
	static func sort_descending(a : ScoreAndID, b : ScoreAndID) -> bool:
		return a.score > b.score
