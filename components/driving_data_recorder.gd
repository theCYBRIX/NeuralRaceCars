@tool

class_name DrivingDataRecorder
extends Node

const DRIVING_DATA_PATH := "user://resources/driving_data.tres"

@export var target_car : NeuralCar
@export var autostart : bool

var driving_data : DrivingData

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if ResourceLoader.exists(DRIVING_DATA_PATH):
		driving_data = ResourceLoader.load(DRIVING_DATA_PATH)
	if not driving_data: driving_data = DrivingData.new()
	set_process(autostart)


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()
	
	var parent = get_parent()
	if parent is NeuralCar:
		target_car = parent

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if target_car.active and target_car.speed > 10:
		driving_data.record(target_car.get_sensor_data(), target_car.get_user_inputs())


func _input(event: InputEvent) -> void:
	#if event is InputEventKey:
		#if event.is_pressed():
			#if event.as_text_keycode() == "T":
				#save()
	if event.is_action_type():
		if event.is_action_pressed("recording_start"):
			start()
		if event.is_action_pressed("recording_stop"):
			stop()
		if event.is_action_pressed("recording_reset"):
			reset()


func reset():
	driving_data.clear()
	print("Recording Reset.")


func start():
	set_process(true)
	print("Recording Started...")


func stop():
	set_process(false)
	print("Recording Stopped.")


func save():
	var error := ResourceSaver.save(driving_data, DRIVING_DATA_PATH)
	if error != OK:
		printerr("Failed to save: " + error_string(error))
	else:
		print("Saved!! >.<")


func _get_configuration_warnings() -> PackedStringArray:
	var warnings : PackedStringArray = []
	if not get_parent() is NeuralCar:
		warnings.append("Parent must be of type NeuralCar.")
	return warnings
