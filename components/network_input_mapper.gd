extends Node

enum InputProperty {
	SPEED,
	SLIP_ANGLE,
	ANGULAR_VELOCITY,
	SENSOR_DATA,
	VEL_TO_TRACK_ALIGNMENT_ANGLE,
}

@export var car : NeuralCar : set = set_car
@export var input_properties : Array[InputProperty] : set = set_inputs

var _inputs_array := PackedFloat64Array()
var _input_callables : Array[Callable] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func get_inputs_array() -> PackedFloat64Array:
	var index : int = 0
	for callable in _input_callables:
		var value = callable.call()
		if value is PackedFloat64Array or value is PackedFloat32Array or value is Array:
			for i in value:
				_inputs_array[index] = i
				index += 1
		else:
			_inputs_array[index] = value
			index += 1
	return _inputs_array


func _update_input_callables() -> void:
	_input_callables.resize(input_properties.size())
	var index : int = 0
	for property in input_properties:
		match property:
			InputProperty.SPEED:
				_input_callables[index] = get_normalized_speed
			InputProperty.SLIP_ANGLE:
				_input_callables[index] = get_slip_angle
			InputProperty.ANGULAR_VELOCITY:
				_input_callables[index] = get_angular_velocity
			InputProperty.SENSOR_DATA:
				_input_callables[index] = get_sensor_readings
			InputProperty.VEL_TO_TRACK_ALIGNMENT_ANGLE:
				_input_callables[index] = get_velocity_to_track_alignment_angle
		index += 1


func get_normalized_speed() -> float:
	if not car.moving:
		return 0
	elif car.moving_forwards:
		return car.speed / car.max_forward_speed
	else:
		return -(car.speed / car.max_reverse_speed)


func get_sensor_readings() -> PackedFloat64Array:
	return car.sensors.get_sensor_readings()


func get_angular_velocity() -> float:
	return car.angular_velocity / (PI * 2)


func get_slip_angle() -> float:
	return car.get_slip_angle() / PI


func get_velocity_to_track_alignment_angle() -> float:
	return angle_difference(get_track_direction(), car.global_rotation)


func get_track_direction() -> float:
	return car.get_node(car.track_path).get_track_direction(car.global_position, 500)


func get_input_count() -> int:
	var num_inputs : int = 0
	for property in input_properties:
		match property:
			InputProperty.SPEED, InputProperty.SLIP_ANGLE, InputProperty.ANGULAR_VELOCITY, InputProperty.VEL_TO_TRACK_ALIGNMENT_ANGLE:
				num_inputs += 1
			InputProperty.SENSOR_DATA:
				num_inputs += car.sensors.get_sensor_count()
	return num_inputs

func set_inputs(array : Array[InputProperty]) -> void:
	input_properties = array if array else []
	_update_internals()


func _update_input_count() -> void:
	if car and car.is_node_ready():
		_inputs_array.resize(get_input_count())


func _update_internals() -> void:
	_update_input_count()
	_update_input_callables()


func set_car(c : NeuralCar) -> void:
	car = c
	if car:
		car.ready.connect(_update_input_count, CONNECT_ONE_SHOT)


#func get_inputs_array_direct() -> PackedFloat64Array:
	#var index : int = 0
	#for property in input_properties:
		#match property:
			#InputProperty.SPEED:
				#_inputs_array[index] = get_normalized_speed()
				#index += 1
			#InputProperty.SLIP_ANGLE:
				#_inputs_array[index] = get_slip_angle()
				#index += 1
			#InputProperty.ANGULAR_VELOCITY:
				#_inputs_array[index] = get_angular_velocity()
				#index += 1
			#InputProperty.SENSOR_DATA:
				#for reading in get_sensor_readings():
					#_inputs_array[index] = reading
					#index += 1
			#InputProperty.VEL_TO_TRACK_ALIGNMENT_ANGLE:
				#_inputs_array[index] = get_velocity_to_track_alignment_angle()
				#index += 1
	#return _inputs_array
