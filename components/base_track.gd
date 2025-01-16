class_name BaseTrack
extends Node2D

signal car_entered_checkpoint(car: Car, checkpoint_index: int, num_checkpoints : int, checkpoints : Area2D)

enum SpawnType {
	TRACK_START,
	CLOSEST_POINT,
	LAST_CHECKPOINT
}

const CAR_FORWARDS_ANGLE := PI / 2.0

@onready var spawn_point: Marker2D = $SpawnPoint
@onready var checkpoints: Area2D = $Checkpoints
var num_checkpoints : int
@onready var trajectory: Path2D = $Trajectory
@onready var line_2d: Line2D = $Line2D

var checkpoint_offsets : Array[float]

var raycast_query_param : PhysicsRayQueryParameters2D


func _init() -> void:
	raycast_query_param = PhysicsRayQueryParameters2D.new()
	raycast_query_param.collision_mask = 0b00000000_00000000_00000000_000001
	raycast_query_param.collide_with_areas = false
	raycast_query_param.collide_with_bodies = true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	num_checkpoints = checkpoints.get_child_count()

	checkpoint_offsets = []
	checkpoint_offsets.resize(num_checkpoints)
	
	var index : int = 0
	for check in checkpoints.get_children(true):
		checkpoint_offsets[index] = get_trajectory_fraction(check.global_position)
		index += 1


func _on_checkpoints_body_shape_entered(_body_rid: RID, body: Node2D, _body_shape_index: int, local_shape_index: int) -> void:
	if body is Car:
		car_entered_checkpoint.emit(body, local_shape_index, num_checkpoints, checkpoints)
		var car : Car = body
		if car is NeuralCar and not car.active:
			return
		#print("%d == %d" %[car.checkpoint_index, local_shape_index - 1])
		car.checkpoint(((car.checkpoint_index + 1) / num_checkpoints) * num_checkpoints + local_shape_index)


func get_lap_progress(global_pos : Vector2, checkpoint_index : int) -> float:
	var trajectory_fraction : float = get_trajectory_fraction(global_pos)
	var true_check_index = (checkpoint_index + 1) % num_checkpoints
	
	if trajectory_fraction <= checkpoint_offsets[true_check_index]:
		return trajectory_fraction
	
	if true_check_index == 0 and checkpoint_index >= (num_checkpoints - 1):
		return trajectory_fraction
	
	return 0


func get_spawn_point(type := SpawnType.TRACK_START, for_whom : Car = null) -> SpawnPoint:
	match type:
		SpawnType.TRACK_START:
			return SpawnPoint.from(spawn_point)
		SpawnType.LAST_CHECKPOINT:
			return SpawnPoint.from(spawn_point if for_whom.checkpoint_index < 0 else checkpoints.get_children(true)[for_whom.checkpoint_index % num_checkpoints])
		SpawnType.CLOSEST_POINT:
			var trajectory_offset := get_closest_trajectory_offset(for_whom.global_position)
			var local_transform := trajectory.curve.sample_baked_with_rotation(trajectory_offset)
			return SpawnPoint.new(trajectory.to_global(local_transform.get_origin()), (trajectory.global_rotation + local_transform.get_rotation()) + CAR_FORWARDS_ANGLE)
		_:
			push_error("Unknown SpawnType requested: %d" % type)
			return SpawnPoint.from(spawn_point)


func get_absolute_progress(global_pos : Vector2, checkpoint_index : int) -> float:
	var laps_completed : int = floori(checkpoint_index / num_checkpoints)
	var lap_progress : float = get_lap_progress(global_pos, checkpoint_index)
	if (checkpoint_index % num_checkpoints) == (num_checkpoints - 1):
		if lap_progress < checkpoint_offsets[0]:
			laps_completed += 1
	return laps_completed + lap_progress


func get_closest_trajectory_offset(global_pos : Vector2) -> float:
	return trajectory.curve.get_closest_offset(trajectory.to_local(global_pos))


func get_trajectory_fraction(global_pos : Vector2) -> float:
	var closest_point := get_closest_trajectory_offset(global_pos)
	return closest_point / trajectory.curve.get_baked_length()


func get_track_direction(global_pos : Vector2, look_ahead_px : float, search_depth : int = 4, minimum_look_ahead : float = 300) -> float:
	var trajectory_px := get_closest_trajectory_offset(global_pos)
	var collision = raycast_to_curve(global_pos,  fmod(trajectory_px + look_ahead_px, trajectory.curve.get_baked_length()) )
	
	if not collision.is_empty():
		var look_ahead_offset : float = -look_ahead_px
		var best_valid_look_ahead : float = minimum_look_ahead
		
		for i in range(search_depth):
			look_ahead_offset = look_ahead_offset / 2
			look_ahead_px += look_ahead_offset
			collision = raycast_to_curve(global_pos, fmod(trajectory_px + look_ahead_px, trajectory.curve.get_baked_length()) )
			if collision.is_empty():
				best_valid_look_ahead = look_ahead_px
				if look_ahead_offset < 0: look_ahead_offset = -look_ahead_offset
			else:
				if look_ahead_offset > 0: look_ahead_offset = -look_ahead_offset
		
		look_ahead_px = best_valid_look_ahead
	
	var trajectory_point := trajectory.to_global(trajectory.curve.sample_baked( fmod(trajectory_px + look_ahead_px, trajectory.curve.get_baked_length()) ))
	
	var direction := global_pos.angle_to_point(trajectory_point)
	return direction


func raycast_to_curve(global_pos : Vector2, curve_offset_px : float) -> Dictionary:
	var direct_state := get_world_2d().direct_space_state
	
	raycast_query_param.from = global_pos
	raycast_query_param.to = trajectory.to_global(trajectory.curve.sample_baked(curve_offset_px))
	
	var collision := direct_state.intersect_ray(raycast_query_param)
	return collision
