extends Node2D

const PLAYER_CAR = preload("res://scenes/car.tscn")

@export var include_player := true

@onready var pause_menu: Control = $CanvasLayer/PauseMenu
@onready var track_provider: TrackProvider = $TrackProvider
@onready var camera_manager: CameraManager = $CameraManager
@onready var neural_car_manager: NeuralCarManager = $NeuralAPIClient/NeuralCarManager
@onready var neural_api_client: NeuralAPIClient = $NeuralAPIClient
@onready var graph: DataGraph = $CanvasLayer/Graph

var _player : Car

func _ready() -> void:
	if include_player and not _player and track_provider and track_provider.has_track():
		spawn_player()
	
	var state : TrainingState = SaveManager.load_training_state("C:\\Users\\math_\\AppData\\Roaming\\Godot\\app_userdata\\CarGame\\saved_networks(18 - 3.89).json")
	
	if not neural_api_client.is_node_ready():
		await neural_api_client.ready
	if not neural_api_client.io_handler.is_node_ready():
		await neural_api_client.io_handler.ready
	
	#neural_api_client.start()
	#await get_tree().create_timer(2).timeout
	#
	#neural_api_client.add_networks(state.networks)
	#var num_cars := 25
	#neural_car_manager.num_cars = num_cars
	#for id in neural_api_client.simulation_network_ids.slice(0, num_cars):
		#neural_car_manager.activate_neural_car(id)
	#
	#graph.add_series("FPS", Color.WEB_GREEN, Engine.get_frames_per_second)
	##graph.add_series("Networks Alive", Color.YELLOW, func(): return neural_car_manager.active_cars.size())
	#
	#neural_car_manager.set_deactivate_on_contact(false)


func _unhandled_key_input(event: InputEvent) -> void:
	match event.keycode:
		KEY_ESCAPE:
			if event.is_pressed() and not event.is_echo():
				pause()


func _on_track_provider_track_updated(track: BaseTrack) -> void:
	if is_node_ready() and include_player:
		spawn_player()


func spawn_player() -> void:
	if _player:
		_player.queue_free()
	if not track_provider:
		push_error("Unable to spawn player: TrackProvider is null.")
		return
	
	_player = PLAYER_CAR.instantiate()
	_player.track_path = ".."
	_player.set_body_color(Color.DARK_RED)
	track_provider.track.add_child(_player)
	#camera_manager.start_tracking(_player)
	$Camera2D.target = _player
	$Camera2D.start()


func pause():
	set_paused(true)


func resume():
	set_paused(false)


func set_paused(enabled : bool):
	get_tree().paused = enabled
	pause_menu.visible = enabled


func _on_resume_button_pressed() -> void:
	resume()


func _on_quit_button_pressed() -> void:
	get_tree().set_deferred("paused", false)
	get_tree().change_scene_to_packed(SceneManager.get_packed(SceneManager.Scene.MAIN_MENU))
