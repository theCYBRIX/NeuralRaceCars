@tool

class_name NeuralAPIClient
extends Node

const EMPTY_PATH := NodePath()

@export var io_handler : IOHandler
var io_mutex : Mutex = Mutex.new()

var layout_generator_path : NodePath = EMPTY_PATH : set = set_layout_generator_path


enum ParentSelection {
	ROULETTE_WHEEL_PREFER_LARGE,
	ROULETTE_WHEEL_PREFER_SMALL,
	TOURNAMENT_PREFER_LARGE,
	TOURNAMENT_PREFER_SMALL,
	ELITES_PREFER_LARGE,
	ELITES_PREFER_SMALL
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	__refresh_first_layout_generator()



func populate_new_generation(network_scores : Dictionary) -> Dictionary:
	send_request("create_new_generation", { "networkScores" : network_scores })
	var response : Dictionary = read()
	return response


func setup_session(num_networks : int, parent_selector : ParentSelection, initial_networks : Array) -> Dictionary:
	
	var network_layout : Dictionary = get_node(layout_generator_path).create_network_layout().to_dict()
	var network_count := num_networks
	var parent_selection = ParentSelection.keys()[parent_selector]
		
	var payload : Dictionary = {}
	payload["layout"] = network_layout
	payload["numNetworks"] = network_count
	payload["parentSelector"] = ParentSelection.keys()[parent_selector]
	if initial_networks: payload["initialNetworks"] = initial_networks
	send_request("setup", payload)
	var response : Dictionary = read()
	
	return response; 


func set_layout_generator_path(path : NodePath):
	layout_generator_path = path
	update_configuration_warnings()

func get_network_outputs(network_inputs : Dictionary) -> Dictionary:
	send_request("process_inputs", { "networkInputs" : network_inputs })
	var outputs : Dictionary = read()
	return outputs


func get_best_networks(num_networks : int) -> Dictionary:
	send_request("get_best_networks", { "numRequested" : num_networks})
	var networks : Dictionary = read()
	return networks


func train_on_dataset(dataset : DrivingData):
	send_request("train_on_dataset", { "inputs" : dataset.inputs, "outputs" : dataset.outputs })
	read()


func get_training_status() -> Dictionary:
	send_request("get_training_state")
	return read()


func stop_training():
	send_request("stop_training")
	read()


func send_request(request : String, payload : Dictionary = {}) -> void:
	var packet : Dictionary = {
		"request" : request,
	}
	
	if not payload.is_empty():
		packet["payload"] = payload
	
	io_mutex.lock()
	io_handler.write(JSON.stringify(packet, "", true, true))
	io_mutex.unlock()


func send(data : Dictionary) -> void:
	io_mutex.lock()
	io_handler.write(JSON.stringify(data, "", true, true))
	io_mutex.unlock()


func read() -> Dictionary:
	io_mutex.lock()
	var raw_response : String = io_handler.read()
	raw_response = raw_response.replace("NaN", "-1")
	var response : Dictionary = JSON.parse_string(raw_response)

	if is_error(response):
		var error : String
		if response.has("payload"):
			var payload : Dictionary = response["payload"]
			error = payload["message"] if payload.has("message") else "Server Error"
			if payload.has("details"): error += " " + payload["details"]
		push_error(error)
		printerr(error)
		response = {}
	
	io_mutex.unlock()
	return response


func is_error(message : Dictionary) -> bool:
	return (message["status"] == "error")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_CHILD_ORDER_CHANGED:
			if is_inside_tree() and is_node_ready():
				__refresh_first_layout_generator()


func __refresh_first_layout_generator():
	var layout_generator = null if layout_generator_path.is_empty() else get_node_or_null(layout_generator_path)
	var current_index = layout_generator.get_index() if layout_generator else INF
	for node in get_children():
		if node is NetworkLayoutGenerator:
			var node_index := node.get_index()
			if node_index < current_index:
				layout_generator_path = node.get_path()
				current_index = node_index
			break
	if is_inf(current_index):
		layout_generator_path = EMPTY_PATH


func _get_configuration_warnings() -> PackedStringArray:
	var warnings : PackedStringArray = []
	
	if layout_generator_path.is_empty():
		warnings.append("NeuralAPIClient requires a NetworkLayoutGenerator child.")
	
	return warnings
