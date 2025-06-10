extends Control


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_packed(SceneManager.get_packed(SceneManager.Scene.TRAINING_MENU))


func _on_load_button_pressed() -> void:
	get_tree().change_scene_to_packed(SceneManager.get_packed(SceneManager.Scene.SAVE_SELECTION))


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_packed(SceneManager.get_packed(SceneManager.Scene.GAMEPLAY))
