class_name CameraManager
extends Node

@onready var camera: Camera2D = $Camera

@export var target : Node = self : set = _set_target
@export var keep_transform_on_free : bool = true
@export var keep_transform_on_tracking : bool = false

var free_floating : bool = false

func _ready() -> void:
	_reparent_camera()


func start_tracking(node : Node, keep_transform := false):
	if node is Car:
		target = node.camera_mount
		return
	
	if target != node:
		target = node
		return
	
	if is_node_ready():
		_reparent_camera(keep_transform)


func stop_tracking(keep_transform := false):
	start_tracking(self, keep_transform)


func _on_camera_toggle_free_floating(enabled: bool) -> void:
	free_floating = enabled
	_reparent_camera()


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

func _set_target(node : Node):
	target = node
	start_tracking(node)
