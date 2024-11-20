@tool
class_name NetworkLayoutGenerator
extends Node

@export_group("Network Layout")
@export_range(1, 100) var num_inputs : int
@export_range(1, 100) var num_outputs : int
@export var hidden_layer_sizes : Array[int] : set = set_hidden_layer_sizes
@export var activation_functions : Array[ActivationFunction] = [ActivationFunction.LINEAR, ActivationFunction.LINEAR] : set = set_activation_functions
@export var input_normalizers : Array[InputNormalizer] = [InputNormalizer.BATCH, InputNormalizer.NONE] : set = set_input_normalizers


enum ActivationFunction {
	LINEAR,
	ReLU,
	SIGMOID,
	TANH,
	SOFTMAX
}

enum InputNormalizer {
	NONE,
	BATCH,
	MIN_MAX
}


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



func set_hidden_layer_sizes(sizes : Array[int]):
	hidden_layer_sizes = sizes
	update_configuration_warnings()


func set_activation_functions(functions : Array[ActivationFunction]):
	activation_functions = functions
	update_configuration_warnings()


func set_input_normalizers(normalizers : Array[InputNormalizer]):
	input_normalizers = normalizers
	update_configuration_warnings()


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


class NetworkLayer:
	var node_count : int
	var activation : ActivationFunction
	var normalizer : InputNormalizer
	
	func _init(nodes : int, activation_function : ActivationFunction, input_normalizer : InputNormalizer ) -> void:
		self.node_count = nodes
		self.activation = activation_function
		self.normalizer = input_normalizer
	
	func to_dict() -> Dictionary:
		return {
			"nodes" : node_count,
			"activationFunction" : ActivationFunction.keys()[activation],
			"inputNormalizer" : InputNormalizer.keys()[normalizer]
		}


class NetworkLayout:
	var input_layer : NetworkLayer
	var output_layer : NetworkLayer
	var hidden_layers : Array[NetworkLayer]
	
	func _init(inputs : NetworkLayer, hidden : Array[NetworkLayer], outputs : NetworkLayer) -> void:
		self.input_layer = inputs
		self.hidden_layers = hidden
		self.output_layer = outputs
	
	func to_dict() -> Dictionary:
		return {
			"inputs" : input_layer.to_dict(),
			"hiddenLayers" : hidden_layers.map(func(x): return x.to_dict()),
			"outputs" : output_layer.to_dict()
		}
