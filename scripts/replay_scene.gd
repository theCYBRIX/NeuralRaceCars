extends Node2D


signal car_instantiated(car : ReplayCar)
signal car_freed(car : ReplayCar)


const REPLAY_CAR = preload("res://scenes/replay_car.tscn")

@export var car_parent : Node
@export var replays : Dictionary : set = set_replays


var _replay_cars : Array[ReplayCar] = []


@onready var leaderboard: Leaderboard = $Leaderboard


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not car_parent:
		car_parent = self
	
	if _replay_cars.size() > 0:
		for car in _replay_cars:
			car_instantiated.emit(car)
	var training_replay_data : TrainingReplayData = ResourceLoader.load("C:/Users/math_/AppData/Roaming/Godot/app_userdata/CarGame/test(recording)(1).tres")
	var replays_dict := {}
	for i in range(training_replay_data.generations.size()):
		replays_dict[training_replay_data.generations[i]] = training_replay_data.replays[i]
	replays = replays_dict


func play() -> void:
	if replays.is_empty():
		return
	
	for car in _replay_cars:
		car_parent.add_child(car)
	
	for car in _replay_cars:
		car.start()


func pause() -> void:
	for car in _replay_cars:
		car.get_animation_player().pause()


func resume() -> void:
	for car in _replay_cars:
		car.get_animation_player().play()


func stop() -> void:
	for car in _replay_cars:
		car.get_animation_player().stop()


func _instantiate_replay_car(data : ReplayData) -> ReplayCar:
	var car : ReplayCar = REPLAY_CAR.instantiate()
	car.replay_data = data
	car_instantiated.emit(car)
	return car


func _instantiate_replay_cars() -> void:
	_replay_cars.resize(replays.size())
	var index : int = 0
	for batch in replays.values():
		for replay in batch:
			_replay_cars[index] = _instantiate_replay_car(replay)
			index += 1


func _free_replay_cars() -> void:
	for car in _replay_cars:
		car.queue_free()
		car_freed.emit(car)
	_replay_cars.clear()


func set_replays(value : Dictionary) -> void:
	replays = value
	_free_replay_cars()
	if replays:
		_instantiate_replay_cars()


func _on_car_instantiated(car: ReplayCar) -> void:
	if is_node_ready():
		leaderboard.add(car)


func _on_car_freed(car: ReplayCar) -> void:
	if is_node_ready():
		leaderboard.remove(car)


func _on_play_button_pressed() -> void:
	play()


func _on_quit_button_pressed() -> void:
	SceneManager.set_scene(SceneManager.Scene.MAIN_MENU)
