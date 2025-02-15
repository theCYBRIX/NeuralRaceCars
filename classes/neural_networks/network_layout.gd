class_name NetworkLayout
extends RefCounted

const LAYOUT_INPUTS := "inputs"
const LAYOUT_HIDDEN_LAYERS := "hiddenLayers"
const LAYOUT_OUTPUTS := "outputs"


var input_layer : NetworkLayer
var output_layer : NetworkLayer
var hidden_layers : Array[NetworkLayer]

func _init(inputs : NetworkLayer, hidden : Array[NetworkLayer], outputs : NetworkLayer) -> void:
	self.input_layer = inputs
	self.hidden_layers = hidden
	self.output_layer = outputs

func to_dict() -> Dictionary:
	return {
		LAYOUT_INPUTS : input_layer.to_dict(),
		LAYOUT_HIDDEN_LAYERS : hidden_layers.map(func(x): return x.to_dict()),
		LAYOUT_OUTPUTS : output_layer.to_dict()
		}

## returns the NetworkLayout matching the dictionary, or null if the dictionary does not fully discribe a layout. 
static func from_dict(layout : Dictionary) -> NetworkLayout:
	if not layout: return null
	
	var input_layer : NetworkLayer
	var output_layer : NetworkLayer
	var hidden_layers : Array[NetworkLayer]
	
	if layout.has(LAYOUT_INPUTS):
		input_layer =  NetworkLayer.from_dict(layout[LAYOUT_INPUTS])
	else:
		return null
	
	if layout.has(LAYOUT_HIDDEN_LAYERS):
		hidden_layers = []
		for layer in layout[LAYOUT_HIDDEN_LAYERS]:
			var converted := NetworkLayer.from_dict(layer)
			if not converted:
				return null
			hidden_layers.append(converted)
	else:
		return null
	
	if layout.has(LAYOUT_OUTPUTS):
		output_layer =  NetworkLayer.from_dict(layout[LAYOUT_OUTPUTS])
	else:
		return null
	
	return NetworkLayout.new(input_layer, hidden_layers, output_layer)
