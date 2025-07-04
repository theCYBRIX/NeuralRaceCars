extends Node2D


@export var car : Car : set = set_car
@export var max_steering_degrees : float = 120
@export var steering_lerp_time : float = 0.15


@onready var gas_pedal: AnimatedSprite2D = $GasPedal
@onready var brake_pedal: AnimatedSprite2D = $BrakePedal
@onready var steering_wheel: Sprite2D = $SteeringWheel


var _steering_tween : Tween


func _process(_delta: float) -> void:
	if not car:
		set_process(false)
		return
	
	
	var throttle_input := car.get_throttle_input()
	var positive_part := clampf(throttle_input, 0, 1)
	var negative_part := absf(clampf(throttle_input, -1, 0))
	if car.moving_forwards:
		set_throttle(positive_part)
		set_brake(negative_part)
	else:
		if throttle_input < 0:
			set_throttle(negative_part)
			set_brake(0)
		else:
			set_throttle(0)
			set_brake(positive_part)
	set_steering(car.get_steering_input())


func reset() -> void:
	set_steering(0)
	set_throttle(0)
	set_brake(0)


func set_steering(input : float) -> void:
	var new_angle := clampf(input, -1, 1) * max_steering_degrees
	if _steering_tween and _steering_tween.is_running():
		_steering_tween.kill()
	_steering_tween = create_tween()
	_steering_tween.tween_property(steering_wheel, "rotation_degrees", new_angle, steering_lerp_time).set_ease(Tween.EASE_IN)


func set_throttle(value : float) -> void:
	var depressed := value >= 0.5
	if depressed:
		gas_pedal.play("Gas Pedal Down")
	else:
		gas_pedal.play("Gas Pedal Up")


func set_brake(value : float) -> void:
	var depressed := value >= 0.5
	if depressed:
		brake_pedal.play("Brake Pedal Down")
	else:
		brake_pedal.play("Brake Pedal Up")


func set_car(obj : Car) -> void:
	car = obj
	if is_node_ready(): reset()
	set_process(true if car else false)
