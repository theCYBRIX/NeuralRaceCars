class_name NetworkLayer
extends Node


const LAYER_NODES := "nodes"
const LAYER_ACTIVATION_FUNC := "activationFunction"
const LAYER_INPUT_NORMALIZER := "inputNormalizer"


var node_count : int
var activation : ActivationFunction
var normalizer : InputNormalizer


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


func _init(nodes : int, activation_function : ActivationFunction, input_normalizer : InputNormalizer ) -> void:
	self.node_count = nodes
	self.activation = activation_function
	self.normalizer = input_normalizer


func to_dict() -> Dictionary:
	return {
			LAYER_NODES : node_count,
			LAYER_ACTIVATION_FUNC : ActivationFunction.keys()[activation],
			LAYER_INPUT_NORMALIZER : InputNormalizer.keys()[normalizer]
			}


## returns the NetworkLayer matching the dictionary, or null if the dictionary does not fully discribe a layer. 
static func from_dict(layer : Dictionary) -> NetworkLayer:
	if not layer: return null
	
	var node_count : int
	var activation : ActivationFunction
	var normalizer : InputNormalizer
	
	if layer.has(LAYER_NODES):
		node_count = layer[LAYER_NODES]
	else:
		return null
	
	if layer.has(LAYER_ACTIVATION_FUNC):
		activation = ActivationFunction.get(layer[LAYER_ACTIVATION_FUNC])
	else:
		return null
	
	if layer.has(LAYER_INPUT_NORMALIZER):
		normalizer = InputNormalizer.get(layer[LAYER_INPUT_NORMALIZER])
	else:
		return null
	
	return NetworkLayer.new(node_count, activation, normalizer)
