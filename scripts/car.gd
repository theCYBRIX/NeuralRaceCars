class_name Car
extends RigidBody2D

signal respawned
signal checkpoint_updated(idx : int)

const HALF_PI := PI / 2
const STEERING_THRESH : int = 300
const STEERING_FORCE_MULTIPLIER : int = 70000000
const MAX_STEERING_ANGLE := deg_to_rad(45)

@export var forward_acceleration : float = 150000
@export var reverse_acceleration : float = 100000
@export var braking_power : float = 70000
@export var tire_friction : float = 10

@export var turn_rate : float = PI / 80.0

@export var max_forward_speed : int = 4000
@export var max_reverse_speed : int = 600

@export var steering_dropoff : Curve
@export var accelecation_curve : Curve

@export var body_color : Color = Color.GREEN : set = set_body_color

@export var track : BaseTrack

var forwards : Vector2 = Vector2.UP

var speed : float
var moving : bool
var moving_forwards : bool
var breaking : bool

var checkpoint_index : int = -1 : set = set_checkpoint

@onready var camera_pivot: Node2D = $CameraPivot
@onready var sprite: Sprite2D = $Sprite

@onready var tire_fl: Node2D = $TireFL
@onready var tire_fr: Node2D = $TireFR
@onready var tire_rl: Node2D = $TireRL
@onready var tire_rr: Node2D = $TireRR

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_body_color(body_color)
	
	if not track:
		track = get_parent()
	
	if track and track.is_node_ready():
		reset()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func get_throttle_input() -> float:
	return Input.get_axis("decelerate", "accelerate")

func get_steering_input() -> float:
	return Input.get_axis("turn_left", "turn_right")

func _physics_process(delta: float) -> void:
	
	speed = linear_velocity.length()
	
	moving = speed > 0
	moving_forwards = forwards.dot(linear_velocity) > 0
	
	var throttle_input = get_throttle_input()
	breaking = moving_forwards and (throttle_input < 0)
	
	var steering_input = get_steering_input()
	
	_update_tire_angles(steering_input)
	
	if speed < STEERING_THRESH:
		steering_input *= steering_dropoff.sample(speed / STEERING_THRESH)
	if not moving_forwards:
		steering_input = -steering_input
	
	if throttle_input < 0:
		if moving_forwards:
			apply_central_force(forwards * (braking_power * throttle_input) * delta * mass)
		else:
			apply_central_force(forwards * (reverse_acceleration * throttle_input * accelecation_curve.sample(speed / max_reverse_speed)) * delta * mass)
	
	elif throttle_input > 0:
		apply_central_force(forwards * (forward_acceleration * throttle_input * accelecation_curve.sample(speed / max_forward_speed)) * delta * mass)
	
	if moving:
		apply_central_force((linear_velocity.project(forwards) - linear_velocity) * mass * tire_friction)
		if steering_input != 0:
			apply_torque(turn_rate * steering_input * delta * mass * STEERING_FORCE_MULTIPLIER)
		else:
			apply_torque(-angular_velocity * mass * tire_friction * 10)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	forwards = Vector2.UP.rotated(state.transform.get_rotation())


func get_slip_angle() -> float:
	return get_velocity_angle_difference(global_rotation)


func get_velocity_angle_difference(angle : float):
	return angle_difference(angle, linear_velocity.angle() + HALF_PI)


func checkpoint(idx : int) -> bool:
	if (checkpoint_index + 1) != idx:
		return false
	checkpoint_index += 1
	return true


func set_checkpoint(idx : int):
	if idx == checkpoint_index: return
	checkpoint_index = idx
	checkpoint_updated.emit(checkpoint_index)


func respawn(pos : Vector2, angle : float):
	await _set_position_and_rotation(pos, angle)
	respawned.emit()


func _set_position_and_rotation(pos : Vector2, angle : float):
	set_physics_process(false)
	await get_tree().physics_frame
	#position = pos
	#rotation = angle
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	
	#var new_transform = transform.rotated(angle_difference(rotation, angle))
	var new_transform = Transform2D(angle, transform.get_scale(), transform.get_skew(), pos)
	#new_transform.origin = pos
	PhysicsServer2D.body_set_state(
		self,
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		new_transform
	)
	#force_update_transform()
	set_physics_process(true)


func set_body_color(color : Color):
	body_color = color
	if is_node_ready():
		sprite.material.set_shader_parameter("replacement_color", body_color)


func reset(spawn_type : BaseTrack.SpawnType = BaseTrack.SpawnType.TRACK_START):
	if not track:
		return
	
	if not track.is_node_ready():
		push_error("Unable to reset. Track is not ready.")
		return
		
	var spawn_point := track.get_spawn_point(spawn_type, self)
	
	if not spawn_point:
		push_error("Unable to reset. Spawn point is null.")
		return
	
	if spawn_type == BaseTrack.SpawnType.TRACK_START:
		checkpoint_index = -1
	
	await respawn(spawn_point.position, spawn_point.rotation)


func _update_tire_angles(steering_input : float) -> void:
	var tire_angle := steering_input * MAX_STEERING_ANGLE
	tire_fl.rotation = tire_angle
	tire_fr.rotation = tire_angle
