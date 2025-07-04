@tool
class_name  LayoutCreator
extends Control


const LAYER_SETTINGS_ITEM = preload("res://scenes/ui/layer_settings_item.tscn")


@export var item_swap_animation_length : float = 0.15


@onready var root_container: VBoxContainer = $RootContainer
@onready var network_visualizer: NetworkVisualizer = $RootContainer/MarginContainer/NetworkVisualizer
@onready var layout_generator: NetworkLayoutGenerator = $NetworkLayoutGenerator
@onready var input_layer: LayerSettings = $RootContainer/MarginContainer2/HBoxContainer/PanelContainer/MarginContainer/VBoxContainer/InputLayer
@onready var output_layer: LayerSettings = $RootContainer/MarginContainer2/HBoxContainer/PanelContainer3/MarginContainer/VBoxContainer/OutputLayer
@onready var hidden_layers: VBoxContainer = $RootContainer/MarginContainer2/HBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/MarginContainer/ScrollContainer/HiddenLayers
@onready var scroll_container: ScrollContainer = $RootContainer/MarginContainer2/HBoxContainer/PanelContainer2/MarginContainer/VBoxContainer/MarginContainer/ScrollContainer


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_update_layout_generator()
	
	#TODO: Remove this temp code
	if OS.is_debug_build():
		hidden_layers.get_children()[0].free()
		
		for i in [64, 64, 32]:
			var layer := add_layer().get_settings()
			layer.set_node_count(i)
			layer.set_activation_func(NetworkLayer.ActivationFunction.ReLU)
		
		input_layer.set_node_count(15)
		input_layer.set_input_normalizer(NetworkLayer.InputNormalizer.BATCH)
		
		output_layer.set_node_count(4)
		output_layer.set_activation_func(NetworkLayer.ActivationFunction.SIGMOID)


func get_layout() -> NetworkLayout:
	return layout_generator.create_network_layout()


func add_layer() -> LayerSettingsItem:
	var item : LayerSettingsItem = LAYER_SETTINGS_ITEM.instantiate()
	item.trash_button_pressed.connect(_on_layer_item_trash_button_pressed)
	item.up_button_pressed.connect(_on_layer_item_up_button_pressed)
	item.down_button_pressed.connect(_on_layer_item_down_button_pressed)
	hidden_layers.add_child(item, false, Node.INTERNAL_MODE_FRONT)
	item.owner = hidden_layers
	item.item_index = item.get_index(true)
	
	var item_settings := item.get_settings()
	item_settings.activation_func_changed.connect(_on_any_activation_func_changed)
	item_settings.input_normalizer_changed.connect(_on_any_input_normalizer_changed)
	item_settings.node_count_changed.connect(_on_any_node_count_changed)
	
	_update_layout_generator()
	
	return item


func _is_layer_settings_item(item : Node) -> bool:
	return item is LayerSettingsItem


func _extract_layer_settings(item : LayerSettingsItem) -> LayerSettings:
	return item.get_settings()


func _update_layer_item_indeces() -> void:
	var idx : int = 0
	for item : LayerSettingsItem in hidden_layers.get_children(true).filter(_is_layer_settings_item):
		item.item_index = idx
		idx += 1


func _update_layout_generator() -> void:
	var hidden_layer_settings := hidden_layers.get_children(true).filter(_is_layer_settings_item).map(_extract_layer_settings)
	
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


func _animate_item_swap(item_a : LayerSettingsItem, item_b : LayerSettingsItem, duration : float) -> Signal:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(item_a, "position", item_b.position, duration)
	tween.parallel().tween_property(item_b, "position", item_a.position, duration)
	tween.parallel().tween_property(item_a, "item_index", item_b.item_index, duration)
	tween.parallel().tween_property(item_b, "item_index", item_a.item_index, duration)
	tween.parallel().tween_property(scroll_container, "scroll_vertical", _get_centered_v_scroll_value(item_b), duration)
	return tween.finished


func _animate_scroll_to_item(item : LayerSettingsItem, duration : float) -> Signal:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(scroll_container, "scroll_vertical", _get_centered_v_scroll_value(item), duration)
	return tween.finished


#func _get_centered_v_scroll_pos(item : Control) -> float:
	#var center_pos := item.position.y + item.size.y
	#var scroll_rect := scroll_container.get_re


func _get_centered_v_scroll_value(item: Control) -> float:
	# Convert the item's global position into the scroll container's local space
	var target_pos_in_container := scroll_container.scroll_vertical + item.get_global_position().y - scroll_container.get_global_position().y
	
	# Calculate the offset to center it
	var center_offset := (item.size.y / 2.0) - (scroll_container.size.y / 2.0)
	
	var desired_scroll := target_pos_in_container + center_offset
	
	var v_scrollbar := scroll_container.get_v_scroll_bar()
	desired_scroll = clamp(desired_scroll, v_scrollbar.min_value, v_scrollbar.max_value)
	
	return desired_scroll




func _on_layer_item_trash_button_pressed(item : LayerSettingsItem) -> void:
	item.queue_free()
	await item.tree_exited
	_update_layout_generator()
	_update_layer_item_indeces()


func _on_layer_item_up_button_pressed(item : LayerSettingsItem) -> void:
	var item_idx := item.get_index(true)
	if item_idx == 0:
		return
	var target_idx := item_idx - 1
	var upper_neighbour : LayerSettingsItem = hidden_layers.get_child(target_idx, true)
	await _animate_item_swap(item, upper_neighbour, item_swap_animation_length)
	scroll_container.ensure_control_visible(item)
	hidden_layers.move_child(item, target_idx)
	_update_layout_generator()


func _on_layer_item_down_button_pressed(item : LayerSettingsItem) -> void:
	var item_idx := item.get_index(true)
	var target_idx := item_idx + 1
	if target_idx == hidden_layers.get_child_count(true):
		return
	var lower_neighbour : LayerSettingsItem = hidden_layers.get_child(target_idx, true)
	await _animate_item_swap(item, lower_neighbour, item_swap_animation_length)
	scroll_container.ensure_control_visible(item)
	hidden_layers.move_child(item, target_idx)
	_update_layout_generator()


func _on_add_layer_button_pressed() -> void:
	var new_layer := add_layer()
	_animate_scroll_to_item.call_deferred(new_layer, item_swap_animation_length)


func _on_any_activation_func_changed(_act_func: int) -> void:
	pass


func _on_any_input_normalizer_changed(_normalizer: int) -> void:
	pass


func _on_any_node_count_changed(_count: int) -> void:
	_update_layout_generator()


func _get_minimum_size() -> Vector2:
	if root_container:
		return root_container.get_minimum_size()
	else:
		return Vector2.ZERO
