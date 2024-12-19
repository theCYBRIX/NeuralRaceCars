class_name NeuralCar
extends Car

signal deactivated
signal checkpoint_updated(idx : int)

const STEERING_NODE = 0
const THROTTLE_NODE = 1

@onready var sensors: Node2D = $Sensors
@onready var checkpoint_timer: Timer = $CheckpointTimer
@onready var lifetime_timer: Timer = $LifetimeTimer
@onready var label: Label = $Label

@export var num_network_inputs : int = 15

var id : int
var active : bool = true
var final_pos : Vector2 = Vector2.ZERO
var final_rotation : float = 0

var checkpoint_index : int = -1 : set = set_checkpoint

var steering_input : float
var throttle_input : float

var frames_stationary : int = 0

var speed_sum : float = 0
var speed_sum_ticks : int = 0

var sensor_list : Array[RayCast2D] = []

var inputs : Array[float]

var reset_marker : Marker2D

func _ready() -> void:
	super._ready()
	
	inputs = []
	inputs.resize(num_network_inputs)
	
	sensor_list.clear()
	for anchor : Node2D in sensors.get_children():
		for sensor : RayCast2D in anchor.get_children():
			sensor_list.append(sensor)
	
	if reset_marker: reset(reset_marker)

func _process(delta: float) -> void:
	super._process(delta)
	label.rotation = -global_rotation
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

#func _physics_process(delta: float) -> void:
	#super._physics_process(delta)
	#
	#if get_contact_count() > 0:
		#deactivate()
		#pass

func deactivate():
	checkpoint_timer.stop()
	lifetime_timer.stop()
	active = false
	set_physics_process(false)
	set_process(false)
	final_pos = Vector2(global_position)
	final_rotation = global_rotation
	deactivated.emit()


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


func get_sensor_data() -> Array[float]:

	var index : int = -1
	
	if moving_forwards:
		index += 1
		inputs[index] = linear_velocity.length() / max_forward_speed
		#index += 1
		#inputs[index] = linear_velocity.angle() - rotation
	elif moving:
		index += 1
		inputs[index] = -(linear_velocity.length() / max_reverse_speed)
		#index += 1
		#inputs[index] = linear_velocity.angle() - rotation
	else:
		index += 1
		inputs[index] = 0
		#index += 1
		#inputs[index] = 0
	
	index += 1
	inputs[index] = angular_velocity / PI
	index += 1
	inputs[index] = rotation

	for sensor : RayCast2D in sensor_list:
		index += 1
		if sensor.is_colliding():
			inputs[index] = sensor.get_collision_point().distance_squared_to(sensor.global_position) / sensor.target_position.length_squared()
		else:
			inputs[index] = 1
	return inputs


func checkpoint():
	checkpoint_index += 1
	#score += ((speed_sum / speed_sum_ticks) / max_forward_speed) * 5
	#reset_speed_recording()
	checkpoint_timer.start(0)


func get_average(array : Array[float]) -> float:
	var average : float = 0
	for s : float in array:
		average += s
	average /= array.size()
	return average

func reset_speed_recording():
	speed_sum = 0
	speed_sum_ticks = 0

func reset(location : Marker2D):
	if not is_node_ready():
		reset_marker = location
		return
	steering_input = 0
	throttle_input = 0
	checkpoint_index = -1
	frames_stationary = 0
	super.reset(location)
	active = true
	reset_speed_recording()
	set_physics_process(true)
	set_process(true)
	checkpoint_timer.start()
	lifetime_timer.start()

func _on_checkpoint_timer_timeout() -> void:
	deactivate()

func _on_lifetime_timer_timeout() -> void:
	deactivate()

func set_checkpoint(idx : int):
	if idx == checkpoint_index: return
	checkpoint_index = idx
	checkpoint_updated.emit(checkpoint_index)
