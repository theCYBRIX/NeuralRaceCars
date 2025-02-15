@tool
class_name NetworkLayoutGenerator
extends Node

signal layout_changed

@export_group("Network Layout")
@export_range(1, 100) var num_inputs : int : set = set_num_inputs
@export_range(1, 100) var num_outputs : int : set = set_num_outputs
@export var hidden_layer_sizes : Array[int] : set = set_hidden_layer_sizes
@export var activation_functions : Array[NetworkLayer.ActivationFunction] = [NetworkLayer.ActivationFunction.LINEAR, NetworkLayer.ActivationFunction.LINEAR] : set = set_activation_functions
@export var input_normalizers : Array[NetworkLayer.InputNormalizer] = [NetworkLayer.InputNormalizer.BATCH, NetworkLayer.InputNormalizer.NONE] : set = set_input_normalizers

@export_group("Default Behaviour")
@export var use_default_behaviour := false
@export_subgroup("Input Layer", "default_input_")
@export var default_input_activation_function : NetworkLayer.ActivationFunction = NetworkLayer.ActivationFunction.LINEAR
@export var default_input_normalizer : NetworkLayer.InputNormalizer = NetworkLayer.InputNormalizer.BATCH
@export_subgroup("Hidden Layer", "default_hidden_")
@export var default_hidden_activation_function : NetworkLayer.ActivationFunction = NetworkLayer.ActivationFunction.ReLU
@export var default_hidden_normalizer : NetworkLayer.InputNormalizer = NetworkLayer.InputNormalizer.NONE
@export_subgroup("Output Layer", "default_output_")
@export var default_output_activation_function : NetworkLayer.ActivationFunction = NetworkLayer.ActivationFunction.SIGMOID
@export var default_output_normalizer : NetworkLayer.InputNormalizer = NetworkLayer.InputNormalizer.NONE


# Layout JSON format example:
#{
#	"inputs":{"nodes": num_inputs,"activationFunction":"LINEAR","inputNormalizer":"BATCH"},
#	"outputs":{"nodes":3,"activationFunction":"LINEAR","inputNormalizer":"NONE"},
#	"hiddenLayers":[{"nodes":8,"activationFunction":"TANH","inputNormalizer":"NONE"}]
#}

func create_network_layout() -> NetworkLayout:
	var hidden_layers : Array[NetworkLayer]
	
	hidden_layers.resize(hidden_layer_sizes.size())
	for i in range(hidden_layer_sizes.size()):
		hidden_layers[i] = NetworkLayer.new(hidden_layer_sizes[i], activation_functions[i + 1], input_normalizers[i + 1])
	
	return NetworkLayout.new(
		NetworkLayer.new(num_inputs, activation_functions[0], input_normalizers[0]),
		hidden_layers,
		NetworkLayer.new(num_outputs, activation_functions[hidden_layer_sizes.size() + 1], input_normalizers[hidden_layer_sizes.size() + 1])
	)



func set_hidden_layer_sizes(sizes : Array[int]) -> void:
	if Engine.is_editor_hint():
		hidden_layer_sizes = sizes
	elif not sizes:
		hidden_layer_sizes.clear()
	else:
		if not is_valid_layer_sizes_array(sizes):
			push_error("Hidden layer sizes array contained a value <= 0. No changes were made to the original array.")
			return
		hidden_layer_sizes = sizes 
	if use_default_behaviour:
		populate_defaults()
	update_configuration_warnings()
	layout_changed.emit()


func is_valid_layer_sizes_array(sizes : Array[int]) -> bool:
	if sizes:
		for node_count in sizes:
			if node_count <= 0:
				return false
	return true


func set_activation_functions(functions : Array[NetworkLayer.ActivationFunction]):
	if Engine.is_editor_hint():
		activation_functions = functions
	elif not functions:
		activation_functions.clear()
	else:
		activation_functions = functions
	update_configuration_warnings()
	layout_changed.emit()


func set_input_normalizers(normalizers : Array[NetworkLayer.InputNormalizer]):
	if Engine.is_editor_hint():
		input_normalizers = normalizers
	elif not normalizers:
		input_normalizers.clear()
	else:
		input_normalizers = normalizers 
	update_configuration_warnings()
	layout_changed.emit()


func set_num_inputs(inputs : int) -> void:
	inputs = clampi(inputs, 1, 100)
	if inputs == num_inputs: return
	num_inputs = inputs
	layout_changed.emit()


func set_num_outputs(outputs : int) -> void:
	outputs = clampi(outputs, 1, 100)
	if outputs == num_outputs: return
	num_outputs = outputs
	layout_changed.emit()


func populate_defaults():
	_populate_default_activation_functions()
	_populate_default_input_normalizers()


func _populate_default_activation_functions():
	activation_functions.clear()
	activation_functions.resize(hidden_layer_sizes.size() + 2)
	activation_functions[0] = default_input_activation_function
	activation_functions[activation_functions.size() - 1] = default_output_activation_function
	for i in range(1, activation_functions.size() - 1):
		activation_functions[i] = default_hidden_activation_function


func _populate_default_input_normalizers():
	input_normalizers.clear()
	input_normalizers.resize(hidden_layer_sizes.size() + 2)
	input_normalizers[0] = default_input_normalizer
	input_normalizers[input_normalizers.size() - 1] = default_output_normalizer
	for i in range(1, input_normalizers.size() - 1):
		input_normalizers[i] = default_hidden_normalizer


func _get_configuration_warnings() -> PackedStringArray:
	var warnings : PackedStringArray = []
	
	var bad_layers : Array[int] = _get_bad_layers()
	if bad_layers.size() > 0:
		var w : String = "Network Layer size must be greater than zero. (Check hidden layers: " + str(bad_layers[0])
		for i in range(1, bad_layers.size()):
			w += ", %d" % bad_layers[i]
		warnings.append(w + ")")
	
	var num_layers = hidden_layer_sizes.size() + 2
	
	if activation_functions.size() != num_layers:
		warnings.append(_needed_for_every_layer("activation function", activation_functions.size(), num_layers))
	if input_normalizers.size() != num_layers:
		warnings.append(_needed_for_every_layer("input normalizer", activation_functions.size(), num_layers))
		
	return warnings

func _get_bad_layers() -> Array[int]:
	var bad_layers : Array[int] = []
	for i in range(hidden_layer_sizes.size()):
		if hidden_layer_sizes[i] <= 0:
			bad_layers.append(i)
	return bad_layers


static func _needed_for_every_layer(long_name : String, present : int, needed : int) -> String:
	var suffix : String
	if present < needed:
		suffix = "(%d missing)" % (needed - present)
	else:
		suffix = "(%d too many)" % (present - needed)
	return "Network Layout must have one %s for every layer. %s" % [long_name, suffix]
