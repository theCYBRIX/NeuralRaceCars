class_name PopoutWindow
extends Window

signal closed

func _init(header_text : String = "Popout Window", initial_size := Vector2(800, 600), initial_pos := Vector2.ZERO) -> void:
	title = header_text
	size = initial_size
	position = position

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func close():
	closed.emit()
	queue_free()
