class_name TestingCar
extends NeuralCar

enum UserInput {
	FORWARDS,
	REVERSE,
	TURN_LEFT,
	TURN_RIGHT
}

@export var deactivateable : bool = false

@onready var sensor_vision: Line2D = $SensorVision
var sequential_sensors : Array[RayCast2D]
@onready var closest_point_on_track: Line2D = $ClosestPointOnTrack

@onready var arrow: Sprite2D = $Arrow

func _ready() -> void:
	super._ready()
	
	sequential_sensors = []
	sequential_sensors.append_array($Sensors/AnchorFL.get_children())
	sequential_sensors.append_array($Sensors/AnchorBL.get_children())
	sequential_sensors.reverse()
	sequential_sensors.append_array($Sensors/AnchorFR.get_children())
	sequential_sensors.append_array($Sensors/AnchorBR.get_children())
	print(sequential_sensors.size())

func _process(delta: float) -> void:
	#super._process(delta)
	
	#print("Lap progress: %4.3f" % get_lap_progress())
	
	sensor_vision.clear_points()
	for s in sequential_sensors:
		if s.is_colliding():
			sensor_vision.add_point(to_local(s.get_collision_point()))
		else:
			sensor_vision.add_point(s.get_parent().position + s.target_position)
	
	#closest_point_on_track.clear_points()
	#closest_point_on_track.add_point(Vector2.ZERO)
	#closest_point_on_track.add_point(to_local(track.trajectory.to_global(track.trajectory.curve.sample_baked(track.get_closest_trajectory_offset(global_position)))))


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if not track: return
	
	if arrow.visible:
		arrow.global_rotation = track.get_target_direction(self, checkpoint_tracker.checkpoint_index, 500) + PI
		#print(angle_difference(track.get_target_direction(self, 500) + PI / 2, global_rotation))
	
	#if arrow.visible and navigaton_enabled:
		#navigation_agent_2d.velocity = linear_velocity
		#arrow.global_rotation = global_position.angle_to(navigation_agent_2d.get_next_path_position())


func deactivate(cancel_signal := false) -> void:
	if deactivateable:
		super.deactivate(cancel_signal)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		reset()


func get_user_inputs() -> Array[float]:
	var inputs : Array[float] = []
	inputs.resize(4)
	inputs[UserInput.FORWARDS] = Input.get_action_strength("accelerate")
	inputs[UserInput.REVERSE] = Input.get_action_strength("decelerate")
	inputs[UserInput.TURN_LEFT] = Input.get_action_strength("turn_left")
	inputs[UserInput.TURN_RIGHT] = Input.get_action_strength("turn_right")
	return inputs



func get_throttle_input() -> float:
	return Input.get_axis("decelerate", "accelerate")

func get_steering_input() -> float:
	return Input.get_axis("turn_left", "turn_right")
