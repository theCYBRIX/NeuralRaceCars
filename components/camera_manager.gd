class_name CameraManager
extends Node

@onready var camera: Camera2D = $Camera
@onready var remote_transform_2d: RemoteTransform2D = $RemoteTransform2D
@onready var car_follow_camera: Camera2D = $CarFollowCamera

@export var target : Node = self : set = _set_target
@export var keep_transform_on_free : bool = true
@export var keep_transform_on_tracking : bool = false

var free_floating : bool = false

func _ready() -> void:
	_set_remote_transform_enabled(not free_floating)


func start_tracking(node : Node):
	if not node:
		node = self
	
	if node is Car:
		car_follow_camera.target = node
		target = node.camera_pivot
		return
	
	if target != node:
		target = node
		return
	
	if is_node_ready():
		reparent_camera.call_deferred()


func reparent_camera() -> void:
	remote_transform_2d.reparent(target, false)
	remote_transform_2d.remote_path = remote_transform_2d.get_path_to(camera)
	_set_remote_transform_enabled(not free_floating)


func stop_tracking(reset_camera := false):
	if reset_camera:
		start_tracking(self)
	else:
		_set_remote_transform_enabled(false)
		remote_transform_2d.reparent(self, false)


func _on_camera_toggle_free_floating(enabled: bool) -> void:
	free_floating = enabled
	_set_remote_transform_enabled(not free_floating)


func _set_remote_transform_enabled(enabled : bool = true):
	remote_transform_2d.update_position = enabled


func _set_target(node : Node):
	target = node
	start_tracking(node)
