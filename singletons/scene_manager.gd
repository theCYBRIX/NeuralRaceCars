extends Node

const MAIN_SCENES := {
	Scene.MAIN_MENU : preload("res://scenes/main_menu.tscn"),
	Scene.TRAINING : preload("res://scenes/training_scene.tscn"),
	Scene.GAMEPLAY : preload("res://scenes/gameplay_scene.tscn"),
	Scene.SAVE_SELECTION : preload("res://scenes/save_selection_menu.tscn"),
}

enum Scene {
	MAIN_MENU,
	TRAINING,
	GAMEPLAY,
	SAVE_SELECTION,
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
