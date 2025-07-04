extends Node

signal car_settings_changed(settings : CarSettings)

var training_state : TrainingState
var track_path : String = "res://scenes/track_2.tscn"
var network_layout : NetworkLayout = null
var car_settings : CarSettings = CarSettings.new()

func get_track() -> PackedScene:
	return ResourceLoader.load(track_path)


func _on_car_settings_changed() -> void:
	car_settings_changed.emit(car_settings)


func set_car_settings(settings : CarSettings) -> void:
	if car_settings:
		Util.disconnect_from_signal(_on_car_settings_changed, car_settings.changed)
	car_settings = settings
	if car_settings:
		car_settings.changed.connect(_on_car_settings_changed)
