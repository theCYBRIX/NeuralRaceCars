extends Control


const TRACKS := {
	"Track 2" : "res://scenes/track_2.tscn",
	"Point to Point" : "res://scenes/point_to_point.tscn",
}

@onready var option_button: OptionButton = $HBoxContainer/VBoxContainer/OptionButton

func _ready() -> void:
	for track in TRACKS.keys():
		option_button.add_item(track)
	
	#var replay_data = ResourceLoader.load("C:\\Users\\math_\\AppData\\Roaming\\Godot\\app_userdata\\CarGame\\saved_networks(20)(recording).res")
	#pass


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_packed(SceneManager.get_packed(SceneManager.Scene.TRAINING))


func _on_load_button_pressed() -> void:
	get_tree().change_scene_to_packed(SceneManager.get_packed(SceneManager.Scene.SAVE_SELECTION))


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_packed(SceneManager.get_packed(SceneManager.Scene.GAMEPLAY))


func _on_option_button_item_selected(index: int) -> void:
	GameSettings.track_scene = ResourceLoader.load(TRACKS.values()[index])
