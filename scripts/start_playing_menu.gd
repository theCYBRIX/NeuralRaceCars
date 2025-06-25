extends Control


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_packed(SceneManager.get_packed(SceneManager.Scene.GAMEPLAY))


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_packed(SceneManager.get_packed(SceneManager.Scene.MAIN_MENU))
