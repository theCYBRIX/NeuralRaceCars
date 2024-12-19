extends Node2D

@export var track_scene : PackedScene

@onready var label: Label = $CanvasLayer/Label
@onready var timer_label: Label = $CanvasLayer/TimerLabel
@onready var graph: Control = $CanvasLayer/Graph
@onready var camera_manager: CameraManager = $CameraManager

var highest_checkpoint : int = 0
var generation : int = 0

var track : BaseTrack
@onready var car: TestingCar = $NetworkControlledCar
@onready var sprite_2d: Sprite2D = $TestingCar2/Sprite2D

func _enter_tree() -> void:
	track = track_scene.instantiate()
	add_child(track, false, Node.INTERNAL_MODE_FRONT)
	track.car_entered_checkpoint.connect(_on_car_entered_checkpoint.bind())
	track.car_entered_slow_zone.connect(reward_slow.bind())
	track.car_exited_slow_zone.connect(reward_slow.bind())


func reward_slow(car : NeuralCar):
	var bonus : float = absf(minf(0, car.speed - 3000.0)) / 6000.0
	if bonus > 0:
		car.score += bonus
		#print("bonus received: " + str(bonus))

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	print("track set")
	car.track = track
	#graph.add_series("Score", Color.DEEP_SKY_BLUE, func(): return (track.get_lap_progress(car.global_position, car.checkpoint_index) * 10) + car.score)
	#graph.add_series("Laps Completed", Color.MEDIUM_PURPLE, func(): return car.laps_completed)
	#graph.add_series("Lap Progress", Color.DEEP_PINK, func(): return track.get_lap_progress(car.global_position, car.checkpoint_index))
	graph.add_series("Car rotation", Color.GOLDENROD, func(): return fmod(car.global_rotation + PI * 3.5, 2 * PI))
	graph.add_series("Track rotation", Color.WEB_PURPLE, func(): return fmod(track.trajectory.curve.sample_baked_with_rotation(track.get_closest_trajectory_offset(car.global_position) + 200).get_rotation() + 2 * PI, 2 * PI))


func get_rotation_bonus():
	var rotation_diff : float = abs(abs(car.global_rotation - (PI / 2)) - abs(track.trajectory.curve.sample_baked_with_rotation(track.get_closest_trajectory_offset(car.global_position) + 200).get_rotation()))
	return ((PI - rotation_diff) / PI) * 100


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
	highest_checkpoint = 0
	generation += 1
	label.set_text("Generation: " + str(generation))


func _on_car_entered_checkpoint(car: NeuralCar, checkpoint_index: int, num_checkpoints: int, checkpoints : Area2D) -> void:
	if car.active and car.moving_forwards:
		if car.checkpoint_index + 1 == checkpoint_index:
			car.checkpoint()
			#print(car.checkpoint_index)
			if car.checkpoint_index > highest_checkpoint:
				highest_checkpoint = car.checkpoint_index
				camera_manager.start_tracking(car)


func _on_generation_countown_updatad(remaining_sec: int) -> void:
	timer_label.set_text("Time Remaining: " + str(roundf(remaining_sec)))
