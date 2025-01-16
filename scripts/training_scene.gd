extends Node2D

@onready var evolution_manager: EvolutionManager = $NeuralAPIClient/EvolutionManager
@onready var neural_api_client: NeuralAPIClient = $NeuralAPIClient
@onready var camera_manager: CameraManager = $CameraManager
@onready var camera_reparent_cooldown: Timer = $CameraReparentCooldown
@onready var stat_screen: Control = $CanvasLayer/StatScreen
@onready var exit_dialog: ConfirmationDialog = $ExitDialog
@onready var leaderboard: Leaderboard = $Leaderboard

@export var training_state : TrainingState : set = set_training_state
@export var use_saved_training_state := true
@export_global_file("*.json", "*.res", "*.tres") var training_state_path := SaveManager.DEFAULT_SAVE_FILE_PATH

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

func _init() -> void:
	if GameSettings.training_state:
		training_state = GameSettings.training_state
		
	elif use_saved_training_state:
		training_state = SaveManager.load_training_state(training_state_path)
		if training_state:
			var error : Error = SaveManager.get_load_error()
			push_warning("Unable to load training state: ", training_state_path, "\nReason: ", error_string(error))
			training_state = TrainingState.new()
		
	elif not training_state:
		training_state = TrainingState.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	assert(training_state != null)
	
	var car_childred := find_children("*", "Car", false)
	if not car_childred.is_empty():
		set_camera_target(car_childred.front())
	
	evolution_manager.initial_networks = training_state.networks
	evolution_manager.generation = training_state.generation
	evolution_manager.car_respawned.connect(set_first_place_car, CONNECT_ONE_SHOT)
	
	evolution_manager.ready.connect(_on_neural_car_manager_reset, CONNECT_ONE_SHOT)
	
	stat_screen.graph.add_series("Framerate (FPS)", Color.LIME_GREEN, Engine.get_frames_per_second)
	stat_screen.graph.add_series("Networks Alive (%)", Color.YELLOW_GREEN, func(): return evolution_manager.active_cars.size() / float(evolution_manager.cars.size()))
	stat_screen.graph_2.add_series("Best Score", Color.SKY_BLUE, func(): return evolution_manager.highest_score)
	stat_screen.graph_2.add_series("First Place Score", Color.DODGER_BLUE, update_first_place_score)


func _process(delta: float) -> void:
	if get_tree().paused: return
	
	training_state.time_elapsed += delta
	var floored := floori(training_state.time_elapsed)
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
		first_place_score = track.get_absolute_progress(leader.global_position, leader.checkpoint_index)
			
	return first_place_score


func _on_first_place_car_deactevated():
	camera_manager.stop_tracking()


func set_time_scale(time_scale : float):
	Engine.time_scale = time_scale
	Engine.max_physics_steps_per_frame = roundi(16 * time_scale)
	Engine.physics_ticks_per_second = roundi(60 * time_scale)
	print("Time Scale: ", Engine.time_scale)


func _on_neural_car_manager_reset() -> void:
	var current_id_index := evolution_manager.id_queue_index
	var total_id_count := neural_api_client.training_network_ids.size()
	var gen_progress := (current_id_index / float(total_id_count)) * 100
	stat_screen.batch_label.set_text("Progress: %d/%d (%d%%)" % [ current_id_index, total_id_count, gen_progress] )


func _on_car_manager_new_generation(generation : int) -> void:
	total_generations += 1
	stat_screen.total_gens_label.set_text("Total Generations: " + str(total_generations))
	
	training_state.generation = generation
	stat_screen.gen_label.set_text("Generation: " + str(generation))
	stat_screen.improvement_label.set_text("Gens without improvement: " + str(evolution_manager.gens_without_improvement))


func _on_neural_car_manager_networks_randomized() -> void:
	since_randomized = 0
	since_randomized_int = 0


func _on_stat_screen_save_button_pressed(save_path : String) -> void:
	training_state.networks = await evolution_manager.get_best_networks(min(200, evolution_manager.num_networks))
	training_state.highest_score = evolution_manager.highest_score
	
	var error := SaveManager.save_training_state(training_state, save_path)
	if error != OK:
		push_warning("Failed to save state. Reason: ", error_string(error))
	#await evolution_manager.save_networks(save_path, min(200, evolution_manager.num_networks), true)


func set_track(instance : BaseTrack):
	track = instance
	
	if not track.is_node_ready():
		await track.ready
	
	for car : Car in find_children("*", "Car", false):
		car.track_path = car.get_path_to(track)


func set_training_state(state : TrainingState):
	if not state: state = TrainingState.new()
	training_state = state
	
	time_elapsed_int = floori(training_state.time_elapsed)
	since_randomized = training_state.time_elapsed
	since_randomized_int = time_elapsed_int
	total_generations = training_state.generation
	
	if not is_node_ready(): return
	
	evolution_manager.initial_networks = training_state.networks
	evolution_manager.generation = training_state.generation
	if neural_api_client.is_node_ready():
		var io_handler := neural_api_client.io_handler
		if io_handler and evolution_manager.api_configured:
			io_handler.stop()
			evolution_manager.api_configured = false
			io_handler.start()


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
	set_first_place_car($Leaderboard.leaderboard.back())
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
	get_tree().change_scene_to_packed(SceneManager.get_packed(SceneManager.Scene.MAIN_MENU))


func _on_camera_reparent_cooldown_timeout() -> void:
	camera_reparent_cooldown_active = false
	if next_camera_target_set_flag:
		next_camera_target_set_flag = false
		set_camera_target(next_camera_target)


func start_camrera_reparent_cooldown():
	camera_reparent_cooldown_active = true
	camera_reparent_cooldown.start()


func _on_leaderboard_first_place_changed(new_first: Car, prev_first: Car) -> void:
	set_first_place_car(new_first)


func _on_track_provider_track_updated(new_track: BaseTrack) -> void:
	track = new_track


func _on_start_button_pressed() -> void:
	evolution_manager.start_training()


func _on_exit_button_pressed() -> void:
	exit_dialog.popup_on_parent(Rect2i(get_window().size / 2 - exit_dialog.min_size / 2, exit_dialog.min_size))


func _on_exit_dialog_confirmed() -> void:
	exit()


func _on_stat_screen_exit_button_pressed() -> void:
	exit()


func _on_evolution_manager_car_instanciated(car: NeuralCar) -> void:
	leaderboard.add(car)
