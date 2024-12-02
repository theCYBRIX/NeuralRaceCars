class_name Car
extends RigidBody2D

const STEERING_THRESH : int = 300
const STEERING_FORCE_MULTIPLIER : int = 70000000

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

@onready var camera_mount: Node2D = $CameraMount
@onready var sprite: Sprite2D = $Sprite

var forwards : Vector2 = Vector2.UP

var speed : float
var moving : bool
var moving_forwards : bool

var reset_state : bool = false
var reset_position : Vector2
var reset_rotation : float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_body_color(body_color)

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
	var steering_input = get_steering_input()
	
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
	
	if reset_state:
		position = reset_position
		rotation = reset_rotation
		linear_velocity = Vector2.ZERO
		angular_velocity = 0
		reset_state = false

func set_reset_state(pos : Vector2, angle : float):
	reset_position = pos
	reset_rotation = angle
	reset_state = true


func set_body_color(color : Color):
	body_color = color
	if is_node_ready():
		sprite.material.set_shader_parameter("replacement_color", body_color)


func reset(location : Marker2D):
	set_reset_state(location.position, location.rotation)
