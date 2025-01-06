extends Control


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game_area.tscn")


func _on_load_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/save_selection_menu.tscn")


func _on_exit_button_pressed() -> void:
	get_tree().quit()
