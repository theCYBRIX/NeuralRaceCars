@tool
class_name  LayoutCreator
extends Control


const LAYER_SETTINGS_ITEM = preload("res://scenes/ui/layer_settings_item.tscn")


@onready var root_container: VBoxContainer = $RootContainer
@onready var network_visualizer: NetworkVisualizer = $RootContainer/MarginContainer/NetworkVisualizer
@onready var layout_generator: NetworkLayoutGenerator = $NetworkLayoutGenerator
@onready var input_layer: LayerSettings = $RootContainer/MarginContainer2/HBoxContainer/PanelContainer/VBoxContainer/InputLayer
@onready var output_layer: LayerSettings = $RootContainer/MarginContainer2/HBoxContainer/PanelContainer3/VBoxContainer/OutputLayer
@onready var hidden_layers: VBoxContainer = $RootContainer/MarginContainer2/HBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/MarginContainer/ScrollContainer/HiddenLayers


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_update_layout_generator()
	
	#TODO: Remove this temp code
	hidden_layers.get_children()[0].queue_free()
	await get_tree().process_frame
	
	for i in [64, 64, 32]:
		var layer := add_layer().get_settings()
		layer.node_count.value = i
		layer.activation_option.select(layer.activation_option.get_item_index(NetworkLayer.ActivationFunction.ReLU))
	
	input_layer.node_count.value = 15
	input_layer.normalizer_option.select(input_layer.normalizer_option.get_item_index(NetworkLayer.InputNormalizer.BATCH))
	
	output_layer.node_count.value = 4
	output_layer.activation_option.select(output_layer.activation_option.get_item_index(NetworkLayer.ActivationFunction.SIGMOID))


func get_layout() -> NetworkLayout:
	return layout_generator.create_network_layout()


func add_layer() -> LayerSettingsItem:
	var item : LayerSettingsItem = LAYER_SETTINGS_ITEM.instantiate()
	item.trash_button_pressed.connect(_on_layer_item_trash_button_pressed)
	hidden_layers.add_child(item)
	item.owner = hidden_layers
	
	var item_settings := item.get_settings()
	item_settings.activation_func_changed.connect(_on_any_activation_func_changed)
	item_settings.input_normalizer_changed.connect(_on_any_input_normalizer_changed)
	item_settings.node_count_changed.connect(_on_any_node_count_changed)
	
	_update_layout_generator()
	
	return item


func _update_layout_generator() -> void:
	var hidden_layer_settings := hidden_layers.get_children().map(func(x : LayerSettingsItem) -> LayerSettings: return x.get_settings())
	
	layout_generator.num_inputs = input_layer.get_node_count()
	layout_generator.num_outputs = output_layer.get_node_count()
	layout_generator.hidden_layer_sizes.assign(hidden_layer_settings.map(func(x : LayerSettings) -> int: return x.get_node_count())) 
	
	var activation_functions : Array[int] = []
	activation_functions.append(input_layer.get_activation_func())
	activation_functions.append_array(hidden_layer_settings.map(func(x : LayerSettings) -> int: return x.get_activation_func()))
	activation_functions.append(input_layer.get_activation_func())
	
	layout_generator.activation_functions.assign(activation_functions.map(func(x : int) -> NetworkLayer.ActivationFunction: return NetworkLayer.ActivationFunction.values()[x]))
	
	var input_normalizers : Array[int] = []
	input_normalizers.append(input_layer.get_activation_func())
	input_normalizers.append_array(hidden_layer_settings.map(func(x : LayerSettings) -> int: return x.get_input_normalizer()))
	input_normalizers.append(input_layer.get_activation_func())
	
	layout_generator.input_normalizers.assign(input_normalizers.map(func(x : int) -> NetworkLayer.InputNormalizer: return NetworkLayer.InputNormalizer.values()[x]))
	layout_generator.emit_signal("layout_changed")


func _on_layer_item_trash_button_pressed(item : LayerSettingsItem) -> void:
	item.queue_free()
	await item.tree_exited
	_update_layout_generator()


func _on_add_layer_button_pressed() -> void:
	add_layer()


func _on_any_activation_func_changed(_act_func: int) -> void:
	pass


func _on_any_input_normalizer_changed(_normalizer: int) -> void:
	pass


func _on_any_node_count_changed(_count: int) -> void:
	_update_layout_generator()


func _get_minimum_size() -> Vector2:
	return root_container.get_minimum_size() if is_node_ready() else Vector2.ZERO
