class_name NeuralCar
extends Car

signal deactivated

@export var num_network_inputs : int = 15

var id : int
var active : bool = false : set = set_active
var final_pos : Vector2 = Vector2.ZERO
var final_rotation : float = 0

var steering_input : float
var throttle_input : float

#var frames_stationary : int = 0

var speed_sum : float = 0
var speed_sum_ticks : int = 0

var inputs : PackedFloat64Array

var reset_marker : Marker2D

var score_adjustment : float = 0

var deactivate_on_contact := true : set = set_deactivate_on_contact

@onready var sensors: Node2D = $Sensors
@onready var input_mapper: Node = $InputMapper

func _init() -> void:
	inputs = PackedFloat64Array()
	inputs.resize(num_network_inputs)


#func _process(delta: float) -> void:
	#super._process(delta)
	
	#if (not moving_forwards) and speed > 20: score -= 0.1
	#speed_sum += speed
	#speed_sum_ticks += 1
	
	#print(get_sensor_data())


func get_steering_input() -> float:
	#return super.get_steering_input()
	return steering_input


func get_throttle_input() -> float:
	#return super.get_throttle_input()
	return throttle_input


func set_steering_input(input : float) -> void:
	#if steering_input == input:
		#if active: score += 0.01
	#else:
	steering_input = input


func set_throttle_input(input : float) -> void:
	#if throttle_input == input:
		#if active: score += 0.05
	#else:
	throttle_input = input


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



func interpret_model_outputs(outputs : Array):
	var forwards : float = clampf(outputs[0], 0, 1)
	var backwards : float = clampf(outputs[1], 0, 1)
	var turn_left : float = clampf(outputs[3], 0, 1)
	var turn_right : float = clampf(outputs[2], 0, 1)
	
	if (forwards < 0.5 and backwards < 0.5) or is_equal_approx(forwards, backwards):
		throttle_input = 0
	else:
		throttle_input = 1 if forwards > backwards else -1
	
	if turn_left < 0.5 and turn_right < 0.5:
		steering_input = 0
	else:
		steering_input = 1 if turn_right > turn_left else -1
	
	
	#throttle_input = forwards if forwards > backwards else -backwards
	#steering_input = turn_right if turn_right > turn_left else -turn_left
		
	#throttle_input = get_input_axis(forwards, backwards)
	#steering_input = get_input_axis(turn_right, turn_left)
	
	#var acceleration : float = clampf(outputs[0], -1, 1)
	#var turning : float = clampf(outputs[1], -1, 1)
		#
	#throttle_input = acceleration
	#steering_input = turning
	
	#print(outputs)


func get_sensor_data() -> PackedFloat64Array:
	return inputs


func update_sensor_data() -> void:
	inputs = input_mapper.get_inputs_array()
	
	#var index : int = -1
	#
	#index += 1
	#inputs[index] = get_normalized_speed()
	#
	#index += 1
	#inputs[index] = angular_velocity / PI
	#index += 1
	#inputs[index] = rotation
#
	#for reading in sensors.get_sensor_readings():
		#index += 1
		#inputs[index] = reading
	


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
	steering_input = 0
	throttle_input = 0
	#frames_stationary = 0
	score_adjustment = 0
	await super.reset(spawn_type)
	reset_speed_recording()
	active = true


func respawn(pos : Vector2, angle : float) -> void:
	_set_position_and_rotation(pos, angle)
	update_sensor_data()
	respawned.emit()


func set_deactivate_on_contact(enabled := true):
	deactivate_on_contact = enabled
