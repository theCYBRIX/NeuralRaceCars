class_name LinearTrack
extends BaseTrack

@onready var trajectory: Path2D = $Trajectory
var num_checkpoints : int

var checkpoint_offsets : Array[float]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	num_checkpoints = checkpoints_area.get_child_count(true)
	checkpoint_offsets = []
	checkpoint_offsets.resize(num_checkpoints)
	
	var index : int = 0
	for check in checkpoints_area.get_children(true):
		checkpoint_offsets[index] = get_trajectory_fraction(check.global_position)
		index += 1


func get_progress(car : Car) -> float:
	if (not car is NeuralCar) or car.active:
		return get_absolute_progress(car.global_position, car.checkpoint_tracker.checkpoint_index)
	else:
		return get_absolute_progress(car.final_pos, car.checkpoint_tracker.checkpoint_index)


func get_closest_spawn_point(for_whom : Car = null) -> SpawnPoint:
	var trajectory_offset := get_closest_trajectory_offset(for_whom.global_position)
	var local_transform := trajectory.curve.sample_baked_with_rotation(trajectory_offset)
	return SpawnPoint.new(trajectory.to_global(local_transform.get_origin()), (trajectory.global_rotation + local_transform.get_rotation()) + CAR_FORWARDS_ANGLE)


func get_target_direction(node : Node2D, checkpoint_index : int, look_ahead_px : float) -> float:
	return get_track_direction(node.global_position, checkpoint_index, look_ahead_px)


func get_lap_progress(global_pos : Vector2, checkpoint_index : int) -> float:
	var trajectory_fraction : float = get_trajectory_fraction(global_pos)
	var true_check_index = (checkpoint_index + 1) % num_checkpoints
	
	if trajectory_fraction <= checkpoint_offsets[true_check_index]:
		return trajectory_fraction
	
	if true_check_index == 0 and checkpoint_index >= (num_checkpoints - 1):
		return trajectory_fraction
	
	return 0


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
	return raycast(global_pos, trajectory.to_global(trajectory.curve.sample_baked(curve_offset_px)))
