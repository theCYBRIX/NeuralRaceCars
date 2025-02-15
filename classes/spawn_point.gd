class_name SpawnPoint
extends RefCounted

var position : Vector2
var rotation : float

func _init(global_pos : Vector2, global_rot : float) -> void:
	position = global_pos
	rotation= global_rot

func apply(node : Node2D) -> void:
	node.global_position = position
	node.global_rotation = rotation

static func from(node : Node2D) -> SpawnPoint:
	return SpawnPoint.new(node.global_position, node.global_rotation)
