extends Node

func switch_current_scene(new_scene : Node):
	get_tree().current_scene.get_parent().add_child(new_scene)
	get_tree().current_scene = new_scene
