@tool

class_name NeuralAPIClient
extends Node

const EMPTY_PATH := NodePath()

@export var io_handler : IOHandler
@export var print_error_stack_trace := true
var error_flag : bool = false

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
	return await request("create_new_generation", { "networkScores" : network_scores })


func populate_random_generation() -> Dictionary:
	return await request("randomize_networks")


func setup_session(num_networks : int, parent_selector : ParentSelection, initial_networks : Array) -> Dictionary:
	
	var network_layout : Dictionary = get_node(layout_generator_path).create_network_layout().to_dict()
	var network_count := num_networks
	var parent_selection = ParentSelection.keys()[parent_selector]
		
	var payload : Dictionary = {}
	payload["layout"] = network_layout
	payload["numNetworks"] = network_count
	payload["parentSelector"] = ParentSelection.keys()[parent_selector]
	if initial_networks: payload["initialNetworks"] = initial_networks
	
	var response : Dictionary = await request("setup", payload)
	
	return response; 


func set_layout_generator_path(path : NodePath):
	layout_generator_path = path
	update_configuration_warnings()

func get_network_outputs(network_inputs : Dictionary) -> Dictionary:
	return await request("process_inputs", { "networkInputs" : network_inputs })


func get_best_networks(num_networks : int) -> Dictionary:
	return await request("get_best_networks", { "numRequested" : num_networks})


func train_on_dataset(dataset : DrivingData):
	request("train_on_dataset", { "inputs" : dataset.inputs, "outputs" : dataset.outputs })


func get_training_status() -> Dictionary:
	return await request("get_training_state")


func stop_training():
	request("stop_training")


func request(request : String, payload : Dictionary = {}) -> Dictionary:
	var packet : Dictionary = {
		"request" : request,
	}
	
	if not payload.is_empty():
		packet["payload"] = payload
	
	var raw_response : String = await io_handler.query(JSON.stringify(packet, "", true, true)) #Sending and recieving
	raw_response = raw_response.replace("NaN", "0")
	var response : Dictionary = JSON.parse_string(raw_response)

	if not response or (response["status"] == "error"):
		var error : String
		
		if not response:
			error = "Failed to parse response.\n Response was:\"%s\"" % raw_response
		
		elif response.has("payload"):
			var response_payload : Dictionary = response["payload"]
			error = response_payload["message"] if response_payload.has("message") else "Server Error"
			if response_payload.has("details"): error += " " + response_payload["details"]
			if print_error_stack_trace and response_payload.has("stackTrace"): error += "\n" + response_payload["stackTrace"]
		#print(payload["networkScores"])
		push_error(error)
		printerr(error)
		
		error_flag = true
	else:
		error_flag = false
	
	return response


func error_occurred() -> bool:
	return error_flag


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
