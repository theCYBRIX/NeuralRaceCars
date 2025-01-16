extends Node

@onready var neural_api_client: NeuralAPIClient = $NeuralAPIClient

var network_ids : Array
var network_count_array : Array[int] = [5, 10, 25, 50, 75, 100, 200, 300, 400, 500]
var num_iterations : int = 200
var _session_configured := false
var _test_sequence_running := false

func _ready() -> void:
	pass



func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_SPACE:
			if event.is_pressed():
				if _session_configured:
					if not _test_sequence_running:
						batching_test()
				elif not event.is_echo():
					var error := setup_session()
					if error != OK or neural_api_client.error_occurred():
						push_error("Failed to setup session: ", error_string(error))
					else:
						print("Setup session successfully.")
						_session_configured = true
						batching_test()


func setup_session() -> Error:
	var path = "C:\\Users\\math_\\AppData\\Roaming\\Godot\\app_userdata\\CarGame"
	var folder := DirAccess.open(path)
	if not folder: return DirAccess.get_open_error()
	
	var files : Array[String] = []
	files.append_array(folder.get_files())
	files = files.filter(SaveManager.can_load_file)
	
	var max_network_count : int = network_count_array.max()
	var file_index : int = -1
	
	while network_ids.size() < max_network_count:
		file_index += 1
		network_ids.append_array(load_networks(path + "\\" + files[file_index]))
		var error := SaveManager.get_load_error()
		if error != OK:
			print("Error occurred when loading file %s: " + error_string(error))
			return error
	
	return OK


func batching_test():
	var total_network_count : int = network_count_array.max()
	var timer := AbsoluteTimer.new() 
	for batch_size in network_count_array:
		print("\nStarting test with %d networks computing in batches of %d for %d iterations." % [total_network_count, batch_size, num_iterations])
		timer.start()
		for i in range(num_iterations):
			var id_index = 0
			while id_index < total_network_count:
				var inputs := get_random_inputs(network_ids.slice(id_index, min(id_index + batch_size, network_ids.size())))
				process_inputs(inputs)
				id_index += batch_size
		timer.stop()
		print("Average execution time: ", format_elapsed_time(timer.get_elapsed_time_micro() / num_iterations))


func get_endpoints() -> Dictionary:
	return neural_api_client.request("endpoints")


func print_endpoints(response : Dictionary = get_endpoints()):
	if response.has("payload"):
		response = response.payload
	
	print(JSON.stringify(response, "\t"))


func load_networks(file_path : String) -> Array:
	var save_file = SaveManager.load_training_state(file_path)
	var networks = save_file.networks
	var response := neural_api_client.request("addNetworks", { "networks" : networks })
	return response["payload"]["networkIds"]


func process_inputs(inputs : Dictionary) -> Dictionary:
	return neural_api_client.request("processInputs", inputs)


func get_inputs(num_networks : int) -> Dictionary:
	var ids := network_ids.duplicate()
	ids.shuffle()
	ids = ids.slice(0, num_networks)
	return get_random_inputs(ids)


func get_random_inputs(ids : Array) -> Dictionary:
	var input_map := {}
	for id in ids:
		var inputs := PackedFloat32Array()
		inputs.resize(15)
		for index in range(inputs.size()):
			inputs[index] = randf_range(-1, 1)
		input_map[id] = inputs
	return { "networkInputs" : input_map }


func run_test_sequence():
	_test_sequence_running = true
	for i in range(network_count_array.size()):
		var num_networks := network_count_array[i] 
		if i <= network_ids.size():
			print("\nStarting test with %d networks computing for %d iterations." % [num_networks, num_iterations])
			run_test(num_networks, num_iterations)
		else:
			push_warning("Network count %d is greater than total number of networks (%d)" % [i, network_ids.size()])
	_test_sequence_running = false


func run_test(network_count : int, num_iterations : int):
	var iteration : int = 0
	var total_elapsed_time : float = 0.0
	while iteration < num_iterations:
		var inputs = get_inputs(network_count)
		var time_taken := measure_function_time(inputs)
		total_elapsed_time += time_taken
		iteration += 1
	print(
		"Function execution time: %s\nAverage: %s" % [
			format_elapsed_time(total_elapsed_time),
			format_elapsed_time(total_elapsed_time / num_iterations)
		]
	)



func measure_function_time(data) -> int:
	
	# Get the starting time in microseconds
	var start_time := Time.get_ticks_usec()
	
	# Call the function you want to measure
	process_inputs(data)
	
	# Get the ending time in microseconds
	var end_time = Time.get_ticks_usec()
	
	# Calculate the elapsed time in seconds
	var elapsed_time_micro : float = float(end_time) - float(start_time)
	return elapsed_time_micro


func format_elapsed_time(elapsed_time_micro : float) -> String:
	var elapsed_time_millis := elapsed_time_micro / 1_000.0
	var elapsed_time_sec := elapsed_time_micro / 1_000_000.0
	
	# Print or return the elapsed time
	return "%fms (%f seconds)" % [elapsed_time_millis, elapsed_time_sec]


class AbsoluteTimer:
	var start_time : int
	var end_time : int
	var elapsed_time : int
	
	func start() -> void:
		start_time = Time.get_ticks_usec()
	
	func stop() -> void:
		end_time = Time.get_ticks_usec()
		elapsed_time = end_time - start_time
	
	func get_elapsed_time_micro() -> int:
		return elapsed_time
	
	func get_elapsed_time_millis() -> int:
		return elapsed_time / 1_000.0
	
	func get_elapsed_time_sec() -> int:
		return elapsed_time / 1_000_000.0
