extends Node2D

@export var gradient : Gradient = null
@export var min_slide_speed : float = 600
@export var min_angular_velocity : float = PI / 1.25
@export var tire_mark_start_angle : float = deg_to_rad(10)
@export var tire_mark_show_time : float
@export var tire_mark_despawn_time : float

var _tire_mark : Line2D
var _sliding : bool = false

var _despawning : Array[Line2D] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var index : int = _despawning.size() - 1
	while index >= 0:
		var mark := _despawning[index]
		if mark.get_point_count() > 0:
			mark.remove_point(0)
		if mark.get_point_count() == 0:
			if not _sliding or mark != _tire_mark:
				_despawning.remove_at(index)
				mark.queue_free()
		index -= 1
	
	var parent := get_parent()
	if parent.speed > min_slide_speed or absf(parent.angular_velocity) > min_angular_velocity:
		if parent.breaking or _check_sliding():
			if not _sliding:
				_start_slide()
			_tire_mark.add_point(global_position)
			return
	
	if _sliding:
		_end_slide()


func _check_sliding() -> bool:
	var velocity_norm : Vector2 = get_parent().linear_velocity.normalized()
	var tire_direction := Vector2.UP.rotated(global_rotation)
	
	return (absf(velocity_norm.dot(tire_direction)) * PI < PI - tire_mark_start_angle)


func _start_slide() -> void:
	if _sliding:
		return
	
	_tire_mark = _new_tire_mark()
	add_child(_tire_mark)
	_sliding = true
	get_tree().create_timer(tire_mark_show_time, false, true).timeout.connect(_start_despawn.bind(_tire_mark), CONNECT_DEFERRED)


func _end_slide() -> void:
	_sliding = false


func _start_despawn(line : Line2D) -> void:
	_despawning.append(line)


func _new_tire_mark() -> Line2D:
	var mark := TireMark.new()
	mark.set_visibility_layer_bit(0, false)
	mark.set_visibility_layer_bit(1, true)
	mark.gradient = gradient
	mark.show_behind_parent = true
	return mark

class TireMark extends Line2D:
	func _process(_delta: float) -> void:
		global_position = Vector2.ZERO
		global_rotation = 0
