extends Camera2D

signal toggle_free_floating(enabled : bool)

@export var default_zoom : float = 1.0 : set = set_default_zoom
@export var min_zoom : float = 0.01 : set = set_min_zoom
@export var max_zoom : float = 5 : set = set_max_zoom
@export var zoom_multiplier : float = 0.08
@export var speed : float = 75
@export var free_floating : bool = false : set = set_free_floating


var dragging : bool = false

var _default_zoom_vec : Vector2 = Vector2.ONE * default_zoom
var _min_zoom_vec : Vector2  = Vector2.ONE * min_zoom
var _max_zoom_vec : Vector2   = Vector2.ONE * max_zoom

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	zoom = _default_zoom_vec
	set_process(free_floating)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var y_motion := Input.get_axis("move_up", "move_down")
	var x_motion := Input.get_axis("move_left", "move_right")
	
	if y_motion != 0 || x_motion != 0:
		var motion := Vector2(x_motion, y_motion) * speed
		position += motion


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					zoom = limit_zoom(zoom + zoom * zoom_multiplier)
				MOUSE_BUTTON_WHEEL_DOWN:
					zoom = limit_zoom(zoom - zoom * zoom_multiplier)
				MOUSE_BUTTON_LEFT:
					dragging = event.is_pressed() and free_floating
				
		elif event is InputEventMouseMotion:
			if dragging: position -= event.relative * (Vector2.ONE / zoom)
	
	elif event is InputEventKey:
		if event.is_action_pressed("toggle_free_cam"):
			free_floating = !free_floating


func limit_zoom(desired : Vector2) -> Vector2:
	return clamp(desired, _min_zoom_vec, _max_zoom_vec)


func set_free_floating(floating : bool):
	if free_floating == floating: return
	free_floating = floating
	set_process(free_floating)
	position_smoothing_enabled = not free_floating
	toggle_free_floating.emit(free_floating)


func set_default_zoom(value : float) -> void:
	default_zoom = value
	_default_zoom_vec = Vector2.ONE * default_zoom


func set_min_zoom(value : float) -> void:
	min_zoom = value
	_min_zoom_vec = Vector2.ONE * min_zoom


func set_max_zoom(value : float) -> void:
	max_zoom = value
	_max_zoom_vec = Vector2.ONE * max_zoom
