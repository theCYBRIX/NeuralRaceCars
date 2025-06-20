extends Node2D

@onready var binary_io_handler: Node = $NeuralAPIClient/BinaryIOHandler

@onready var evolution_manager: EvolutionManager = $NeuralAPIClient/EvolutionManager
@onready var neural_api_client: NeuralAPIClient = $NeuralAPIClient
@onready var camera_manager: CameraManager = $CameraManager
@onready var camera_reparent_cooldown: Timer = $CameraReparentCooldown
@onready var stat_screen: Control = $CanvasLayer/StatScreen
@onready var exit_dialog: ConfirmationDialog = $ExitDialog
@onready var leaderboard: Leaderboard = $Leaderboard
@onready var start_button: Button = $CanvasLayer/Control/MarginContainer/HBoxContainer/VBoxContainer/StartButton
@onready var network_layout_generator: NetworkLayoutGenerator = $NeuralAPIClient/NetworkLayoutGenerator

var total_generations : int = 0
var time_elapsed_int : int = 0

var since_randomized := 0.0
var since_randomized_int : int = 0

var first_place_car : NeuralCar

var previous_id_queue_index : int = 0

var best_network_id : int = -1
var first_place_score : float = 0

var camera_reparent_cooldown_active := false
var next_camera_target : NeuralCar
var next_camera_target_set_flag := false

var track : BaseTrack : set = set_track

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(false)
	get_tree().paused = true
	
	var car_childred := find_children("*", "Car", false)
	if not car_childred.is_empty():
		set_camera_target(car_childred.front())
	
	evolution_manager.car_respawned.connect(set_first_place_car, CONNECT_ONE_SHOT)
	
	evolution_manager.ready.connect(_on_evolution_manager_reset, CONNECT_ONE_SHOT)
	
	
	if GameSettings.network_layout:
		network_layout_generator.set_layout(GameSettings.network_layout)
		#print(JSON.stringify(network_layout_generator.create_network_layout().to_dict()))
	
	
	stat_screen.graph.add_series("Framerate (FPS)", Color.LIME_GREEN, Engine.get_frames_per_second)
	stat_screen.graph.add_series("Networks Alive (%)", Color.YELLOW_GREEN, func() -> float: return evolution_manager.active_cars.size() / float(evolution_manager.cars.size()))
	Performance.add_custom_monitor("game/networks_alive", func() -> int: return evolution_manager.active_cars.size())
	
	if binary_io_handler and binary_io_handler.Enabled:
		stat_screen.graph.add_series("API Average Response Time (ms)", Color.ORANGE, func() -> float: return binary_io_handler.GetAverageResponseTime())
		Performance.add_custom_monitor("time/api_response_time (ms)", func() -> float: return binary_io_handler.GetAverageResponseTime())
	else:
		stat_screen.graph.add_series("API Average Response Time (ms)", Color.ORANGE, neural_api_client.get_average_response_time)
		Performance.add_custom_monitor("time/api_response_time (ms)", neural_api_client.get_average_response_time)
	#stat_screen.graph.add_series("API Last Response Time", Color.YELLOW, neural_api_client.get_last_response_time)
	stat_screen.graph_2.add_series("Best Score", Color.SKY_BLUE, func() -> float: return evolution_manager.training_state.highest_score)
	Performance.add_custom_monitor("game/best_score", func() -> float: return evolution_manager.training_state.highest_score)
	stat_screen.graph_2.add_series("First Place Score", Color.DODGER_BLUE, update_first_place_score)
	Performance.add_custom_monitor("game/first_place_score", func() -> float: return first_place_score)


func _exit_tree() -> void:
	Performance.remove_custom_monitor("game/networks_alive")
	Performance.remove_custom_monitor("time/api_response_time (ms)")
	Performance.remove_custom_monitor("game/best_score")
	Performance.remove_custom_monitor("game/first_place_score")


func _process(delta: float) -> void:
	if get_tree().paused: return
	
	var floored := floori(evolution_manager.training_state.time_elapsed + delta)
	if floored > time_elapsed_int:
		time_elapsed_int = floored
		stat_screen.time_elapsed_label.set_text("Time elapsed: " + Util.format_time(time_elapsed_int))
	
	since_randomized += delta
	floored = floori(since_randomized)
	if floored > since_randomized_int:
		since_randomized_int = floored
		stat_screen.since_randomized_label.set_text("Since Last Randomized: " + Util.format_time(since_randomized_int))
	
	if previous_id_queue_index != evolution_manager.id_queue_index:
		stat_screen.batch_label.set_text("Progress: %d/%d (%d%%)" % [evolution_manager.id_queue_index, neural_api_client.training_network_ids.size(), (float(evolution_manager.id_queue_index) / neural_api_client.training_network_ids.size()) * 100] )
		previous_id_queue_index = evolution_manager.id_queue_index


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		match event.keycode:
			KEY_ESCAPE:
				if event.is_pressed():
					get_tree().paused = not get_tree().paused
			KEY_M:
				if event.is_pressed():
					stat_screen.visible = !stat_screen.visible
			_:
				return
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		match event.keycode:
			KEY_PERIOD:
				if event.is_pressed(): set_time_scale(Engine.time_scale + 0.25)
			KEY_COMMA:
				if event.is_pressed(): set_time_scale(Engine.time_scale - 0.25)
			KEY_SLASH:
				if event.is_pressed(): set_time_scale(1.0)
			KEY_SPACE:
				if event.is_pressed() and has_node("Car"):
					$Car.reset(BaseTrack.SpawnType.CLOSEST_POINT)
			_:
				return
		get_viewport().set_input_as_handled()


func update_first_place_score() -> float:
	var leader : Car = next_camera_target if next_camera_target_set_flag else first_place_car
	if leader:
		if leader is NeuralCar and leader.active:
			first_place_score = evolution_manager.get_reward(leader)
			evolution_manager.on_network_score_changed(first_place_score)
	elif has_node("Car"):
		leader = $Car
		first_place_score = track.get_progress(leader)
	
	return first_place_score


func _on_first_place_car_deactevated():
	camera_manager.stop_tracking()


func set_time_scale(time_scale : float):
	Engine.time_scale = time_scale
	Engine.max_physics_steps_per_frame = roundi(16 * time_scale)
	Engine.physics_ticks_per_second = roundi(60 * time_scale)
	print("Time Scale: ", Engine.time_scale)


func _on_evolution_manager_reset() -> void:
	var current_id_index := evolution_manager.id_queue_index
	var total_id_count := neural_api_client.training_network_ids.size()
	var gen_progress := (current_id_index / float(total_id_count)) * 100
	stat_screen.batch_label.set_text("Progress: %d/%d (%d%%)" % [ current_id_index, total_id_count, gen_progress] )


func _on_evolution_manager_new_generation(generation : int) -> void:
	total_generations += 1
	stat_screen.total_gens_label.set_text("Total Generations: " + str(total_generations))
	
	stat_screen.gen_label.set_text("Generation: " + str(generation))
	stat_screen.improvement_label.set_text("Gens without improvement: " + str(evolution_manager.gens_without_improvement))
	
	#TODO: Do properly
	if track and track.has_method("randomize_checkpoints"):
		track.randomize_checkpoints()


func _on_evolution_manager_networks_randomized() -> void:
	since_randomized = 0
	since_randomized_int = 0


func _on_stat_screen_save_button_pressed(save_path : String, network_count : int) -> void:
	evolution_manager.save_networks(save_path, network_count)


func set_track(instance : BaseTrack):
	track = instance
	
	if not track.is_node_ready():
		await track.ready
	
	for car : Car in find_children("*", "Car", false):
		car.track_path = car.get_path_to(track)
	


func set_first_place_car(car : NeuralCar):
	if best_network_id == car.id: return
	if first_place_car and first_place_car.deactivated.is_connected(_on_first_place_car_deactevated):
		first_place_car.deactivated.disconnect(_on_first_place_car_deactevated)
	first_place_car = car
	best_network_id = car.id
	first_place_car.deactivated.connect(_on_first_place_car_deactevated, CONNECT_ONE_SHOT)
	camera_manager.start_tracking(first_place_car)


func update_first_place_car():
	best_network_id = -1
	set_first_place_car.call_deferred($Leaderboard.leaderboard.back())
	return


func set_camera_target(target : Node):
	if camera_reparent_cooldown_active:
		next_camera_target = target
		next_camera_target_set_flag = true
		#print("target queued")
	else:
		#print("new target")
		camera_manager.start_tracking(target)
		start_camrera_reparent_cooldown()


func exit() -> void:
	get_tree().set_deferred("paused", false)
	get_tree().change_scene_to_packed(SceneManager.get_packed(SceneManager.Scene.MAIN_MENU))


func _on_camera_reparent_cooldown_timeout() -> void:
	camera_reparent_cooldown_active = false
	if next_camera_target_set_flag:
		next_camera_target_set_flag = false
		set_camera_target(next_camera_target)


func start_camrera_reparent_cooldown():
	camera_reparent_cooldown_active = true
	camera_reparent_cooldown.start()


func _on_leaderboard_first_place_changed(new_first: Car, _prev_first: Car) -> void:
	set_first_place_car(new_first)


func _on_track_provider_track_updated(new_track: BaseTrack) -> void:
	track = new_track
	$Leaderboard.track = track


func _on_start_button_pressed() -> void:
	start_button.disabled = true
	get_tree().paused = false
	evolution_manager.start_training()
	start_button.disabled = false


func _on_exit_button_pressed() -> void:
	exit_dialog.popup_on_parent(Rect2i(get_window().size / 2 - exit_dialog.min_size / 2, exit_dialog.min_size))


func _on_exit_dialog_confirmed() -> void:
	exit()


func _on_stat_screen_exit_button_pressed() -> void:
	exit()


func _on_evolution_manager_car_instanciated(car: NeuralCar) -> void:
	leaderboard.add(car)


func _on_evolution_manager_training_started() -> void:
	start_button.hide()
	set_process(true)


func _on_evolution_manager_training_state_refreshed(training_state: TrainingState) -> void:
	time_elapsed_int = floori(training_state.time_elapsed)
	since_randomized = training_state.time_elapsed
	since_randomized_int = time_elapsed_int
	total_generations = training_state.generation


func _on_evolution_manager_metadata_updated(metadata_tracker: MetadataTracker) -> void:
	for type_name : String in metadata_tracker.types.keys():
		if not stat_screen.manual_graph.has_series(type_name) :
			stat_screen.manual_graph.add_series(type_name, get_series_color(stat_screen.manual_graph.get_series_count()), metadata_tracker.types[type_name].get_average)
		if not stat_screen.manual_graph_2.has_series(type_name) :
			stat_screen.manual_graph_2.add_series(type_name, get_series_color(stat_screen.manual_graph_2.get_series_count()), metadata_tracker.types[type_name].get_top_average.bind(0.05))
	
	stat_screen.manual_graph.update_all()
	stat_screen.manual_graph_2.update_all()


func get_series_color(index: int) -> Color:
	var predefined_colors := [
		Color(0.22, 0.49, 0.72), # Blue
		Color(0.89, 0.29, 0.20), # Red
		Color(0.30, 0.68, 0.29), # Green
		Color(0.60, 0.40, 0.80), # Purple
		Color(1.00, 0.60, 0.00), # Orange
		Color(0.20, 0.70, 0.75), # Teal
		Color(0.95, 0.77, 0.06)  # Yellow
	]
	
	if index < predefined_colors.size():
		return predefined_colors[index]
	else:
		# Generate appealing random color using HSV
		var hue := randf() # 0 to 1
		var saturation := 0.6 + randf() * 0.4 # 0.6 to 1
		var value := 0.7 + randf() * 0.3 # 0.7 to 1
		return Color.from_hsv(hue, saturation, value)
