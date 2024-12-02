extends Node2D
@onready var checkpoints: Area2D = $Checkpoints
var num_checkpoints : int
@onready var neural_car_manager: Node = $NeuralCarManager
@onready var spawn_point: Marker2D = $SpawnPoint
@onready var label: Label = $CanvasLayer/Label
@onready var timer_label: Label = $CanvasLayer/TimerLabel
@onready var graph: Control = $CanvasLayer/Graph
var highest_checkpoint : int = 0
var generation : int = 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	num_checkpoints = checkpoints.get_child_count()
	neural_car_manager.ready.connect(_on_neural_car_manager_reset, CONNECT_ONE_SHOT)
	graph.add_series("Best Score", Color.DEEP_SKY_BLUE, func(): return neural_car_manager.highest_score)
	graph.add_series("Networks Alive", Color.YELLOW_GREEN, func(): return neural_car_manager.cars_active)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_right"):
		set_time_scale(Engine.time_scale + 0.5)
	elif Input.is_action_just_pressed("ui_left"):
		if Engine.time_scale > 1:
			set_time_scale(Engine.time_scale - 0.5)
	timer_label.set_text("Time Remaining: " + str(roundf(neural_car_manager.timer.time_left)))


func set_time_scale(scale : float):
	Engine.time_scale = scale
	Engine.max_physics_steps_per_frame = 8 * scale
	print(Engine.time_scale)


func _on_checkpoints_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body is NeuralCar:
		var car := body as NeuralCar
		if car.active and car.moving_forwards:
			if (car.checkpoint_index % num_checkpoints) == local_shape_index:
				car.checkpoint(local_shape_index == (num_checkpoints - 1))
				if car.checkpoint_index > highest_checkpoint:
					highest_checkpoint = car.checkpoint_index
					car.camera.make_current()



func _on_neural_car_manager_reset() -> void:
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	highest_checkpoint = 0
	generation += 1
	label.set_text("Generation: " + str(generation))
	for c : NeuralCar in neural_car_manager.cars:
		reset_position(c)


func reset_position(car : Car):
	car.set_reset_state(spawn_point.position, spawn_point.rotation)


func _on_neural_car_manager_spawned(car: NeuralCar) -> void:
	reset_position(car)


func _on_save_button_pressed() -> void:
	neural_car_manager.call_deferred_thread_group("save_networks", 200)
