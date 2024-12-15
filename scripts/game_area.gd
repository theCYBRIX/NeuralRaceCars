extends Node2D

var USER_DATA_FOLDER : String = ProjectSettings.globalize_path("user://")

@export var track_scene : PackedScene


@onready var neural_car_manager: NeuralCarManager = $NeuralAPIClient/NeuralCarManager
@onready var gen_label: Label = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/PanelContainer/MarginContainer/VBoxContainer/GenLabel
@onready var batch_label: Label = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/PanelContainer/MarginContainer/VBoxContainer/BatchLabel
@onready var timer_label: Label = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/PanelContainer/MarginContainer/VBoxContainer/TimerLabel
@onready var graph: Control = $CanvasLayer/StatScreen/MarginContainer/Columns/ScrollContainer2/Items/Graph
@onready var camera_manager: CameraManager = $CameraManager
@onready var camera_reparent_cooldown: Timer = $CameraReparentCooldown
@onready var stat_screen: Control = $CanvasLayer/StatScreen
@onready var popout_component: Node = $CanvasLayer/StatScreen/PopoutComponent
@onready var popout_button: Button = $CanvasLayer/StatScreen/MarginContainer/Columns/VFlowContainer/PopoutButton
@onready var pause_button: Button = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/VBoxContainer/VBoxContainer/ButtonRow/PauseButton
@onready var save_path_edit: TextEdit = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/VBoxContainer/VBoxContainer/HBoxContainer/SavePathEdit
@onready var improvement_label: Label = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/PanelContainer/MarginContainer/VBoxContainer/ImprovementLabel
@onready var since_randomized_label: Label = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/PanelContainer/MarginContainer/VBoxContainer/SinceRandomizedLabel
@onready var browse_button: Button = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/VBoxContainer/VBoxContainer/HBoxContainer/BrowseButton
@onready var color_rect_2: ColorRect = $CanvasLayer/StatScreen/ColorRect2

@onready var time_elapsed_label: Label = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/PanelContainer2/MarginContainer/VBoxContainer/TimeElapsedLabel
@onready var total_gens_label: Label = $CanvasLayer/StatScreen/MarginContainer/Columns/Items/PanelContainer2/MarginContainer/VBoxContainer/TotalGensLabel

var highest_checkpoint : int = 0

var first_place_car : NeuralCar

var track : BaseTrack

var paused := false
var total_time_elapsed := 0.0
var total_time_elapsed_int : int = -1

var since_randomized := 0.0
var since_randomized_int : int = 0

var total_generations : int = 0
var previous_id_queue_index : int = 0

var best_network_id : int = -1
var first_place_score : float = 0

<<<<<<< Updated upstream
=======
var camera_reparent_cooldown_active := false
var next_camera_target : NeuralCar
var next_camera_target_set_flag := false

>>>>>>> Stashed changes
func _process(delta: float) -> void:
	total_time_elapsed += delta
	var floored := floori(total_time_elapsed)
	if floored > total_time_elapsed_int:
		total_time_elapsed_int = floored
		time_elapsed_label.set_text("Time elapsed: " + format_time(total_time_elapsed_int))
	
	since_randomized += delta
	floored = floori(since_randomized)
	if floored > since_randomized_int:
		since_randomized_int = floored
		since_randomized_label.set_text("Since Last Randomized: " + format_time(since_randomized_int))
	
	if neural_car_manager.dynamic_batch and previous_id_queue_index != neural_car_manager.id_queue_index:
		batch_label.set_text("Progress: %d/%d (%d%%)" % [neural_car_manager.id_queue_index, neural_car_manager.network_ids.size(), (float(neural_car_manager.id_queue_index) / neural_car_manager.network_ids.size()) * 100] )


func format_time(seconds : int) -> String:
	var formatted := "%ds" % (seconds % 60)
	
	if seconds > 60:
		formatted = ("%dm " % ((seconds / 60) % 60)) + formatted
	if seconds > 3600:
		formatted = ("%dh " % ((seconds / 3600) % 24)) + formatted
	if seconds > 86400:
		formatted = ("%dd " % (seconds / 86400)) + formatted
	
	return formatted

func _enter_tree() -> void:
	track = track_scene.instantiate()
	add_child(track, false, Node.INTERNAL_MODE_FRONT)
	track.car_entered_checkpoint.connect(_on_car_entered_checkpoint.bind())
	track.car_entered_slow_zone.connect(reward_slow.bind())
	track.car_exited_slow_zone.connect(reward_slow.bind())


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
<<<<<<< Updated upstream
	if camera_reparent_cooldown.is_stopped():
		first_place_score = neural_car_manager.get_reward(first_place_car)
=======
	var leader : NeuralCar = next_camera_target if next_camera_target_set_flag else first_place_car
	if leader.active:
		first_place_score = neural_car_manager.get_reward(leader)
>>>>>>> Stashed changes
		neural_car_manager.on_network_score_changed(first_place_score)
	return first_place_score


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	neural_car_manager.track = track
	set_first_place_car(neural_car_manager.cars[0])
	
	neural_car_manager.ready.connect(_on_neural_car_manager_reset, CONNECT_ONE_SHOT)
	
	graph.add_series("First Place Score", Color.DODGER_BLUE, update_first_place_score)
	graph.add_series("Best Score", Color.SKY_BLUE, func(): return neural_car_manager.highest_score)
	graph.add_series("Networks Alive (%)", Color.YELLOW_GREEN, func(): return neural_car_manager.cars_active / float(neural_car_manager.cars.size()))
	graph.add_series("Framerate (FPS)", Color.LIME_GREEN, Engine.get_frames_per_second)


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


@warning_ignore("shadowed_variable")
func set_time_scale(scale : float):
	Engine.time_scale = scale
	Engine.max_physics_steps_per_frame = 8 * scale
	print(Engine.time_scale)



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
	
	gen_label.set_text("Generation: " + str(generation))
	improvement_label.set_text("Gens without improvement: " + str(neural_car_manager.gens_without_improvement))


func _on_neural_car_manager_networks_randomized() -> void:
	since_randomized = 0
	since_randomized_int = 0



func _on_save_button_pressed() -> void:
	var save_path := save_path_edit.get_text()
	await neural_car_manager.save_networks(save_path, min(200, neural_car_manager.num_networks), true)


func _on_car_entered_checkpoint(car: NeuralCar, checkpoint_index: int, num_checkpoints: int, checkpoints : Area2D) -> void:
	if car.active and car.moving_forwards:
		if car.checkpoint_index + 1 == checkpoint_index:
			car.checkpoint(checkpoint_index == (num_checkpoints - 1))
			#print(car.checkpoint_index)
			var checkpoints_reached : int = car.laps_completed * num_checkpoints + checkpoint_index
				
			if checkpoints_reached > highest_checkpoint:
				highest_checkpoint = checkpoints_reached
<<<<<<< Updated upstream
				if car.id != best_network_id:
					set_first_place_car(car)
					camera_reparent_cooldown.stop()
=======
				#if car.id != best_network_id:
					#set_first_place_car(car)
>>>>>>> Stashed changes

func set_first_place_car(car : NeuralCar):
	if best_network_id == car.id: return
	if first_place_car and first_place_car.deactivated.is_connected(_on_first_place_car_deactevated):
		first_place_car.deactivated.disconnect(_on_first_place_car_deactevated)
	first_place_car = car
	best_network_id = car.id
	highest_checkpoint = car.checkpoint_index
	first_place_car.deactivated.connect(_on_first_place_car_deactevated, CONNECT_ONE_SHOT)
<<<<<<< Updated upstream
	camera_manager.start_tracking(car)
	camera_reparent_cooldown.stop()
	update_first_place_score()

func update_first_place_car():
	var contenders : Array[NeuralCar] = []
	var max_checkpoint_index : int = 0
	for car : NeuralCar in neural_car_manager.active_cars.values():
		if (not car.active) or (car.checkpoint_index < max_checkpoint_index): continue
		if car.checkpoint_index > max_checkpoint_index:
			max_checkpoint_index = car.checkpoint_index
			contenders.clear()
		contenders.append(car)
	
	if contenders.is_empty(): return
	
	var max_score : float = -1
	var first_place : NeuralCar = contenders[0]
	for car : NeuralCar in contenders:
		if not car.active: continue
		var score := neural_car_manager.get_reward(car)
		if score > max_score:
			max_score = score
			first_place = car
	set_first_place_car(first_place_car)


func _on_first_place_car_deactevated():
	camera_manager.stop_tracking()
	camera_manager.camera.global_position = first_place_car.final_pos
	camera_reparent_cooldown.start()
=======
	set_camera_target(car)
	update_first_place_score()

func update_first_place_car():
	best_network_id = -1
	set_first_place_car($Leaderboard.leaderboard.back())
	return
	
	#var contenders : Array[NeuralCar] = []
	#var max_checkpoint_index : int = -1
	#for car : NeuralCar in neural_car_manager.active_cars.values():
		#if not car.active: continue
		#var car_abs_checkpoint_index := car.laps_completed * neural_car_manager.track.num_checkpoints + car.checkpoint_index
		#if car_abs_checkpoint_index < max_checkpoint_index: continue
		#if car_abs_checkpoint_index > max_checkpoint_index:
			#max_checkpoint_index = car_abs_checkpoint_index
			#contenders.clear()
		#contenders.append(car)
	#
	#if contenders.is_empty():
		#start_camrera_reparent_cooldown()
		#print("why?")
		#return
	#
	#var max_score : float = -1
	#var first_place : NeuralCar = contenders[0]
	#for car : NeuralCar in contenders:
		#if not car.active: continue
		#var score := neural_car_manager.get_reward(car)
		#if score > max_score:
			#max_score = score
			#first_place = car
	#
	#best_network_id = -1
	#set_first_place_car(first_place_car)


func _on_first_place_car_deactevated():
	#var camera_position := Vector2(camera_manager.camera.global_position)
	camera_manager.stop_tracking()
	#if not camera_manager.free_floating: camera_manager.camera.global_position = camera_position
	
	#update_first_place_car()
>>>>>>> Stashed changes


func _on_generation_countown_updatad(remaining_sec: int) -> void:
	timer_label.set_text("Time Remaining: " + str(roundf(remaining_sec)))


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
		
	var dialog = FileDialog.new()
	dialog.title = "Select save file"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.add_filter("*.json", "JavaScript Object Notation")
	
	if FileAccess.file_exists(current_path):
		if current_path.get_extension() == "json":
			dialog.current_file = current_path
		else:
			dialog.current_dir = current_path.get_base_dir()
	elif DirAccess.dir_exists_absolute(current_path):
		dialog.current_dir = current_path
	else:
		dialog.current_dir = USER_DATA_FOLDER
	
	dialog.use_native_dialog = true
	dialog.file_selected.connect(func(path : String): save_path_edit.set_text(localize_path(path.replace("\\", "/"))), CONNECT_ONE_SHOT)
	dialog.canceled.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.confirmed.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.file_selected.connect(func(x): dialog.queue_free(), CONNECT_ONE_SHOT)
	dialog.tree_exiting.connect(browse_button.set_disabled.bind(false), CONNECT_ONE_SHOT)
	#get_tree().get_root().add_child(dialog)
	dialog.popup_exclusive(get_tree().get_root(), get_tree().get_root().get_visible_rect())

func get_selected_save_path() -> String:
	var current_path := save_path_edit.get_text()
	
	if (not current_path.is_empty()) and current_path.is_relative_path():
		current_path = ProjectSettings.globalize_path(current_path)
	
	return current_path


func localize_path(path : String) -> String:
	if path.begins_with(USER_DATA_FOLDER):
		path = "user://" + path.substr(USER_DATA_FOLDER.length(), path.length() - USER_DATA_FOLDER.length())
	else:
		path = ProjectSettings.localize_path(path)
	return path


func _on_file_manager_button_pressed() -> void:
	var save_path := ProjectSettings.globalize_path(get_selected_save_path())
	
	if not FileAccess.file_exists(save_path) and not DirAccess.dir_exists_absolute(save_path):
		save_path = save_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(save_path):
			save_path = USER_DATA_FOLDER
	
	OS.shell_show_in_file_manager(save_path)


<<<<<<< Updated upstream
func _on_camera_reparent_cooldown_timeout() -> void:
	update_first_place_car()
=======
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
>>>>>>> Stashed changes
