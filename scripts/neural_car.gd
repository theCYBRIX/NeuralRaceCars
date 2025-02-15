class_name NeuralCar
extends Car

signal deactivated

var id : int
var active : bool = false : set = set_active
var final_pos : Vector2 = Vector2.ZERO
var final_rotation : float = 0

#var frames_stationary : int = 0

var speed_sum : float = 0
var speed_sum_ticks : int = 0

var reset_marker : Marker2D

var score_adjustment : float = 0

var deactivate_on_contact := true : set = set_deactivate_on_contact

@onready var sensors: Node2D = $Sensors
var input_mapper := NetworkInputMapper.new()
var output_interpreter := NetworkOutputInterpreter.new()

func _init() -> void:
	add_child(input_mapper, false, INTERNAL_MODE_FRONT)
	add_child(output_interpreter, false, INTERNAL_MODE_FRONT)


#func _process(delta: float) -> void:
	#super._process(delta)
	
	#if (not moving_forwards) and speed > 20: score -= 0.1
	#speed_sum += speed
	#speed_sum_ticks += 1
	
	#print(get_sensor_data())


func get_steering_input() -> float:
	#return super.get_steering_input()
	return output_interpreter.steering_input


func get_throttle_input() -> float:
	#return super.get_throttle_input()
	return output_interpreter.throttle_input


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if deactivate_on_contact and get_contact_count() > 0:
		deactivate()
		#score_adjustment -= 0.1 * delta
		pass


func deactivate(emit_signal := true) -> void:
	if not active:
		return
	active = false
	final_pos = Vector2(global_position)
	final_rotation = global_rotation
	if emit_signal:
		deactivated.emit()


func set_active(enabled : bool = true) -> void:
	active = enabled
	set_physics_process(active)
	set_process(active)


func get_network_inputs() -> PackedFloat64Array:
	return input_mapper.update_inputs()


func handle_network_outputs(outputs : Array) -> void:
	output_interpreter.interpret_network_outputs(outputs)


func get_normalized_speed() -> float:
	if not moving:
		return 0
	elif moving_forwards:
		return speed / max_forward_speed
	else:
		return -(speed / max_reverse_speed)


func get_average(array : Array[float]) -> float:
	var average : float = 0
	for s : float in array:
		average += s
	average /= array.size()
	return average


func reset_speed_recording():
	speed_sum = 0
	speed_sum_ticks = 0


func reset(spawn_type := BaseTrack.SpawnType.TRACK_START):
	output_interpreter.reset()
	#frames_stationary = 0
	score_adjustment = 0
	await super.reset(spawn_type)
	reset_speed_recording()
	active = true


func respawn(pos : Vector2, angle : float) -> void:
	_set_position_and_rotation(pos, angle)
	respawned.emit()


func set_deactivate_on_contact(enabled := true):
	deactivate_on_contact = enabled
