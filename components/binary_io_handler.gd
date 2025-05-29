class_name BinaryIOHandlerGD
extends ServerIOHandler

const PROCESS_INPUTS_ENDPOINT : int = 2

func put_doubles(array : Array[float]) -> void:
	for value : float in array:
		socket.put_double(value)


func put_inputs(network_id : int, doubles : Array[float]) -> void:
	socket.put_32(network_id)
	socket.put_32(doubles.size())
	put_doubles(doubles)


func process_inputs(inputs : Dictionary) -> Dictionary[String, PackedFloat64Array]:
	socket.put_32(PROCESS_INPUTS_ENDPOINT)
	socket.put_32(inputs.size())
	for network_id in inputs.keys():
		put_inputs(int(network_id), inputs[network_id])
	
	var outputs : Dictionary[String, PackedFloat64Array] = {}
	
	var error : int = socket.get_32()
	if error != OK:
		push_error("Binary IO Channel returned error code: %d" %[error])
		return outputs
	
	var num_networks := socket.get_32()
	if num_networks != inputs.size():
		push_error("Num networks changed %d -> %d" % [num_networks, inputs.size()])
	for idx in range(num_networks):
		var network_id = socket.get_32()
		var num_outputs = socket.get_32()
		var output_array : PackedFloat64Array = []
		output_array.resize(num_outputs)
		for output_idx in range(num_outputs):
			output_array[output_idx] = socket.get_double()
		outputs[str(network_id)] = output_array
	
	return outputs
