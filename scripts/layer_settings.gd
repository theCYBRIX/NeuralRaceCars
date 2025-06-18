class_name LayerSettings
extends PanelContainer


signal node_count_changed(count : int)
signal activation_func_changed(act_func : int)
signal input_normalizer_changed(normalizer : int)


@onready var activation_option: OptionButton = $MarginContainer/VBoxContainer/ActivationSelector/ActivationOption
@onready var normalizer_option: OptionButton = $MarginContainer/VBoxContainer/NormalizerSelector/NormalizerOption
@onready var node_count: SpinBox = $MarginContainer/VBoxContainer/HBoxContainer/NodeCount


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for norm : String in NetworkLayer.InputNormalizer.keys():
		normalizer_option.add_item(norm.capitalize(), NetworkLayer.InputNormalizer[norm])
	
	for act : String in NetworkLayer.ActivationFunction.keys():
		activation_option.add_item(act.capitalize() if act != "ReLU" else act, NetworkLayer.ActivationFunction[act])


func get_node_count() -> int:
	return int(node_count.value)


func set_node_count(count : int) -> void:
	node_count.value = count


func get_activation_func() -> int:
	return activation_option.get_selected_id()


func set_activation_func(function : NetworkLayer.ActivationFunction):
	activation_option.select(activation_option.get_item_index(function))


func get_input_normalizer() -> int:
	return normalizer_option.get_selected_id()


func set_input_normalizer(normalizer : NetworkLayer.InputNormalizer) -> void:
	normalizer_option.select(normalizer_option.get_item_index(normalizer))


func _on_node_count_value_changed(value: float) -> void:
	node_count_changed.emit(value)


func _on_activation_option_item_selected(index: int) -> void:
	activation_func_changed.emit(activation_option.get_item_id(index))


func _on_normalizer_option_item_selected(index: int) -> void:
	input_normalizer_changed.emit(normalizer_option.get_item_id(index))
