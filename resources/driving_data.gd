class_name DrivingData
extends Resource


@export var map : Dictionary = {}

var inputs : Array
var outputs : Array


func record(sensor_data : Array, user_input : Array):
	map[sensor_data] = user_input

func clear():
	map.clear()

func convert():
	inputs = map.keys()
	outputs = map.values()
