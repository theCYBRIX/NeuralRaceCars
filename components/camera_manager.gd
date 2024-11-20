class_name CameraManager
extends Node

@onready var camera: Camera2D = $Camera

@export var target : Node = self : set = start_tracking
@export var keep_transform_on_free : bool = true
@export var keep_transform_on_tracking : bool = false

var free_floating : bool = false

func _ready() -> void:
	_reparent_camera()


func start_tracking(node : Node):
	if node is Car:
		node = node.camera_mount
	if target == node: return
	target = node
	if is_node_ready():
		_reparent_camera()


func reset():
	start_tracking(self)


func _on_camera_toggle_free_floating(enabled: bool) -> void:
	free_floating = enabled
	_reparent_camera()


func _reparent_camera():
	var node : Node = self if free_floating else target
	if node == camera.get_parent(): return
	var keep_transform = keep_transform_on_free if free_floating else keep_transform_on_tracking
	camera.reparent(node, keep_transform)
	if not keep_transform:
		camera.position = Vector2.ZERO
		if node is Node2D:
			camera.rotation = node.rotation
