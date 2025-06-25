extends Node

const MAIN_SCENES := {
	Scene.MAIN_MENU : preload("res://scenes/main_menu.tscn"),
	Scene.TRAINING : preload("res://scenes/training_scene.tscn"),
	Scene.GAMEPLAY : preload("res://scenes/gameplay_scene.tscn"),
	Scene.SAVE_SELECTION : preload("res://scenes/save_selection_menu.tscn"),
	Scene.TRAINING_MENU : preload("res://scenes/start_training_menu.tscn"),
	Scene.PLAY_GAME_MENU : preload("res://scenes/start_playing_menu.tscn"),
}

enum Scene {
	MAIN_MENU,
	TRAINING,
	GAMEPLAY,
	SAVE_SELECTION,
	TRAINING_MENU,
	PLAY_GAME_MENU,
}

var JAVA_INSTALLED : bool
var ACTION_DOWNLOAD := "download"
var ACTION_EXIT := "exit"


func _ready() -> void:
	JAVA_INSTALLED = Util.is_java_installed()
	if not JAVA_INSTALLED:
		var dialog = AcceptDialog.new()
		dialog.disable_3d = true
		dialog.dialog_text = "Java is required to run SimpleNeuralNetwork.\nPlease install Java and restart the game."
		dialog.custom_action.connect(_on_dialog_custom_action)
		dialog.add_button("Get Java", true, ACTION_DOWNLOAD)
		dialog.add_button("Exit", true, ACTION_EXIT)
		dialog.visibility_changed.connect(func(): if not dialog.visible: dialog.queue_free())
		add_child(dialog)
		dialog.popup_centered()


func _on_dialog_custom_action(action : String) -> void:
	match action:
		ACTION_DOWNLOAD:
			OS.shell_open("https://www.java.com/en/download/")
		ACTION_EXIT:
			get_tree().quit()
	


func set_scene(scene : Scene) -> Node:
	return set_scene_to_packed(get_packed(scene))

func set_current_scene(new_scene : Node) -> Node:
	var prev_scene = get_tree().current_scene
	get_tree().current_scene.get_parent().add_child(new_scene)
	get_tree().current_scene = new_scene
	prev_scene.get_parent().remove_child(prev_scene)
	return prev_scene

func set_scene_to_file(path : String) -> Node:
	var packed_scene : PackedScene = ResourceLoader.load(path)
	return set_scene_to_packed(packed_scene)

func set_scene_to_packed(scene : PackedScene) -> Node:
	if not scene:
		return null
	var instance := scene.instantiate()
	if not instance:
		return null
	return set_current_scene(instance)

func get_packed(scene : Scene) -> PackedScene:
	return MAIN_SCENES[scene]
