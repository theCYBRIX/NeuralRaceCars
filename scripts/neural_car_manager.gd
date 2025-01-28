@tool
class_name NeuralCarManager
extends Node

signal instanciated(car : NeuralCar)
signal freed(car : NeuralCar)

signal car_respawned(car : NeuralCar)
signal car_deactivated(car : NeuralCar)

signal track_ready(track : BaseTrack)


const INPUT_THRESH : float = 0.5



@export var car_parent: Node = self as Node: set = set_car_parent
@export var track_provider : TrackProvider = null : set = set_track_provider
@export var deactivate_on_contact := true : set = set_deactivate_on_contact

@export var enabled : bool = true

@export_range(0, Util.INT_32_MAX_VALUE) var num_cars : int : set = set_num_cars

@export_group("Autoload")
@export var load_saved_networks : bool = false
@export_global_file("*.json") var network_load_path := SaveManager.DEFAULT_SAVE_FILE_PATH

var track : BaseTrack : set = set_track

var cars : Array[NeuralCar] = []
var active_cars : Dictionary = {}
var inactive_cars : Array[NeuralCar] = []

var network_outputs : Array[Array]

var api_connected : bool = false

var ignore_deactivations := false

var _api_client : NeuralAPIClient : set = set_api_client
var _neural_car_scene : PackedScene = preload("res://scenes/neural_car.tscn")



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(false)
	
	if not car_parent:
		car_parent = self
	
	if Engine.is_editor_hint():
		update_configuration_warnings()
		return
	
	process_physics_priority = -1
	
	if enabled and track:
		_update_car_count()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	if active_cars.is_empty(): return
	
	var network_inputs : Dictionary = get_network_inputs()
	var response : Dictionary = get_network_outputs(network_inputs)
	
	if _api_client.error_occurred(): return
	
	response.make_read_only()
	set_neural_car_inputs(response)
	#for id in response.keys():
		#var str_id = str(id)
		#var c : NeuralCar = active_cars[str_id]
		#var outputs : Array = response[str_id]
		#c.interpret_model_outputs(outputs)
	
	#var cars_to_update : Array[NeuralCar] = []
	#cars_to_update.append_array(active_cars.values())
	#_api_client.update_car_inputs(cars_to_update, 16)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PARENTED:
			if not _api_client:
				var parent = get_parent()
				if parent is NeuralAPIClient:
					_api_client = parent
				else:
					_api_client = null
		NOTIFICATION_UNPARENTED:
			_api_client = null


func _update_car_count():
	if not track: return
	
	var num_cars_needed = num_cars
	if cars.size() > 0:
		num_cars_needed -= cars.size()
		if num_cars_needed == 0: return
		if num_cars_needed < 0:
			_remove_neural_cars(abs(num_cars_needed))
			return
	
	_add_neural_cars(num_cars_needed)


func _remove_neural_cars(count : int):
	var removed : int = 0
	while removed < count:
		var c : NeuralCar = cars.pop_back()
		c.queue_free()
		freed.emit(c)
		removed += 1


func _add_neural_cars(count : int):
	var current_car_count := cars.size()
	cars.resize(current_car_count + count)
	for i in range(current_car_count, cars.size()):
		var c : NeuralCar = _instanciate_neural_car(i)
		c.deactivate_on_contact = deactivate_on_contact
		c.deactivated.connect(_on_car_deactivated.bind(c), CONNECT_DEFERRED)
		c.respawned.connect(_on_car_respawned.bind(c), CONNECT_DEFERRED)
		car_parent.add_child(c, false, Node.INTERNAL_MODE_FRONT)
		instanciated.emit(c)


func _on_car_deactivated(car : NeuralCar):
	if _should_ignore_deactivations(): return
	set_inactive(car)
	car_deactivated.emit(car)


func set_inactive(car : NeuralCar):
	if active_cars.erase(str(car.id)):
		inactive_cars.append(car)


func _on_car_respawned(car : NeuralCar):
	car_respawned.emit(car)


func _instanciate_neural_car(index : int) -> NeuralCar:
	var c : Car = _neural_car_scene.instantiate()
	c.id = index
	c.set_name("Neural Car " + str(index))
	if track and track.is_node_ready():
		c.track_path = NodePath("../" + str(car_parent.get_path_to(track)))
	cars[index] = c
	inactive_cars.append(c)
	return c


func set_deactivate_on_contact(enabled : bool) -> void:
	deactivate_on_contact = enabled
	for car in cars:
		car.deactivate_on_contact = deactivate_on_contact


func get_network_outputs(network_inputs : Dictionary) -> Dictionary:
	var response : Dictionary = _api_client.get_network_outputs(network_inputs)
	return response


func set_neural_car_inputs(data : Dictionary) -> void:
	var group_task : int = WorkerThreadPool.add_group_task(set_neural_car_input.bind(data.keys(), data), data.size(), -1, true, "Set network inputs")
	WorkerThreadPool.wait_for_group_task_completion(group_task)

func set_neural_car_input(network_index : int, network_ids : Array, data : Dictionary):
	var id : String = network_ids[network_index]
	var c : NeuralCar = active_cars[id]
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
			c.update_sensor_data()
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


func set_track(new_track : BaseTrack):
	if track:
		Util.disconnect_from_signal(_on_track_ready, track.ready)
	
	track = new_track
	
	if not track:
		return
	
	if track.is_node_ready():
		_on_track_ready()
	else:
		track.ready.connect(_on_track_ready, CONNECT_ONE_SHOT)


func set_car_parent(node : Node):
	car_parent = node if node else self as Node


func _should_ignore_deactivations() -> bool:
	return ignore_deactivations or not track or not track.is_node_ready()


func _on_track_ready():
	
	if enabled:
		_update_car_count()
	
	if not _api_client.simulation_network_ids or _api_client.simulation_network_ids.is_empty():
		await _api_client.network_ids_updated
	
	#var idx = -1
	#for car in cars:
		#idx += 1
		#car.track_path = car.get_path_to(track)
		#reset_neural_car(_api_client.simulation_network_ids[idx], car)
	#
	#await get_tree().create_timer(0.5).timeout
	#
	#for car in cars:
		#car.active = true


func set_num_cars(n : int):
	num_cars = n
	if is_node_ready() and not Engine.is_editor_hint():
		_update_car_count()


func reset_neural_car(network_id : int, car : NeuralCar):
	car.id = network_id
	active_cars[str(network_id)] = car
	await car.reset()


func activate_neural_car(network_id : int) -> Error:
	if inactive_cars.is_empty(): return ERR_CANT_ACQUIRE_RESOURCE
	
	var car : NeuralCar = inactive_cars.pop_back()
	await reset_neural_car(network_id, car)
	
	return OK


func free_neural_cars() -> void:
	if cars.size() > 0:
		for c : NeuralCar in cars:
			if c: c.queue_free()
		cars = []


func _on_api_client_connected() -> void:
	api_connected = true


func _on_api_client_disconnected() -> void:
	api_connected = false
	set_process(false)


func _on_api_client_connection_error() -> void:
	_on_api_client_disconnected()


func _on_track_updated(new_track : BaseTrack) -> void:
	track = new_track


func set_track_provider(provider : TrackProvider) -> void:
	if track_provider and is_instance_valid(track_provider) and not Engine.is_editor_hint():
		Util.disconnect_from_signal(_on_track_updated, track_provider.track_updated)
	track_provider = provider
	
	if not Engine.is_editor_hint():
		if track_provider:
			track_provider.track_updated.connect(_on_track_updated)
			track = track_provider.track
		else:
			track = null
	update_configuration_warnings()


func deactivate_all() -> void:
	for car : NeuralCar in active_cars.values():
		car.deactivate(false)
	
	active_cars.clear()


func activate_all() -> void:
	for car : NeuralCar in cars:
		active_cars[str(car.id)] = car
		car.set_active(true)


func set_api_client(client : NeuralAPIClient):
	if _api_client and not Engine.is_editor_hint():
		Util.disconnect_from_signal(_on_api_client_connected, _api_client.connected)
		Util.disconnect_from_signal(_on_api_client_disconnected, _api_client.disconnected)
		Util.disconnect_from_signal(_on_api_client_connection_error, _api_client.connection_error)
	
	api_connected = false
	_api_client = client
	
	if _api_client and not Engine.is_editor_hint():
		_api_client.connected.connect(_on_api_client_connected, CONNECT_DEFERRED)
		_api_client.disconnected.connect(_on_api_client_disconnected, CONNECT_DEFERRED)
		_api_client.connection_error.connect(_on_api_client_connection_error, CONNECT_DEFERRED)
		if not api_connected and _api_client.is_api_connected():
			_on_api_client_connected()
	
	update_configuration_warnings()


func _connect_io_handler_signals() -> void:
	var io_handler := _api_client.io_handler
	
	


func _get_configuration_warnings() -> PackedStringArray:
	var warnings : PackedStringArray = []
	
	if not _api_client:
		warnings.append("Node must be a child of a NeuralAPIClient.")
	
	if not track_provider:
		warnings.append("No TrackProvider has been set.")
	elif not (track_provider is TrackProvider):
		warnings.append("TrackProvider path is not valid.")
	
	return warnings
