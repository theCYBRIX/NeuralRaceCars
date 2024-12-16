extends Camera2D

signal toggle_free_floating(enabled : bool)

const MIN_ZOOM := Vector2.ONE * 0.01
const MAX_ZOOM := Vector2.ONE * 5

@export var zoom_multiplier : float = 0.08
@export var speed : float = 75

@export var free_floating : bool = false : set = set_free_floating

var dragging : bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
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
	return clamp(desired, MIN_ZOOM, MAX_ZOOM)


func set_free_floating(floating : bool):
	if free_floating == floating: return
	free_floating = floating
	set_process(free_floating)
	position_smoothing_enabled = not free_floating
	toggle_free_floating.emit(free_floating)
