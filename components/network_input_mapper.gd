extends Node

enum InputProperty {
	SPEED,
	SLIP_ANGLE,
	ANGULAR_VELOCITY,
	SENSOR_DATA,
	MAP_DIRECTION,
}

@export var car : NeuralCar : set = set_car
@export var inputs : Array[InputProperty] : set = set_inputs

var _inputs_array := PackedFloat64Array()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func get_inputs_array() -> PackedFloat64Array:
	var index : int = 0
	for property in inputs:
		match property:
			InputProperty.SPEED:
				_inputs_array[index] = get_normalized_speed()
				index += 1
			InputProperty.SLIP_ANGLE:
				_inputs_array[index] = car.get_slip_angle() / PI
				index += 1
			InputProperty.ANGULAR_VELOCITY:
				_inputs_array[index] = car.angular_velocity / (PI * 2)
				index += 1
			InputProperty.SENSOR_DATA:
				for reading in get_sensor_readings():
					_inputs_array[index] = reading
					index += 1
			InputProperty.MAP_DIRECTION:
				_inputs_array[index] = car.get_node(car.track_path).get_track_direction(car.global_position, 500)
				index += 1
	return _inputs_array


func get_normalized_speed() -> float:
	if not car.moving:
		return 0
	elif car.moving_forwards:
		return car.speed / car.max_forward_speed
	else:
		return -(car.speed / car.max_reverse_speed)


func get_sensor_readings() -> PackedFloat64Array:
	return car.sensors.get_sensor_readings()


func get_input_count() -> int:
	var num_inputs : int = 0
	for property in inputs:
		match property:
			InputProperty.SPEED, InputProperty.SLIP_ANGLE, InputProperty.ANGULAR_VELOCITY, InputProperty.MAP_DIRECTION:
				num_inputs += 1
			InputProperty.SENSOR_DATA:
				num_inputs += car.sensors.get_sensor_count()
	return num_inputs

func set_inputs(array : Array[InputProperty]) -> void:
	inputs = array if array else []
	_update_input_count()


func _update_input_count() -> void:
	if car and car.is_node_ready():
		_inputs_array.resize(get_input_count())


func set_car(c : NeuralCar) -> void:
	car = c
	if car:
		car.ready.connect(_update_input_count, CONNECT_ONE_SHOT)
