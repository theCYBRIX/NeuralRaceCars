extends Node2D

var sensor_list : Array[RayCast2D] = []

func _ready() -> void:
	sensor_list.clear()
	for anchor : Node2D in get_children():
		for sensor : RayCast2D in anchor.get_children():
			sensor_list.append(sensor)


func get_sensor_readings() -> PackedFloat64Array:
	var readings : PackedFloat64Array = []
	readings.resize(sensor_list.size())
	var index : int = -1
	for sensor : RayCast2D in sensor_list:
		index += 1
		if sensor.is_colliding():
			readings[index] = sensor.get_collision_point().distance_squared_to(sensor.global_position) / sensor.target_position.length_squared()
		else:
			readings[index] = 1
	return readings
