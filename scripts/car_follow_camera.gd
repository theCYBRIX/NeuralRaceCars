extends Camera2D

@export var target : Car
@export var enable_rotation := false : set = set_enable_rotation
@export var look_ahead := 500.0
@export var camera_look_ahead_thresh : float = 1000
@export var default_zoom := Vector2.ONE
@export var max_zoom_in := Vector2.ONE * 1.25
@export var max_zoom_out := Vector2.ONE * 0.75 
@export var max_speed : float = 1500
@export var min_speed : float = 0
@export var zoom_in_speed_thresh : float = 300
@export var zoom_out_speed_thresh : float = 1200

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(false)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var speed = target.speed
	#print(speed)
	var target_position := target.camera_pivot.global_position
	if speed >= camera_look_ahead_thresh:
		target_position += target.linear_velocity.normalized() * (minf(1, (speed - camera_look_ahead_thresh) / (max_speed - camera_look_ahead_thresh)) * look_ahead)
	global_position = global_position.lerp(target_position, minf(1, delta * 5.0))
	
	if enable_rotation:
		global_rotation = lerp_angle(global_rotation, target.global_rotation + target.get_slip_angle(), minf(1, delta * 2))
	
	if speed >= zoom_out_speed_thresh:
		zoom = zoom.lerp(Vector2.ONE * max_zoom_out, ((minf(speed, max_speed) - min_speed) / (max_speed - min_speed)) * delta)
	elif speed <= zoom_in_speed_thresh:
		zoom = zoom.lerp(Vector2.ONE * max_zoom_in, ((max_speed - maxf(speed, min_speed)) / (max_speed - min_speed)) * delta * 3)
	else:
		zoom = zoom.lerp(default_zoom, minf(1, delta * 5) * delta)


func start() -> void:
	set_process(true)
	make_current()


func stop(keep_transform := false) -> void:
	set_process(false)
	if not keep_transform:
		position = Vector2.ZERO
		rotation = 0


func set_enable_rotation(enable : bool) -> void:
	ignore_rotation = not enable
	enable_rotation = enable
