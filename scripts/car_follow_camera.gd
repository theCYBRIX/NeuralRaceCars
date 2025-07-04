class_name ChaseCamera
extends Camera2D


@export var target : Car : set = set_target
@export var look_ahead_enabled := false

@export_group("Zoom Behaviour")
## The baseline zoom value
@export var default_zoom := 0.35 : set = set_default_zoom
## How far to zoom out from default_zoom. Range: [0, inf)
@export var relative_min_zoom := -0.25 : set = set_relative_min_zoom
## How far to zoom in from default_zoom. Range: (-inf, 0]
@export var relative_max_zoom := 0.25 : set = set_relative_max_zoom
@export_subgroup("Speed Multiplyers")
@export var reset_zoom_speed_multiplier := 5.0 : set = set_reset_zoom_speed_multiplier
@export var zoom_in_speed_multiplier := 3.0 : set = set_zoom_in_speed_multiplier
@export var zoom_out_speed_multiplier := 1.0 : set = set_zoom_out_speed_multiplier

@export_subgroup("Speed Range")
## Speed at which the target zoom should be the zoom in limit.
@export var min_speed : float = 0 : set = set_min_speed
## Speed at which the target zoom should be the zoom out limit.
@export var max_speed : float = 1500 : set = set_max_speed
## Speed below which to start zooming in.
@export var zoom_in_trigger_speed : float = 300 : set = set_zoom_in_trigger_speed
## Speed above which to start zooming out.
@export var zoom_out_trigger_speed : float = 1200 : set = set_zoom_out_trigger_speed

@export_group("Rotation", "rotation")
@export var rotation_speed_multiplyer : float = 2.0 : set = set_rotation_speed_multiplier
@export var rotation_follow_velocity_min_speed : float = 300 : set = set_rotation_follow_velocity_min_speed

@export_group("Look Ahead", "look_ahead")
@export var look_ahead_distance := 800.0
@export var look_ahead_speed_thresh : float = 700 : set = set_look_ahead_speed_thresh
@export var look_ahead_min_speed : float = 200 : set = set_look_ahead_min_speed
@export var look_ahead_lerp_time : float = 1.5 : set = set_look_ahead_lerp_time


var tracking : bool = false : set = set_tracking, get = is_tracking


var _default_zoom : Vector2
var _max_zoom : Vector2
var _min_zoom : Vector2

var _look_ahead_time : float = 0.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_zoom_limits()
	zoom = _default_zoom
	set_process(false)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not target:
		tracking = false
		return
	
	var speed := target.speed
	#print(speed)
	var target_position := target.camera_pivot.global_position
	
	if look_ahead_enabled:
		var above_thresh := (speed >= look_ahead_speed_thresh)
		var lerp_weight := smoothstep(0, look_ahead_lerp_time, _look_ahead_time)
		if above_thresh:
			target_position += target.linear_velocity.normalized() * lerpf(0, look_ahead_distance, lerp_weight)
			if _look_ahead_time != look_ahead_lerp_time:
				_look_ahead_time = min(_look_ahead_time + delta, look_ahead_lerp_time)
		elif speed > look_ahead_min_speed:
			target_position += target.linear_velocity.normalized() * lerpf(look_ahead_distance, 0, 1.0 - lerp_weight)
			if _look_ahead_time > 0:
				_look_ahead_time = max(0.0, _look_ahead_time - delta)
		else:
			_look_ahead_time = 0.0
	
	global_position = global_position.lerp(target_position, minf(1, delta * 5.0))
	
	if not ignore_rotation:
		var target_rotation := target.global_rotation + target.get_slip_angle() if speed > rotation_follow_velocity_min_speed else target.global_rotation
		global_rotation = lerp_angle(global_rotation, target_rotation, minf(1, delta * rotation_speed_multiplyer))
	
	if speed >= zoom_out_trigger_speed:
		zoom = zoom.lerp(_min_zoom, ((minf(speed, max_speed) - min_speed) / (max_speed - min_speed)) * delta * zoom_out_speed_multiplier)
	elif speed <= zoom_in_trigger_speed:
		zoom = zoom.lerp(_max_zoom, ((max_speed - maxf(speed, min_speed)) / (max_speed - min_speed)) * delta * zoom_in_speed_multiplier)
	else:
		zoom = zoom.lerp(_default_zoom, minf(1, delta * reset_zoom_speed_multiplier) * delta)


func _smooth_lerp(from : float, to : float, time_start : float, time_end : float, curr_time : float, invert : bool = false) -> float:
	if invert:
		return lerpf(from, to, smoothstep(time_start, time_end, curr_time))
	else:
		return lerpf(to, from, smoothstep(time_end, time_start, curr_time))


func is_tracking() -> bool:
	return tracking


func set_tracking(state : bool) -> void:
	tracking = state
	set_process(tracking)


func start_tracking() -> void:
	tracking = true


func stop_tracking(keep_transform := false) -> void:
	tracking = false
	if not keep_transform:
		position = Vector2.ZERO
		rotation = 0


func set_target(car : Car) -> void:
	target = car


func set_default_zoom(default : float) -> void:
	if is_nan(default_zoom):
		return
	default_zoom = Util.clamp_infinity_to_finite(default)
	_update_zoom_limits()


func set_relative_max_zoom(max_zoom : float) -> void:
	if is_nan(max_zoom):
		return
	relative_max_zoom = maxf(0, Util.clamp_infinity_to_finite(max_zoom))
	_update_zoom_limits()


func set_relative_min_zoom(min_zoom : float) -> void:
	if is_nan(min_zoom):
		return
	relative_min_zoom = minf(Util.clamp_infinity_to_finite(min_zoom), 0)
	_update_zoom_limits()


func set_min_speed(speed : float) -> void:
	min_speed = min(max_speed, speed)


func set_max_speed(speed : float) -> void:
	max_speed = max(min_speed, speed)


func set_zoom_in_trigger_speed(speed : float) -> void:
	if is_nan(speed):
		return
	zoom_in_trigger_speed = max(min_speed, speed)
	_update_zoom_limits()


func set_zoom_out_trigger_speed(speed : float) -> void:
	if is_nan(speed):
		return
	zoom_out_trigger_speed = min(max_speed, speed)
	_update_zoom_limits()


func set_reset_zoom_speed_multiplier(value : float) -> void:
	if is_nan(value):
		return
	reset_zoom_speed_multiplier = max(0, value)


func set_zoom_in_speed_multiplier(value : float) -> void:
	if is_nan(value):
		return
	zoom_in_speed_multiplier = max(0, value)


func set_zoom_out_speed_multiplier(value : float) -> void:
	if is_nan(value):
		return
	zoom_out_speed_multiplier = max(0, value)


func set_rotation_speed_multiplier(value : float) -> void:
	if is_nan(value):
		return
	rotation_speed_multiplyer = max(0, value)


func set_rotation_follow_velocity_min_speed(speed : float) -> void:
	if is_nan(speed):
		return
	rotation_follow_velocity_min_speed = max(0, speed)


func set_look_ahead_lerp_time(seconds : float) -> void:
	if is_nan(seconds):
		return
	look_ahead_lerp_time = max(0, seconds)


func set_look_ahead_min_speed(speed : float) -> void:
	if is_nan(speed):
		return
	look_ahead_min_speed = max(0, speed)


func set_look_ahead_speed_thresh(speed : float) -> void:
	if is_nan(speed):
		return
	look_ahead_speed_thresh = max(look_ahead_min_speed, speed)


func _update_zoom_limits() -> void:
	_default_zoom = Vector2.ONE * default_zoom
	_max_zoom = _default_zoom * (1 + relative_max_zoom)
	_min_zoom = _default_zoom * (1 + relative_min_zoom)
