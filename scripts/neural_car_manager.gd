@tool
class_name NeuralCarManager
extends Node

signal reset
signal randomizing_networks
signal networks_randomized
signal new_generation(generation : int)
signal instanciated(car : NeuralCar)
signal destroyed(car : NeuralCar)
signal car_reset(car : NeuralCar)
signal network_ids_updated

signal network_outputs_received(data : Dictionary)
signal network_inputs_set

const INPUT_THRESH : float = 0.5
const DEFAULT_SAVE_PATH := "user://saved_networks.json"

@export var enabled : bool = true

@export var api_client : NeuralAPIClient : set = set_api_client
@export var track : BaseTrack : set = set_track

@export_group("Autoload")
@export var load_saved_networks : bool = false
@export_global_file("*.json") var network_load_path := DEFAULT_SAVE_PATH

@export_group("Autosave")
@export var save_failed_networks := true
@export var failed_gen_score_thresh : float = 0.6
@export var network_save_count : int = 200

@export_group("Training Parameters")
@export_range(0, 5000) var num_networks : int : set = set_num_networks
@export var gens_without_improvement_limit : int = 100
@export var batch_size : int = 50 : set = set_batch_size
@export var dynamic_batch := true

@export var parent_selection : NeuralAPIClient.ParentSelection

@onready var neural_cars: Node = $NeuralCars

var neural_car : PackedScene = preload("res://scenes/network_controlled_car.tscn")
var cars : Array[NeuralCar] = []
var active_cars : Dictionary = {}
var batch_manager : BatchManager = BatchManager.new(batch_size)

var initial_networks : Array = []

var network_ids : Array
var id_queue_index : int = 0
var id_queue_semaphore := Semaphore.new()

var network_scores : Dictionary = {}

var cars_active_mutex : Mutex = Mutex.new()
var cars_active : int = 0

var generation : int = 0
var gens_without_improvement : int = 0
var improvement_flag : bool = false

var network_outputs : Array[Array]

var highest_score : float = 0
var highscore_mutex : Mutex = Mutex.new()

var api_connected : bool = false
var api_configured : bool = false

var batch_update_semaphore := Semaphore.new()

var ignoring_deactivations := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	batch_update_semaphore.post()
	id_queue_semaphore.post()
	
	set_process(false)
	
	if Engine.is_editor_hint():
		update_configuration_warnings()
		return
	
	if enabled:
		__update_car_count() 


func pause():
	set_process(false)


func resume():
	if api_connected and api_configured:
		set_process(true)
	else:
		push_error("Unable to resume: API is not connected.")

#TODO: Create track.get_absolute_progress method to replace most of this function
func get_reward(car : NeuralCar) -> float:
	var score : float = car.score_adjustment
	
	#var checkpoints_passed : int = (car.laps_completed * track.num_checkpoints) + car.checkpoint_index
	#score += checkpoints_passed * 0.1
	
	var track_progress : float
	#var rotation_bonus : float
	
	if car.active:
		track_progress = track.get_absolute_progress(car.global_position, car.checkpoint_index)
		#rotation_bonus = get_rotation_bonus(car.global_position, car.global_rotation)
	else:
		track_progress = track.get_absolute_progress(car.final_pos, car.checkpoint_index)
		
	
	score += track_progress
	#score += rotation_bonus
	
	return score

func __update_car_count():
	var num_cars_needed = batch_size
	if cars.size() > 0:
		num_cars_needed -= cars.size()
		if num_cars_needed == 0: return
		if num_cars_needed < 0:
			__remove_neural_cars(abs(num_cars_needed))
			return
	
	__add_neural_cars(num_cars_needed)


func __remove_neural_cars(num_cars : int):
	var removed : int = 0
	while removed < num_cars:
		var c : NeuralCar = cars.pop_back()
		c.queue_free()
		destroyed.emit(c)
		removed += 1

func __add_neural_cars(num_cars : int):
	var current_car_count := cars.size()
	cars.resize(current_car_count + num_cars)
	if not track: ignoring_deactivations = true
	for i in range(current_car_count, cars.size()):
		var c : NeuralCar = instanciate_neural_car(i)
		c.deactivated.connect(on_car_deactivated.bind(c), CONNECT_DEFERRED)
		
		neural_cars.add_child(c, false, Node.INTERNAL_MODE_FRONT)
		#c.score_changed.connect(on_network_score_changed, CONNECT_DEFERRED)
		#c.body_color = Color(randf(), randf(), randf())
		instanciated.emit(c)


func on_car_deactivated(car : NeuralCar):
	if not track or ignoring_deactivations: return
	if dynamic_batch:
		register_score(car)
		
		if id_queue_index < network_ids.size():
			active_cars.erase(str(car.id))
			reset_neural_car(network_ids[id_queue_index], car)
			id_queue_index += 1
			return
			
	decrement_active_count()
	#if car.checkpoint_index > 1: car.score += (car.laps_completed + track.get_lap_progress(car.position)) * 10


func decrement_active_count():
	cars_active_mutex.lock()
	cars_active -= 1
	
	if cars_active == 0 and api_connected:
		start_next_batch()
	
	cars_active_mutex.unlock()


func start_next_batch():
	if not batch_update_semaphore.try_wait(): return
	
	if not dynamic_batch:
		var batch_scores : Dictionary = get_network_scores()
		network_scores.merge(batch_scores, true)
	
	#if network_scores.size() >= num_networks:
		#var keys := network_scores.keys()
		#var start : int = int(keys[0])
		#for i in range(1, keys.size()):
			#var next := int(keys[i])
			#if next == start + 1:
				#start = next
				#continue
			#pass
	
	if dynamic_batch or (not batch_manager.has_next()):
		
		if improvement_flag:
			gens_without_improvement = 0
		else:
			gens_without_improvement += 1
		
		improvement_flag = false
		
		if gens_without_improvement >= gens_without_improvement_limit:
			await populate_random_generation()
		else:
			await populate_new_generation()
			#var values := network_scores.values()
			#values.sort()
			#print(values)
	reset_neural_cars()
	
	batch_update_semaphore.post()


func populate_new_generation():
	var msg := await api_client.populate_new_generation(network_scores)
	#assert(not api_client.error_occurred())
	if not api_client.error_occurred():
		update_network_ids(msg)
	on_new_generation_populated(msg)
	network_scores.clear()
	pass


func populate_random_generation():
	randomizing_networks.emit()
	
	if save_failed_networks:
		if highest_score >= failed_gen_score_thresh:
			save_networks(DEFAULT_SAVE_PATH, network_save_count, false)
	
	await api_client.populate_random_generation()
	var msg := await api_client.populate_new_generation(network_scores)
	assert(not api_client.error_occurred())
	if not api_client.error_occurred():
		update_network_ids(msg)
		networks_randomized.emit()
	generation = -1
	gens_without_improvement = 0
	highest_score = 0
	on_new_generation_populated(msg)
	network_scores.clear()


func reset_active_count():
	cars_active_mutex.lock()
	cars_active = batch_size
	cars_active_mutex.unlock()


func instanciate_neural_car(index : int) -> NeuralCar:
	var c : Car = neural_car.instantiate()
	c.id = index
	c.set_name("Neural Car " + str(index))
	cars[index] = c
	return c

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	
	if cars_active > 0:
		var network_inputs : Dictionary = get_network_inputs()
		var response : Dictionary = await get_network_outputs(network_inputs)
		
		if api_client.error_occurred(): return
		await set_neural_car_inputs(response["payload"]["networkOutputs"])


func get_network_outputs(network_inputs : Dictionary) -> Dictionary:
	var response : Dictionary = await api_client.get_network_outputs(network_inputs)
	return response


func set_neural_car_inputs(data : Dictionary) -> Signal:
	var group_task : int = WorkerThreadPool.add_group_task(set_neural_car_input.bind(data), data.size(), -1, true, "Set network inputs")
	WorkerThreadPool.wait_for_group_task_completion(group_task)
	call_thread_safe("emit_signal", "network_inputs_set")
	return network_inputs_set


func set_neural_car_input(network_index : int, data : Dictionary):
	var id := str(data.keys()[network_index])
	var c = active_cars[id]
	var outputs : Array = data[id]
	c.interpret_model_outputs(outputs)

func get_input_axis(positive : float, negative : float) -> float:
	if (positive >= INPUT_THRESH and negative > INPUT_THRESH) or (positive < INPUT_THRESH and negative < INPUT_THRESH):
		return 0
	elif positive > INPUT_THRESH:
		return 1
	else:
		return -1

func get_network_inputs() -> Dictionary:
	var inputs : Dictionary = {}
	
	for c : NeuralCar in cars:
		if c.active:
			var data := c.get_sensor_data()
			#data[16] = track.get_track_direction(c.global_position, 500)
			inputs[str(c.id)] = data
	
	#var mutex : Mutex = Mutex.new()
	#var task_id := WorkerThreadPool.add_group_task(get_inputs.bind(cars, inputs, mutex), cars.size(), -1, true, "Get sensor data")
	#WorkerThreadPool.wait_for_group_task_completion(task_id)
	
	return inputs

func get_inputs(index : int, car_array : Array[NeuralCar], registry : Dictionary, registry_mutex : Mutex):
	var car := car_array[index]
	if not car.active: return
	var inputs : Array[float] = car.get_sensor_data()
	inputs[16] = track.get_track_direction(car.global_position, 500)
	registry_mutex.lock()
	registry[car.id] = inputs
	registry_mutex.unlock()

func get_network_scores() -> Dictionary:
	var scores : Dictionary = {}
	
	for c : Car in cars:
		scores[str(c.id)] = get_reward(c)
	
	return scores


func register_score(car : NeuralCar):
	network_scores[str(car.id)] = get_reward(car)



func get_rotation_bonus(global_pos : Vector2, global_rotation : float) -> float:
	const TWO_PI : float = PI * 2
	var car_rotation : float = fmod(global_rotation + PI * 3.5, TWO_PI)
	var track_rotation : float = fmod(track.trajectory.curve.sample_baked_with_rotation(track.get_closest_trajectory_offset(global_pos) + 100).get_rotation() + TWO_PI, TWO_PI)
	var rotation_diff : float = fmod(abs(track_rotation - car_rotation), PI)
	return ((PI - rotation_diff) / PI) * 0.01


func set_track(new_track : BaseTrack):
	track = new_track
	
	if not network_ids or network_ids.is_empty():
		await network_ids_updated
	
	var idx = -1
	for car in cars:
		idx += 1
		reset_neural_car(network_ids[idx], car)
	
	await get_tree().create_timer(0.5).timeout
	
	for car in cars:
		car.active = true
	
	ignoring_deactivations = false


func set_num_networks(n : int):
	num_networks = n
	if is_node_ready() and not Engine.is_editor_hint():
		__update_car_count()


func on_network_score_changed(score : float):
	highscore_mutex.lock()
	if score > highest_score:
		highest_score = score
		improvement_flag = true
	highscore_mutex.unlock()


func on_new_generation_populated(_server_message: Dictionary) -> void:
	generation += 1
	new_generation.emit(generation)


func reset_neural_cars():
	#highest_score = -INF
	#print(cars.map(func(x): return x.get_score()).max())
	if not track: return
	#if batch_start_index == 50 or batch_start_index == 200:
		#pass
	
	active_cars.clear()
	
	var batch_ids : Array
	if dynamic_batch:
		batch_ids = network_ids.slice(0, batch_size)
		id_queue_index = batch_size
	else:
		batch_ids = batch_manager.next_batch()
	if batch_ids.is_empty(): return
	
	if cars.size() != batch_manager.batch_size:
		__update_car_count()
	
	for index in range(batch_ids.size()):
		var network_id := int(batch_ids[index])
		var car := cars[index]
		reset_neural_car(network_id, car)
	
	reset_active_count()
	
	reset.emit()


func reset_neural_car(network_id : int, car : NeuralCar):
	car.id = network_id
	active_cars[str(network_id)] = car
	car.reset(track.spawn_point)


func update_network_ids(server_msg : Dictionary):
	if dynamic_batch:
		network_ids = server_msg["payload"]["networkIDs"]
	else:
		batch_manager.set_elements(server_msg["payload"]["networkIDs"])
	network_ids_updated.emit()


func free_neural_cars():
	if cars.size() > 0:
		for c : NeuralCar in cars:
			if c: c.queue_free()
		cars = []


func _on_api_client_connected() -> void:
	if not api_configured:
		if load_saved_networks: initial_networks = load_networks(network_load_path)
		var response := await api_client.setup_session(num_networks, parent_selection,  initial_networks)
		
		if not api_client.error_occurred():
			update_network_ids(response)
			on_server_configured()
			
	api_connected = true


func set_batch_size(size : int):
	batch_size = size
	batch_manager.batch_size = size


func get_best_networks(n := num_networks) -> Array:
	var response := await api_client.get_best_networks(n)
	var networks : Array = response["payload"]["networks"]
	return networks

func save_networks(path := DEFAULT_SAVE_PATH, n := num_networks, overwrite = false) -> void:
	var networks : Array = await get_best_networks(n)
	if not overwrite: path = make_path_unique(path)
	var save_file = FileAccess.open(path, FileAccess.WRITE)
	save_file.store_string(JSON.stringify(networks))
	save_file.close()


func make_path_unique(path := DEFAULT_SAVE_PATH):
	var extension := path.get_extension()
	if not extension.is_empty(): extension = "." + extension
	var raw_path := path.get_basename()
	var duplicate_number : int = 0
	var unique_path := path
	while FileAccess.file_exists(unique_path):
		duplicate_number += 1
		unique_path = raw_path + ("(%d)" % duplicate_number) + extension
	return unique_path


func load_networks(save_path : String) -> Array:
	var save_file = FileAccess.open(save_path, FileAccess.READ)
	var file_contents = save_file.get_as_text()
	save_file.close()
	if save_file.get_error() != OK: return []
	var networks : Array = JSON.parse_string(file_contents)
	return networks


func _on_api_client_disconnected() -> void:
	api_connected = false
	set_process(false)


func _on_api_client_connection_error() -> void:
	_on_api_client_disconnected()



func on_server_configured() -> void:
	api_configured = true
	if not enabled: return
	reset.emit()
	reset_neural_cars()
	set_process(true)


class NetworkDataPacket:
	var id : int
	var node_values : Array[float]
	
	@warning_ignore("shadowed_variable")
	func _init(id : int, data : Array[float]):
		self.id = id
		self.node_values = data

class NetworkScorePacket:
	var id : int
	var score : float
	
	func _init(id : int, score : float):
		self.id = id
		self.score = score


func _on_timer_timeout() -> void:
	start_next_batch()


func set_api_client(client : NeuralAPIClient):
	if api_client and not Engine.is_editor_hint():
		api_client.io_handler.connected.disconnect(_on_api_client_connected)
		api_client.io_handler.disconnected.disconnect(_on_api_client_disconnected)
		api_client.io_handler.connection_error.disconnect(_on_api_client_connection_error)
	
	api_client = client
	
	if api_client and not Engine.is_editor_hint():
		api_client.io_handler.connected.connect(_on_api_client_connected, CONNECT_DEFERRED)
		api_client.io_handler.disconnected.connect(_on_api_client_disconnected, CONNECT_DEFERRED)
		api_client.io_handler.connection_error.connect(_on_api_client_connection_error, CONNECT_DEFERRED)
	
	update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings : PackedStringArray = []
	
	if not api_client:
		warnings.append("NeuralCarManager requires a NeuralAPIClient.")
	
	return warnings
