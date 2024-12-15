class_name CameraManager
extends Node

@onready var camera: Camera2D = $Camera
@onready var remote_transform_2d: RemoteTransform2D = $RemoteTransform2D

@export var target : Node = self : set = _set_target
@export var keep_transform_on_free : bool = true
@export var keep_transform_on_tracking : bool = false

var free_floating : bool = false

func _ready() -> void:
	_set_remote_transform_enabled(not free_floating)


func start_tracking(node : Node, keep_transform := false):
	if node is Car:
		target = node.camera_mount
		return
	
	if target != node:
		target = node
		return
	
	if is_node_ready():
<<<<<<< Updated upstream
		_reparent_camera(keep_transform)


func stop_tracking(keep_transform := false):
	start_tracking(self, keep_transform)
=======
		remote_transform_2d.reparent(target, false)
		remote_transform_2d.remote_path = remote_transform_2d.get_path_to(camera)
		_set_remote_transform_enabled(not free_floating)


func stop_tracking(reset_camera := false):
	if reset_camera:
		start_tracking(self)
	else:
		_set_remote_transform_enabled(false)
		remote_transform_2d.reparent(self, false)
>>>>>>> Stashed changes


func _on_camera_toggle_free_floating(enabled: bool) -> void:
	free_floating = enabled
	_set_remote_transform_enabled(not free_floating)


<<<<<<< Updated upstream
func _reparent_camera(keep_transform := false):
	var node : Node = self if free_floating else target
	if node == camera.get_parent(): return
	if not keep_transform:
		keep_transform = keep_transform_on_free if free_floating else keep_transform_on_tracking
	
	camera.reparent(node, keep_transform)
	if not keep_transform:
		camera.position = Vector2.ZERO
		if node is Node2D:
			camera.rotation = node.rotation
=======
func _set_remote_transform_enabled(enabled : bool = true):
	remote_transform_2d.update_position = enabled

>>>>>>> Stashed changes

func _set_target(node : Node):
	target = node
	start_tracking(node)
