@tool
class_name NeuralCarManager
extends Node

signal reset
signal new_generation
signal spawned(car : NeuralCar)
signal generation_countown_updatad(remaining_sec : int)

signal network_outputs_received(data : Dictionary)
signal network_inputs_set

const INPUT_THRESH : float = 0.5

@export var enabled : bool = true
@export var load_saved_networks : bool = false

@export var api_client : NeuralAPIClient : set = set_api_client
@export var track : BaseTrack : set = set_track

@export_group("Training Parameters")
@export_range(0, 1000) var num_networks : int : set = set_num_networks
@export var batch_size : int = 50

@export var parent_selection : NeuralAPIClient.ParentSelection

@onready var timer: Timer = $GenerationTimer

@onready var neural_cars: Node = $NeuralCars

var neural_car : PackedScene = preload("res://Scenes/network_controlled_car.tscn")
var cars : Array[NeuralCar] = []
var active_cars : Dictionary = {}

var network_scores : Dictionary = {}
var network_ids : Array = []

var batch_start_index : int = 0
var cars_active_mutex : Mutex = Mutex.new()
var cars_active : int = 0

var network_outputs : Array[Array]

var highest_score : float = 0
var highscore_mutex : Mutex = Mutex.new()

var api_connected : bool = false
var api_configured : bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(false)
	
	if Engine.is_editor_hint():
		update_configuration_warnings()
		return
	
	if enabled:
		__update_car_count() 


func get_reward(car : NeuralCar) -> float:
	var score : float = 0
	
	#var checkpoints_passed : int = (car.laps_completed * track.num_checkpoints) + car.checkpoint_index
	#score += checkpoints_passed * 0.1
	
	var track_progress : float
	var rotation_bonus : float
	
	if car.active:
		track_progress = car.laps_completed + track.get_lap_progress(car.global_position, car.checkpoint_index)
		rotation_bonus = get_rotation_bonus(car.global_position, car.global_rotation)
	else:
		track_progress = car.laps_completed + track.get_lap_progress(car.final_pos, car.checkpoint_index)
		rotation_bonus = get_rotation_bonus(car.final_pos, car.final_rotation)
	
	score += track_progress
	score += rotation_bonus
	
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
		removed += 1

func __add_neural_cars(num_cars : int):
	var current_car_count := cars.size()
	cars.resize(current_car_count + num_cars)
	for i in range(current_car_count, cars.size()):
		var c : NeuralCar = instanciate_neural_car(i)
		c.deactivated.connect(on_car_deactivated.bind(c), CONNECT_DEFERRED)
		c.score_changed.connect(on_network_score_changed, CONNECT_DEFERRED)
		#c.body_color = Color(randf(), randf(), randf())
		neural_cars.add_child(c, false, Node.INTERNAL_MODE_FRONT)


func on_car_deactivated(car : NeuralCar):
	decrement_active_count()
	#if car.checkpoint_index > 1: car.score += (car.laps_completed + track.get_lap_progress(car.position)) * 10


func decrement_active_count():
	cars_active_mutex.lock()
	cars_active -= 1
	
	if cars_active == 0 and api_connected:
		start_next_batch()
	
	cars_active_mutex.unlock()


func start_next_batch():
	var batch_scores : Dictionary = get_network_scores()
	network_scores.merge(batch_scores, true)
	
	batch_start_index += batch_size
	
	if batch_start_index >= num_networks:
		batch_start_index = 0
		populate_new_generation()
		#var values := network_scores.values()
		#values.sort()
		#print(values)
	
	reset_neural_cars()
	timer.start()


func populate_new_generation():
	var msg := api_client.populate_new_generation(network_scores)
	if not msg.is_empty():
		update_network_ids(msg)
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
	if not timer.is_stopped():
		generation_countown_updatad.emit(timer.time_left)
	
	if cars_active > 0:
		var network_inputs : Dictionary = get_network_inputs()
		var response : Dictionary = await get_network_outputs(network_inputs)
		
		if response.is_empty(): return
		await set_neural_car_inputs(response["payload"]["networkOutputs"])


func get_network_outputs(network_inputs : Dictionary) -> Signal:
	var response : Dictionary = api_client.get_network_outputs(network_inputs)
	call_thread_safe("emit_signal", "network_outputs_received", response)
	
	return network_outputs_received


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
			data[16] = track.get_track_direction(c.global_position, 500)
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


func get_rotation_bonus(global_pos : Vector2, global_rotation : float) -> float:
	const TWO_PI : float = PI * 2
	var car_rotation : float = fmod(global_rotation + PI * 3.5, TWO_PI)
	var track_rotation : float = fmod(track.trajectory.curve.sample_baked_with_rotation(track.get_closest_trajectory_offset(global_pos) + 100).get_rotation() + TWO_PI, TWO_PI)
	var rotation_diff : float = fmod(abs(track_rotation - car_rotation), PI)
	return ((PI - rotation_diff) / PI) * 0.01


func set_track(new_track : BaseTrack):
	track = new_track


func set_num_networks(n : int):
	num_networks = n
	if is_node_ready() and not Engine.is_editor_hint():
		__update_car_count()


func on_network_score_changed(score : float):
	highscore_mutex.lock()
	if score > highest_score:
		highest_score = score
	highscore_mutex.unlock()


func on_new_generation_populated(_server_message: Dictionary) -> void:
	new_generation.emit()


func reset_neural_cars():
	#highest_score = -INF
	#print(cars.map(func(x): return x.get_score()).max())
	if not track: return
	
	var car_index : int = batch_start_index
	active_cars.clear()
	
	for c : NeuralCar in cars:
		var network_id = network_ids[car_index]
		c.id = network_id
		active_cars[str(network_id)] = c
		c.reset(track.spawn_point)
		car_index += 1
	
	reset_active_count()
	
	reset.emit()


func update_network_ids(server_msg : Dictionary):
	network_ids = server_msg["payload"]["networkIDs"]


func free_neural_cars():
	if cars.size() > 0:
		for c : NeuralCar in cars:
			if c: c.queue_free()
		cars = []


func _on_api_client_connected() -> void:
	if not api_configured:
		var response := api_client.setup_session(num_networks, parent_selection, load_networks() if load_saved_networks else [])
		if not response.is_empty():
			update_network_ids(response)
			on_server_configured()
	api_connected = true



func save_networks(n : int):
	var response := api_client.get_best_networks(n)
	var networks : Array = response["payload"]["networks"]
	var save_file = FileAccess.open("user://saved_networks.json", FileAccess.WRITE)
	save_file.store_string(JSON.stringify(networks))
	save_file.close()


func load_networks() -> Array:
	var save_file = FileAccess.open("user://saved_networks.json", FileAccess.READ)
	var file_contents = save_file.get_as_text()
	save_file.close()
	if save_file.get_error() != OK: return []
	var networks : Array = JSON.parse_string(file_contents)
	return networks


func _on_api_client_disconnected() -> void:
	api_connected = false
	set_process(false)
	timer.stop()


func _on_api_client_connection_error() -> void:
	_on_api_client_disconnected()



func on_server_configured() -> void:
	api_configured = true
	if not enabled: return
	
	reset.emit()
	reset_neural_cars()
	set_process(true)
	timer.start()


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
	timer.stop()
	start_next_batch()


func set_api_client(client : NeuralAPIClient):
	if api_client and not Engine.is_editor_hint():
		api_client.io_handler.connected.disconnect(_on_api_client_connected)
		api_client.io_handler.disconnected.disconnect(_on_api_client_disconnected)
		api_client.io_handler.connection_error.disconnect(_on_api_client_connection_error)
	
	api_client = client
	
	if api_client:
		api_client.io_handler.connected.connect(_on_api_client_connected, CONNECT_DEFERRED)
		api_client.io_handler.disconnected.connect(_on_api_client_disconnected, CONNECT_DEFERRED)
		api_client.io_handler.connection_error.connect(_on_api_client_connection_error, CONNECT_DEFERRED)
	
	update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings : PackedStringArray = []
	
	if not api_client:
		warnings.append("NeuralCarManager requires a NeuralAPIClient.")
	
	return warnings
