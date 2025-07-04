class_name LayerSettingsItem
extends Control


signal trash_button_pressed(item : LayerSettingsItem)
signal up_button_pressed(item : LayerSettingsItem)
signal down_button_pressed(item : LayerSettingsItem)


@onready var layer_settings: LayerSettings = $PanelContainer/MarginContainer/HBoxContainer/LayerSettings
@onready var index_label: Label = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer/MarginContainer/VBoxContainer/IndexLabel
@onready var panel_container: PanelContainer = $PanelContainer
@onready var up_button: Button = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer/MarginContainer/VBoxContainer/UpButton
@onready var down_button: Button = $PanelContainer/MarginContainer/HBoxContainer/PanelContainer/MarginContainer/VBoxContainer/DownButton


var item_index : int = 0 : set = set_item_index


func _ready() -> void:
	get_parent().child_order_changed.connect(_on_sibling_count_changed)
	_on_item_index_changed()


func get_settings() -> LayerSettings:
	return layer_settings


func set_item_index(idx : int) -> void:
	if idx == item_index:
		return
	item_index = idx
	_on_item_index_changed()


func _on_sibling_count_changed() -> void:
	_on_item_index_changed()


func _on_item_index_changed() -> void:
	if index_label:
		index_label.text = str(item_index + 1)
	
	if up_button:
		up_button.disabled = (item_index == 0)
	
	if down_button:
		var parent := get_parent()
		if parent:
			down_button.disabled = (item_index == parent.get_child_count(true) - 1)


func _on_trash_button_pressed() -> void:
	trash_button_pressed.emit(self)


func _on_up_button_pressed() -> void:
	up_button_pressed.emit(self)


func _on_down_button_pressed() -> void:
	down_button_pressed.emit(self)


func _get_minimum_size() -> Vector2:
	if panel_container:
		return panel_container.get_minimum_size()
	else:
		return Vector2.ZERO
