extends Control


@onready var layout_creator: LayoutCreator = $MarginContainer/VBoxContainer/LayoutCreator


func _on_start_button_pressed() -> void:
	GameSettings.network_layout = layout_creator.get_layout()
	get_tree().change_scene_to_packed(SceneManager.get_packed(SceneManager.Scene.TRAINING))


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_packed(SceneManager.get_packed(SceneManager.Scene.MAIN_MENU))
