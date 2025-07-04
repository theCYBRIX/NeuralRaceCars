extends Node

const MAIN_SCENES := {
	Scene.MAIN_MENU : preload("res://scenes/main_menu.tscn"),
	Scene.TRAINING : preload("res://scenes/training_scene.tscn"),
	Scene.GAMEPLAY : preload("res://scenes/gameplay_scene.tscn"),
	Scene.SAVE_SELECTION : preload("res://scenes/save_selection_menu.tscn"),
	Scene.TRAINING_MENU : preload("res://scenes/start_training_menu.tscn"),
	Scene.PLAY_GAME_MENU : preload("res://scenes/start_playing_menu.tscn"),
}

const TRACKS := {
	Track.TRACK_2 : "res://scenes/track_2.tscn",
	Track.TRACK_3 : "res://scenes/track_3.tscn",
	Track.POINT_TO_POINT : "res://scenes/point_to_point.tscn",
}

enum Scene {
	MAIN_MENU,
	TRAINING,
	GAMEPLAY,
	SAVE_SELECTION,
	TRAINING_MENU,
	PLAY_GAME_MENU,
}

enum Track {
	TRACK_2,
	TRACK_3,
	POINT_TO_POINT,
}


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


func get_track_name(track : Track) -> String:
	match track:
		Track.TRACK_2:
			return "Track 2"
		Track.TRACK_3:
			return "Track 3"
		Track.POINT_TO_POINT:
			return "Point to Point"
		_:
			return "Undefined"
