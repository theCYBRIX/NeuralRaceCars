class_name LayerSettingsItem
extends HBoxContainer


signal trash_button_pressed(item : LayerSettingsItem)


@onready var layer_settings: LayerSettings = $LayerSettings


func _on_trash_button_pressed() -> void:
	trash_button_pressed.emit(self)


func get_settings() -> LayerSettings:
	return layer_settings
