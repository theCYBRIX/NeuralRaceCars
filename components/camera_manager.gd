class_name CameraManager
extends Node


@export var chase_camera : ChaseCamera
@export var target : Node2D : set = set_target
@export var enabled : bool = true

@onready var free_cam: Camera2D = $FreeCam


var _free_floating : bool = false


func _process(_delta: float) -> void:
	if not target:
		set_process(false)
		return
	
	free_cam.global_position = target.global_position


func start_tracking(node : Node = target):
	if not node:
		node = self
	
	if target != node:
		target = node
	
	if _free_floating:
		if not free_cam.is_current():
			_switch_to_free_cam()
	elif chase_camera:
		if not chase_camera.is_current():
			_switch_to_chase_cam()
		elif not chase_camera.is_tracking():
			chase_camera.tracking = true


func stop_tracking():
	set_process(false)
	chase_camera.tracking = false


func set_target(node : Node2D):
	target = node
	if not target:
		return
	if target is Car:
		if chase_camera:
			chase_camera.target = target
		target = target.camera_pivot
	if enabled:
		if chase_camera:
			chase_camera.tracking = true
		else:
			set_process(true)


func set_enabled(state : bool) -> void:
	if state == enabled:
		return
	enabled = state


func _switch_to_free_cam() -> void:
	free_cam.enabled = true
	free_cam.global_position = chase_camera.global_position
	free_cam.global_rotation = chase_camera.global_rotation
	free_cam.zoom = chase_camera.zoom
	free_cam.make_current()
	set_process(not _free_floating)
	chase_camera.tracking = false
	chase_camera.enabled = false


func _switch_to_chase_cam() -> void:
	chase_camera.enabled = true
	chase_camera.global_position = free_cam.global_position
	chase_camera.global_rotation = free_cam.global_rotation
	chase_camera.zoom = free_cam.zoom
	chase_camera.tracking = true
	chase_camera.make_current()
	free_cam.enabled = false


func _on_camera_toggle_free_floating(value: bool) -> void:
	_free_floating = value
	if _free_floating:
		_switch_to_free_cam()
	else:
		_switch_to_chase_cam()
