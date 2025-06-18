@tool

class_name NeuralAPIClient
extends Node

signal connected
signal disconnected
signal connection_error(error : Error)
signal network_ids_updated(Array)

@export var io_handler : IOHandler : set = set_io_handler
@export var binary_io_handler : Node
@export var layout_generator : NetworkLayoutGenerator : set = set_layout_generator
@export var print_error_stack_trace := true
@export var track_response_times := true : set = set_track_response_times
@export var response_time_samples : int = 5

enum ParentSelection {
	ROULETTE_WHEEL_PREFER_LARGE,
	ROULETTE_WHEEL_PREFER_SMALL,
	TOURNAMENT_PREFER_LARGE,
	TOURNAMENT_PREFER_SMALL,
	ELITES_PREFER_LARGE,
	ELITES_PREFER_SMALL
}


var error_flag : bool = false
var simulation_network_ids : Array : set = set_simulation_network_ids
var training_network_ids : Array : set = set_training_network_ids

var _api_connected : bool = false : get = is_api_connected
var _response_timer : AbsoluteTimer = AbsoluteTimer.new()
var _response_times : Array[float] = []
var _request_callable : Callable = _request_timed

func _ready() -> void:
	if Engine.is_editor_hint():
		return


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if binary_io_handler and binary_io_handler.IsConnected():
		binary_io_handler.Disconnect()


func update_car_inputs(cars : Array[NeuralCar], batch_size : int = cars.size()):
	var outputs := {}
	var process_queue : Array[Array] = []
	var batch_start_index : int = 0
	var outputs_mutex := Mutex.new()
	var io_write_semaphore := Semaphore.new()
	var io_read_semaphore := Semaphore.new()
	
	var num_tasks : int = 1
	var tasks : Array[ProcessTask] = []
	var additional_tasks_needed : int = num_tasks
	
	if batch_size < cars.size() and (batch_size * 2) > cars.size():
		batch_size = roundi(batch_size / 2.0)
	
	io_write_semaphore.post()
	io_read_semaphore.post()
	while batch_start_index < cars.size() or not tasks.is_empty() or not process_queue.is_empty():
		if batch_start_index < cars.size():
			var batch_end_index := mini(batch_start_index + batch_size, cars.size())
			var car_batch := cars.slice(batch_start_index, batch_end_index)
			batch_start_index = batch_end_index
			
			var inputs = _get_network_inputs(car_batch)
			var task_id = WorkerThreadPool.add_task(_process_inputs_threaded.bind(inputs, outputs, io_write_semaphore, io_read_semaphore, outputs_mutex))
			tasks.append(ProcessTask.new(task_id, car_batch))
			
			additional_tasks_needed -= 1
			if additional_tasks_needed > 0:
				continue
		
		while process_queue.is_empty():
			var index : int = 0
			while index < tasks.size():
				if not tasks[index].try_wait():
					index += 1
				else:
					var task : ProcessTask = tasks.pop_at(index)
					var error := task.wait()
					additional_tasks_needed += 1
					if error == OK:
						process_queue.append(task.cars)
					else:
						push_warning("Error when processing a batch: ", error_string(error))
						outputs_mutex.lock()
						process_queue.append(task.cars.filter(func(x): outputs.has(str(x.id))))
						outputs_mutex.unlock()
		
		outputs_mutex.lock()
		for car : NeuralCar in process_queue.pop_front():
			var id := str(car.id)
			if not outputs.has(id):
				continue
			car.interpret_model_outputs(outputs[id])
		outputs_mutex.unlock()
	
	for t in tasks:
		t.wait()
	


func start() -> void:
	if io_handler:
		io_handler.start()
	else:
		push_error("Unable to start: IOHandler is null.")


func _process_inputs_threaded(inputs : Dictionary, outputs : Dictionary, io_write_semaphore : Semaphore, io_read_semaphore : Semaphore, outputs_update_mutex : Mutex):
	io_write_semaphore.wait()
	_send_request("processInputs", { "networkInputs" : inputs })
	io_read_semaphore.wait()
	io_write_semaphore.post()
	var response := _read_response()
	io_read_semaphore.post()
	
	var out : Dictionary
	if response.has("payload") and response.payload.has("networkOutputs"):
		out = response.payload.networkOutputs
	else:
		out = {}
	
	outputs_update_mutex.lock()
	outputs.merge(out, true)
	outputs_update_mutex.unlock()


func _get_network_inputs(cars : Array[NeuralCar]) -> Dictionary:
	var inputs : Dictionary = {}
	
	for c : NeuralCar in cars:
		var data := c.get_network_inputs()
		inputs[str(c.id)] = data
	
	return inputs


func populate_new_generation(network_scores : Dictionary) -> Error:
	var response := request("createNewGeneration", { "networkScores" : network_scores })
	if not error_flag:
		training_network_ids = _get_network_ids(response)
	
	return FAILED if error_flag else OK


func populate_random_generation() -> Error:
	
	#NOTE: Randomizes existing networks and leaves their IDs unchanged
	request("randomizeNetworks")
	
	return FAILED if error_flag else OK


func add_networks(networks : Array) -> Error:
	var response := request("addNetworks", { "networks" : networks })
	if error_flag: return FAILED
	simulation_network_ids.append_array(response["payload"]["networkIds"])
	return OK


func setup_session(num_networks : int, parent_selector : ParentSelection, initial_networks : Array) -> Error:
	var payload : Dictionary = {}
	var network_layout : Dictionary
	
	var network_count := num_networks
	var parent_selection = ParentSelection.keys()[parent_selector]
	
	if not initial_networks or initial_networks.is_empty():
		network_layout = layout_generator.create_network_layout().to_dict()
	else:
		network_layout = initial_networks.front()["layout"]
		payload["initialNetworks"] = initial_networks
	
	payload["layout"] = network_layout
	payload["numNetworks"] = network_count
	payload["parentSelector"] = parent_selection
	payload["createMetadata"] = true
	
	var response : Dictionary = request("setup", payload)
	
	if not error_flag:
		training_network_ids = _get_network_ids(response)
	
	return FAILED if error_flag else OK


func get_network_metadata(network_ids : Array[int] = []) -> Dictionary:
	var response := request("getMetadata") if network_ids.is_empty() else request("getMetadata", { "networkIds" : network_ids})
	if error_flag or not response.has("payload") or not response.payload.has("metadata"): return {}
	return response.payload.metadata


func setup_training_session():
	pass


func set_layout_generator(generator : NetworkLayoutGenerator):
	layout_generator = generator
	update_configuration_warnings()


func set_io_handler(handler : IOHandler):
	if io_handler and not Engine.is_editor_hint():
		Util.disconnect_from_signal(_on_io_handler_connected, io_handler.connected)
		Util.disconnect_from_signal(_on_io_handler_disconnected, io_handler.disconnected)
		Util.disconnect_from_signal(_on_io_handler_connection_error, io_handler.connection_error)
	
	io_handler = handler
	
	if io_handler and not Engine.is_editor_hint():
		io_handler.connected.connect(_on_io_handler_connected, CONNECT_DEFERRED)
		io_handler.disconnected.connect(_on_io_handler_disconnected, CONNECT_DEFERRED)
		io_handler.connection_error.connect(_on_io_handler_connection_error, CONNECT_DEFERRED)
		if io_handler.is_running():
			_on_io_handler_connected()
	
	
	update_configuration_warnings()


func get_network_outputs(network_inputs : Dictionary) -> Dictionary:
	if binary_io_handler and binary_io_handler.Enabled and binary_io_handler.IsConnected():
		#binary_io_handler.Test()
		return binary_io_handler.ProcessInputs(network_inputs)
	
	var response := request("processInputs", { "networkInputs" : network_inputs })
	var outputs : Dictionary
	
	if response.has("payload") and response.payload.has("networkOutputs"):
		outputs = response.payload.networkOutputs
	else:
		outputs = {}
	
	return outputs


func get_best_networks(num_networks : int) -> Array:
	var response := request("getBestNetworks", { "numRequested" : num_networks})
	if error_flag: return []
	var networks : Array = response["payload"]["networks"]
	return networks


func get_networks(ids : Array[int]) -> Dictionary:
	var response := request("getNetworks", { "networkIds" : ids})
	if error_flag: return {}
	var networks : Dictionary = response["payload"]["networks"]
	return networks


func train_on_dataset(dataset : DrivingData):
	request("trainOnDataset", { "dataset" : { "inputs" : dataset.inputs, "outputs" : dataset.outputs }})


func get_training_status() -> Dictionary:
	return request("getTrainingState")


func stop_training():
	request("stopTraining")


@warning_ignore("shadowed_variable")
func _send_request(request : String, payload : Dictionary = {}) -> void:
	var packet : Dictionary = {
		"request" : request,
	}
	
	if not payload.is_empty():
		packet["payload"] = payload
	
	io_handler.write(JSON.stringify(packet, "", true, true))


func _read_response() -> Dictionary:
	return parse_message(io_handler.read())


@warning_ignore("shadowed_variable")
func request(request : String, payload : Dictionary = {}) -> Dictionary:
	return _request_callable.call(request, payload)


@warning_ignore("shadowed_variable")
func _request_direct(request : String, payload : Dictionary = {}) -> Dictionary:
	_send_request(request, payload)
	return _read_response()

@warning_ignore("shadowed_variable")
func _request_timed(request : String, payload : Dictionary = {}) -> Dictionary:
	_response_timer.start()
	_send_request(request, payload)
	var response := _read_response()
	_response_timer.stop()
	if _response_times.size() == response_time_samples:
		_response_times.pop_front()
	_response_times.append(_response_timer.get_elapsed_time_millis())
	return response



func get_last_response_time() -> float:
	if _response_times.is_empty():
		return 0
	else:
		return _response_times.back()


func get_average_response_time() -> float:
	if _response_times.is_empty():
		return 0
	
	var cumulative_time := 0.0
	for time in _response_times:
		cumulative_time += time
	
	return cumulative_time / _response_times.size()


func parse_message(server_msg : String) -> Dictionary:
	var parser := JSON.new()
	var parse_error := parser.parse(server_msg)
	var response : Dictionary
	
	if parser.data:
		response = parser.data

	if parse_error != OK or (not response) or (response["status"] == "error"):
		var error : String
	
		if parse_error != OK:
			error = "Error on line %d when parsing server response. Error: %s" % [parser.get_error_line(), parser.get_error_message()]
		
		elif not response:
			error = "Parser returned null.\n Response was:\"%s\"" % server_msg
		
		elif response.has("payload"):
			var response_payload : Dictionary = response["payload"]
			error = response_payload["message"] if response_payload.has("message") else "Server Error"
			if response_payload.has("details"): error += " " + str(response_payload["details"])
			if print_error_stack_trace and response_payload.has("stackTrace"): error += "\n" + str(response_payload["stackTrace"])
		
		push_error(error)
		printerr(error)
		
		error_flag = true
	else:
		error_flag = false
	
	return response



func error_occurred() -> bool:
	return error_flag


func set_simulation_network_ids(ids : Array):
	simulation_network_ids = ids
	network_ids_updated.emit()


func set_training_network_ids(ids : Array):
	training_network_ids = ids
	network_ids_updated.emit()


func set_track_response_times(enabled : bool) -> void:
	if track_response_times == enabled:
		return
	track_response_times = enabled
	_response_times.clear()
	_request_callable = _request_timed if track_response_times else _request_direct


func is_api_connected() -> bool:
	return _api_connected


func _get_network_ids(server_msg : Dictionary) -> Array:
	return server_msg["payload"]["networkIds"]


func _get_configuration_warnings() -> PackedStringArray:
	var warnings : PackedStringArray = []
	
	if not layout_generator:
		warnings.append("No NetworkLayoutGenerator has been set.")
	elif not (layout_generator is NetworkLayoutGenerator):
		warnings.append("NetworkLayoutGenerator is not valid.")
	
	if not io_handler:
		warnings.append("No IOHandler has been set.")
	elif not (io_handler is IOHandler):
		warnings.append("IOHandler is not valid.")
	
	return warnings


func _on_io_handler_connected() -> void:
	_api_connected = true
	connected.emit()
	
	if binary_io_handler and binary_io_handler.Enabled:
		request("openBinaryChannel")
		if not error_flag:
			binary_io_handler.Start()
		else:
			push_error("Failed to open binary channel.")


func _on_io_handler_disconnected() -> void:
	_api_connected = false
	disconnected.emit()


func _on_io_handler_connection_error(error : Error) -> void:
	_api_connected = false
	connection_error.emit(error)


class ProcessTask:
	var id : int
	var need_wait : bool = true
	var cars : Array[NeuralCar]
	
	func _init(task_id : int, task_cars : Array[NeuralCar]) -> void:
		id = task_id
		cars = task_cars
	
	func try_wait() -> bool:
		return need_wait or WorkerThreadPool.is_task_completed(id)
	
	func wait() -> Error:
		if not need_wait:
			return ERR_DOES_NOT_EXIST
		need_wait = false
		return WorkerThreadPool.wait_for_task_completion(id)
