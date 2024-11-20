class_name BaseTrack
extends Node2D

signal car_entered_checkpoint(car: NeuralCar, checkpoint_index: int, num_checkpoints : int, checkpoints : Area2D)

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
	if body is NeuralCar:
		car_entered_checkpoint.emit(body, local_shape_index, num_checkpoints, checkpoints)


func get_lap_progress(global_pos : Vector2, checkpoint_index : int) -> float:
	var trajectory_fraction : float = get_trajectory_fraction(global_pos)
	if trajectory_fraction <= checkpoint_offsets[checkpoint_index + 1]:
		return trajectory_fraction
	else:
		return 0


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
	
	#line_2d.clear_points()
	#line_2d.add_point(trajectory.to_global(trajectory.curve.sample_baked(trajectory_px)))
	#line_2d.add_point(global_pos)
	#line_2d.add_point(trajectory_point)
	
	var direction := global_pos.angle_to_point(trajectory_point)
	return direction


func raycast_to_curve(global_pos : Vector2, curve_offset_px : float) -> Dictionary:
	var direct_state := get_world_2d().direct_space_state
	
	raycast_query_param.from = global_pos
	raycast_query_param.to = trajectory.to_global(trajectory.curve.sample_baked(curve_offset_px))
	
	var collision := direct_state.intersect_ray(raycast_query_param)
	return collision
