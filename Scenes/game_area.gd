extends Node2D

@export var track_scene : PackedScene

@onready var neural_car_manager: NeuralCarManager = $NeuralAPIClient/NeuralCarManager
@onready var gen_label: Label = $CanvasLayer/GenLabel
@onready var batch_label: Label = $CanvasLayer/BatchLabel
@onready var timer_label: Label = $CanvasLayer/TimerLabel
@onready var graph: Control = $CanvasLayer/Graph
@onready var camera_manager: CameraManager = $CameraManager

var highest_checkpoint : int = 0

var first_place_car : NeuralCar
var best_score : float = 0

var generation : int = 0

var track : BaseTrack

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


func update_first_place_score() -> float:
	var first_place_score := neural_car_manager.get_reward(first_place_car)
	if first_place_score > best_score:
		best_score = first_place_score
	return first_place_score


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	neural_car_manager.track = track
	first_place_car = neural_car_manager.cars[0]
	
	neural_car_manager.ready.connect(_on_neural_car_manager_reset, CONNECT_ONE_SHOT)
	
	graph.add_series("First Place Score", Color.DODGER_BLUE, update_first_place_score)
	graph.add_series("Best Score", Color.SKY_BLUE, func(): return best_score)
	graph.add_series("Networks Alive (%)", Color.YELLOW_GREEN, func(): return neural_car_manager.cars_active / float(neural_car_manager.cars.size()))
	graph.add_series("Framerate (FPS)", Color.LIME_GREEN, Engine.get_frames_per_second)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	#sprite_2d.rotation = PI + track.get_track_direction(sprite_2d.global_position, 500)
	pass
	#if Input.is_action_just_pressed("ui_right"):
		#set_time_scale(Engine.time_scale + 0.5)
	#elif Input.is_action_just_pressed("ui_left"):
		#if Engine.time_scale > 1:
			#set_time_scale(Engine.time_scale - 0.5)

@warning_ignore("shadowed_variable")
func set_time_scale(scale : float):
	Engine.time_scale = scale
	Engine.max_physics_steps_per_frame = 8 * scale
	print(Engine.time_scale)



func _on_neural_car_manager_reset() -> void:
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	var batch_progress := (neural_car_manager.batch_start_index + neural_car_manager.batch_size)
	batch_label.set_text("Progress: %d/%d (%d%%)" % [batch_progress, neural_car_manager.num_networks, (batch_progress * 100 / neural_car_manager.num_networks)] )
	
	highest_checkpoint = 0
	if not neural_car_manager.cars.is_empty():
		camera_manager.start_tracking(neural_car_manager.cars[0])


func _on_car_manager_new_generation() -> void:
	generation += 1
	gen_label.set_text("Generation: " + str(generation))



func _on_save_button_pressed() -> void:
	neural_car_manager.call_deferred_thread_group("save_networks", neural_car_manager.num_networks)


func _on_car_entered_checkpoint(car: NeuralCar, checkpoint_index: int, num_checkpoints: int, checkpoints : Area2D) -> void:
	if car.active and car.moving_forwards:
		if car.checkpoint_index + 1 == checkpoint_index:
			car.checkpoint(checkpoint_index == (num_checkpoints - 1))
			#print(car.checkpoint_index)
			var checkpoints_reached : int = car.laps_completed * num_checkpoints + checkpoint_index
				
			if checkpoints_reached > highest_checkpoint:
				highest_checkpoint = checkpoints_reached
				if car != first_place_car:
					first_place_car = car
					camera_manager.start_tracking(car)


func _on_generation_countown_updatad(remaining_sec: int) -> void:
	timer_label.set_text("Time Remaining: " + str(roundf(remaining_sec)))
