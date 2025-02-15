class_name BaseTrack
extends Node2D

signal body_entered_checkpoint(body : PhysicsBody2D, checkpoint_index : int, num_checkpoints : int, checkpoints_area : Area2D)

enum SpawnType {
	TRACK_START,
	CLOSEST_POINT,
	LAST_CHECKPOINT
}

const CAR_FORWARDS_ANGLE := PI / 2.0

@onready var spawn_point: Marker2D = $SpawnPoint
@onready var checkpoints_area: Area2D = $Checkpoints

var raycast_query_param : PhysicsRayQueryParameters2D


func _init() -> void:
	raycast_query_param = PhysicsRayQueryParameters2D.new()
	raycast_query_param.collision_mask = 0b00000000_00000000_00000000_000001
	raycast_query_param.collide_with_areas = false
	raycast_query_param.collide_with_bodies = true


func get_target_direction(node : Node2D, checkpoint_index : int, look_ahead_px : float) -> float:
	return node.global_position.angle_to_point(get_checkpoint(checkpoint_index + 1).global_position)


func _on_checkpoints_body_shape_entered(_body_rid: RID, body: Node2D, _body_shape_index: int, local_shape_index: int) -> void:
	if body is Car:
		body_entered_checkpoint.emit(body, local_shape_index, checkpoints_area.get_child_count(), checkpoints_area)
		
		if body is Car:
			#print(car.checkpoint_index)
			if not body.moving_forwards or (body is NeuralCar and not body.active):
				return
			#print("%d == %d" %[car.checkpoint_index, local_shape_index - 1])
		
		if body.has_node("CheckpointTracker"):
			var tracker : CheckpointTracker = body.get_node("CheckpointTracker")
			tracker.checkpoint(((tracker.checkpoint_index + 1) / checkpoints_area.get_child_count()) * checkpoints_area.get_child_count() + local_shape_index)



func raycast(from : Vector2, to : Vector2) -> Dictionary:
	var direct_state := get_world_2d().direct_space_state
	
	if not direct_state:
		return {}
	
	raycast_query_param.from = from
	raycast_query_param.to = to
	
	var collision := direct_state.intersect_ray(raycast_query_param)
	return collision


func get_checkpoint(index : int) -> CollisionShape2D:
	return checkpoints_area.get_child(index % checkpoints_area.get_child_count(true), true)


func get_progress(car : Car) -> float:
	return car.checkpoint_index


func get_spawn_point(type := SpawnType.TRACK_START, for_whom : Car = null) -> SpawnPoint:
	match type:
		SpawnType.TRACK_START:
			return get_track_start_spawn_point(for_whom)
		SpawnType.LAST_CHECKPOINT:
			return get_last_checkpoint_spawn_point(for_whom)
		SpawnType.CLOSEST_POINT:
			return get_closest_spawn_point(for_whom)
		_:
			push_error("Unknown SpawnType requested: %d" % type)
			return SpawnPoint.from(spawn_point)


@warning_ignore("unused_variable")
func get_track_start_spawn_point(for_whom : Car = null) -> SpawnPoint:
	return SpawnPoint.from(spawn_point)


func get_last_checkpoint_spawn_point(for_whom : Car = null) -> SpawnPoint:
	return SpawnPoint.from(spawn_point if for_whom.checkpoint_index < 0 else checkpoints_area.get_children(true)[for_whom.checkpoint_index % checkpoints_area.get_child_count()])


func get_closest_spawn_point(for_whom : Car = null) -> SpawnPoint:
	push_warning("Closest spawn point is not implemented")
	return get_track_start_spawn_point(for_whom)
