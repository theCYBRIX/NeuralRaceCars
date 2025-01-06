extends Node2D



@onready var neural_car_manager: NeuralCarManager = $NeuralAPIClient/NeuralCarManager
@onready var neural_api_client: NeuralAPIClient = $NeuralAPIClient
@onready var gen_label: Label = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/PanelContainer/MarginContainer/VBoxContainer/GenLabel
@onready var batch_label: Label = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/PanelContainer/MarginContainer/VBoxContainer/BatchLabel
@onready var graph: Control = $CanvasLayer/StatScreen/MarginContainer/Columns/VBoxContainer/HBoxContainer/ScrollContainer2/Items/Graph
@onready var camera_manager: CameraManager = $CameraManager
@onready var camera_reparent_cooldown: Timer = $CameraReparentCooldown
@onready var stat_screen: Control = $CanvasLayer/StatScreen
@onready var popout_component: Node = $CanvasLayer/StatScreen/PopoutComponent
@onready var popout_button: Button = $CanvasLayer/StatScreen/MarginContainer/Columns/VBoxContainer/HBoxContainer/VFlowContainer/PopoutButton
@onready var pause_button: Button = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/VBoxContainer/ButtonRow/PauseButton
@onready var save_path_edit: LineEdit = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/VBoxContainer/HBoxContainer/SavePathEdit
@onready var improvement_label: Label = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/PanelContainer/MarginContainer/VBoxContainer/ImprovementLabel
@onready var since_randomized_label: Label = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/PanelContainer/MarginContainer/VBoxContainer/SinceRandomizedLabel
@onready var browse_button: Button = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/VBoxContainer/HBoxContainer/BrowseButton
@onready var color_rect_2: ColorRect = $CanvasLayer/StatScreen/ColorRect2
@onready var exit_dialog: ConfirmationDialog = $ExitDialog

@onready var time_elapsed_label: Label = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/PanelContainer2/MarginContainer/VBoxContainer/TimeElapsedLabel
@onready var total_gens_label: Label = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/PanelContainer2/MarginContainer/VBoxContainer/TotalGensLabel


@export var track_scene : PackedScene
@export var training_state : TrainingState : set = set_training_state
@export var use_saved_training_state := true
@export_global_file("*.json", "*.res", "*.tres") var training_state_path := SaveManager.DEFAULT_SAVE_FILE_PATH


var highest_checkpoint : int = 0

var total_generations : int = 0
var time_elapsed_int : int = 0

var since_randomized := 0.0
var since_randomized_int : int = 0

var first_place_car : NeuralCar

var track : BaseTrack

var paused := false

var previous_id_queue_index : int = 0

var best_network_id : int = -1
var first_place_score : float = 0

var camera_reparent_cooldown_active := false
var next_camera_target : NeuralCar
var next_camera_target_set_flag := false


func _enter_tree() -> void:
	if GameSettings.track_scene:
		track_scene = GameSettings.track_scene
	
	track = track_scene.instantiate()
	add_child(track, false, Node.INTERNAL_MODE_FRONT)
	track.car_entered_checkpoint.connect(_on_car_entered_checkpoint.bind())
	track.car_entered_slow_zone.connect(reward_slow.bind())
	track.car_exited_slow_zone.connect(reward_slow.bind())

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
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
	
	assert(training_state != null)
	
	neural_car_manager.initial_networks = training_state.networks
	neural_car_manager.generation = training_state.generation
	
	neural_car_manager.track = track
	set_first_place_car(neural_car_manager.cars[0])
	
	save_path_edit.text = SaveManager.DEFAULT_SAVE_FILE_PATH
	
	neural_car_manager.ready.connect(_on_neural_car_manager_reset, CONNECT_ONE_SHOT)
	
	graph.add_series("First Place Score", Color.DODGER_BLUE, update_first_place_score)
	graph.add_series("Best Score", Color.SKY_BLUE, func(): return neural_car_manager.highest_score)
	graph.add_series("Networks Alive (%)", Color.YELLOW_GREEN, func(): return neural_car_manager.cars_active / float(neural_car_manager.cars.size()))
	graph.add_series("Framerate (FPS)", Color.LIME_GREEN, Engine.get_frames_per_second)


func _process(delta: float) -> void:
	
	training_state.time_elapsed += delta
	var floored := floori(training_state.time_elapsed)
	if floored > time_elapsed_int:
		time_elapsed_int = floored
		time_elapsed_label.set_text("Time elapsed: " + CommonTools.format_time(time_elapsed_int))
	
	since_randomized += delta
	floored = floori(since_randomized)
	if floored > since_randomized_int:
		since_randomized_int = floored
		since_randomized_label.set_text("Since Last Randomized: " + CommonTools.format_time(since_randomized_int))
	
	if neural_car_manager.dynamic_batch and previous_id_queue_index != neural_car_manager.id_queue_index:
		batch_label.set_text("Progress: %d/%d (%d%%)" % [neural_car_manager.id_queue_index, neural_car_manager.network_ids.size(), (float(neural_car_manager.id_queue_index) / neural_car_manager.network_ids.size()) * 100] )
		previous_id_queue_index = neural_car_manager.id_queue_index


func reward_slow(car : NeuralCar):
	#var bonus : float = absf(minf(0, car.speed - 3000.0)) / 6000.0
	#if bonus > 0:
		#car.score += bonus
		#print("bonus received: " + str(bonus))
	pass


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if event.is_pressed():
				if popout_component.popped_out:
					popout_component.close_popout()
				else:
					stat_screen.visible = !stat_screen.visible


func update_first_place_score() -> float:
	var leader : NeuralCar = next_camera_target if next_camera_target_set_flag else first_place_car
	if leader.active:
		first_place_score = neural_car_manager.get_reward(leader)
		neural_car_manager.on_network_score_changed(first_place_score)
	return first_place_score


func pause():
	if paused: return;
	paused = true
	pause_button.text = "Resume"
	#neural_car_manager.pause()
	get_tree().paused = true

func resume():
	if not paused: return
	paused = false
	pause_button.text = "Pause"
	#neural_car_manager.resume()
	get_tree().paused = false

func toggle_pause():
	if paused:
		resume()
	else:
		pause()


func set_time_scale(time_scale : float):
	Engine.time_scale = time_scale
	Engine.max_physics_steps_per_frame = 8 * time_scale
	print("Time Scale: ", Engine.time_scale)


func _on_neural_car_manager_reset() -> void:
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	var batch_progress := neural_car_manager.batch_manager.get_progress()
	var current_batch_index := neural_car_manager.batch_manager.get_current_index()
	batch_label.set_text("Progress: %d/%d (%d%%)" % [current_batch_index, neural_car_manager.num_networks, batch_progress * 100] )
	
	highest_checkpoint = 0
	#if not neural_car_manager.cars.is_empty():
		#set_camera_target(neural_car_manager.cars[0])


func _on_car_manager_new_generation(generation : int) -> void:
	total_generations += 1
	total_gens_label.set_text("Total Generations: " + str(total_generations))
	
	training_state.generation = generation
	gen_label.set_text("Generation: " + str(generation))
	improvement_label.set_text("Gens without improvement: " + str(neural_car_manager.gens_without_improvement))


func _on_neural_car_manager_networks_randomized() -> void:
	since_randomized = 0
	since_randomized_int = 0



func _on_save_button_pressed() -> void:
	var save_path := save_path_edit.get_text()
	
	training_state.networks = await neural_car_manager.get_best_networks(min(200, neural_car_manager.num_networks))
	training_state.highest_score = neural_car_manager.highest_score
	
	var error := await SaveManager.save_training_state(training_state, save_path)
	if error != OK:
		push_warning("Failed to save state. Reason: ", error_string(error))
	#await neural_car_manager.save_networks(save_path, min(200, neural_car_manager.num_networks), true)


func set_training_state(state : TrainingState):
	if not state: state = TrainingState.new()
	training_state = state
	
	time_elapsed_int = floori(training_state.time_elapsed)
	since_randomized = training_state.time_elapsed
	since_randomized_int = time_elapsed_int
	total_generations = training_state.generation
	
	if not is_node_ready(): return
	
	neural_car_manager.initial_networks = training_state.networks
	neural_car_manager.generation = training_state.generation
	if neural_api_client.is_node_ready():
		var io_handler := neural_api_client.io_handler
		if io_handler and neural_car_manager.api_configured:
			io_handler.stop()
			neural_car_manager.api_configured = false
			io_handler.start()


func _on_car_entered_checkpoint(car: NeuralCar, checkpoint_index: int, num_checkpoints: int, checkpoints : Area2D) -> void:
	if car.active and car.moving_forwards:
		if ((car.checkpoint_index + 1) % num_checkpoints) == checkpoint_index:
			car.checkpoint()
				
			if car.checkpoint_index > highest_checkpoint:
				highest_checkpoint = car.checkpoint_index
				#if car.id != best_network_id:
					#set_first_place_car(car)


func set_first_place_car(car : NeuralCar):
	if best_network_id == car.id: return
	if first_place_car and first_place_car.deactivated.is_connected(_on_first_place_car_deactevated):
		first_place_car.deactivated.disconnect(_on_first_place_car_deactevated)
	first_place_car = car
	best_network_id = car.id
	highest_checkpoint = car.checkpoint_index
	first_place_car.deactivated.connect(_on_first_place_car_deactevated, CONNECT_ONE_SHOT)
	camera_manager.start_tracking(first_place_car)


func update_first_place_car():
	best_network_id = -1
	set_first_place_car($Leaderboard.leaderboard.back())
	return


func _on_first_place_car_deactevated():
	#var camera_position := Vector2(camera_manager.camera.global_position)
	camera_manager.stop_tracking()
	#if not camera_manager.free_floating: camera_manager.camera.global_position = camera_position
	
	#update_first_place_car()


func _on_popout_button_pressed() -> void:
	popout_component.popout()


func _on_stat_screen_popout_state_changed(popped_out: bool) -> void:
	popout_button.visible = not popped_out


func _on_pause_button_pressed() -> void:
	toggle_pause()


func _on_browse_button_pressed() -> void:
	browse_button.disabled = true
	browse_save_folder()


func browse_save_folder():
	var current_path := get_selected_save_path()
	
	var filters = FileFilter.get_file_filters([
		FileType.TYPE_JSON,
		FileType.TYPE_RES,
		FileType.TYPE_TRES
	])
	
	CommonTools.browse_folder(FileDialog.FILE_MODE_SAVE_FILE, _on_file_selected, browse_button.set_disabled.bind(false), "Select save file", current_path, filters, FileDialog.Access.ACCESS_USERDATA)


func _on_file_selected(path : String) -> void:
	save_path_edit.set_text(CommonTools.localize_path(path.replace("\\", "/")))


func get_selected_save_path() -> String:
	var current_path := save_path_edit.get_text()
	
	if (not current_path.is_empty()) and current_path.is_relative_path():
		current_path = CommonTools.globalize_path(current_path)
	
	return current_path


func _on_file_manager_button_pressed() -> void:
	var save_path := CommonTools.globalize_path(get_selected_save_path())
	
	if not FileAccess.file_exists(save_path) and not DirAccess.dir_exists_absolute(save_path):
		save_path = save_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(save_path):
			save_path = CommonTools.USER_DATA_FOLDER
	
	OS.shell_show_in_file_manager(save_path)


func set_camera_target(target : Node):
	if camera_reparent_cooldown_active:
		next_camera_target = target
		next_camera_target_set_flag = true
		#print("target queued")
	else:
		#print("new target")
		camera_manager.start_tracking(target)
		start_camrera_reparent_cooldown()


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


func _on_exit_button_pressed() -> void:
	exit_dialog.popup_on_parent(Rect2i(get_window().size / 2 - exit_dialog.min_size / 2, exit_dialog.min_size))


func _on_exit_dialog_confirmed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
