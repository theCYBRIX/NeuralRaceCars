extends HBoxContainer

signal pressed

@onready var line_2d: Line2D = $Control/Line2D
@onready var label: Label = $Label

var text : String : set = set_text
var color : Color : set = set_color
var series : GraphSeries

var hovered : bool = false
var held_down : bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	label.set_text(text)
	line_2d.default_color = self.color


func _gui_input(event: InputEvent) -> void:
	if not hovered: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_released():
				if held_down:
					pressed.emit()
			elif not held_down:
				held_down = true


func set_color(c : Color):
	color = c
	if is_node_ready():
		line_2d.default_color = self.color

func set_text(title : String):
	text = title
	if is_node_ready():
		label.set_text(text)


func _on_mouse_entered() -> void:
	hovered = true


func _on_mouse_exited() -> void:
	hovered = false
	held_down = false


func _get_drag_data(_at_position: Vector2) -> Variant:
	var cpb := ColorPickerButton.new()
	cpb.color = color
	cpb.size = Vector2(50, 50)
	set_drag_preview(cpb)
	
	return series
