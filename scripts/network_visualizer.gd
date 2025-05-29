@tool

class_name NetworkVisualizer
extends Control


@export var layout_generator : NetworkLayoutGenerator = null : set = set_layout_generator
@export var node_separation : Vector2 = Vector2.ZERO : set = set_node_separation
@export_range(0, 1) var node_size_multiplier : float = 1 : set = set_node_size_multiplier

@export_group("Colors")
@export var background_color : Color = 0x00000000 : set = set_background_color
@export var node_color : Color = 0xc9c600FF : set = set_node_color
@export var connection_color : Color = 0xdd9dd9FF : set = set_connection_color

@export_group("Draw Settings")
@export var line_stroke_width := 1.0 : set = set_connection_width
@export var antialiased := true : set = set_antialiased

var network_layout : NetworkLayout : set = set_network_layout

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color, true)
	if not network_layout: return
	var max_nodes_x := get_max_layer_node_count(network_layout)
	var max_nodes_y := get_layer_count(network_layout)
	var node_offset := size / Vector2(max_nodes_x, max_nodes_y)
	var center := size / 2.0
	
	var node_positions : Array[Array] = []
	node_positions.resize(max_nodes_y)
	var layer_index :int = -1
	
	for layer in get_layers_as_array(network_layout):
		layer_index += 1
		
		var layer_array : Array[Vector2] = []
		layer_array.resize(layer.node_count)
		node_positions[layer_index] = layer_array
		
		var pos_y := (center.y + (max_nodes_y / 2.0) * node_offset.y + (max_nodes_y / 2.0 - 1) * node_separation.y) - (layer_index + 0.5) * node_offset.y - (layer_index * node_separation.y)
		for node_index in range(layer.node_count):
			var pos_x = (center.x - (layer.node_count / 2.0) * node_offset.x - (layer.node_count / 2.0 - 1) * node_separation.x) + (node_index + 0.5) * node_offset.x + (node_index * node_separation.x)
			var pos := Vector2(pos_x, pos_y)
			layer_array[node_index] = pos
	
	for layer in range(node_positions.size() - 1):
		for pos in node_positions[layer]:
				for node in node_positions[layer + 1]:
					draw_line(pos, node, connection_color, line_stroke_width, antialiased)
	
	var node_radius := (minf(node_offset.x, node_offset.y) / 2.0) *  node_size_multiplier
	for layer in node_positions:
		for pos in layer:
			draw_circle(pos, node_radius, node_color, true, -1.0, antialiased)
			#draw_circle(pos, node_radius, Color.BLACK, false, node_radius * 0.1)


func get_max_layer_node_count(layout : NetworkLayout) -> int:
	return get_node_count_array(layout).max()


func get_layer_count(layout : NetworkLayout) -> int:
	return layout.hidden_layers.size() + 2


func get_node_count_array(layout : NetworkLayout) -> Array:
	return get_layers_as_array(layout).map(func(x : NetworkLayer) -> int: return x.node_count)


func get_layers_as_array(layout : NetworkLayout) -> Array[NetworkLayer]:
	var layers : Array[NetworkLayer] = []
	
	layers.resize(layout.hidden_layers.size() + 2)
	layers[0] = layout.input_layer
	layers[layers.size() - 1] = layout.output_layer
	
	var index = 1
	for layer in layout.hidden_layers:
		layers[index] = layer
		index += 1
	
	return layers


func set_layout_generator(generator : NetworkLayoutGenerator):
	layout_generator = generator
	if layout_generator:
		layout_generator.layout_changed.connect(_on_network_layout_generator_layout_changed)
		refresh_layout_generator_layout()
	update_configuration_warnings()


func set_network_layout(layout : NetworkLayout) -> void:
	network_layout = layout
	queue_redraw()
	if layout:
		tooltip_text = "inputs: %d\nhidden layers: %s\noutputs: %d" % [layout.input_layer.node_count, str(layout.hidden_layers.map(func(x): return x.node_count)), layout.output_layer.node_count]


func refresh_layout_generator_layout():
	network_layout = layout_generator.create_network_layout()


func set_antialiased(enabled := true) -> void:
	if antialiased == enabled: return
	antialiased = enabled
	queue_redraw()


func set_node_size_multiplier(diameter : float):
	node_size_multiplier = diameter
	queue_redraw()

func set_connection_width(width : float) -> void:
	line_stroke_width = width
	queue_redraw() 


func set_connection_color(color : Color) -> void:
	connection_color = color
	queue_redraw()


func set_node_color(color : Color) -> void:
	node_color = color
	queue_redraw()


func set_background_color(color : Color) -> void:
	background_color = color
	queue_redraw()



func set_node_separation(separation : Vector2) -> void:
	node_separation = separation
	queue_redraw()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings : PackedStringArray = []
	
	if not layout_generator:
		warnings.append("A Layout Generator must be specified.")
	
	return warnings


func _on_network_layout_generator_layout_changed() -> void:
	if not layout_generator.hidden_layer_sizes.any(func(x): return x <= 0):
		refresh_layout_generator_layout()
