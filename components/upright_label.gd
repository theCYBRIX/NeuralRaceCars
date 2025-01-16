class_name UprightLabel
extends Node2D

const CAR_LABEL_SETTINGS = preload("res://resources/car_label_settings.tres")

var label : Label

var label_rotation : float = 0.0 : set = set_label_rotation

func _init() -> void:
	label = Label.new()
	label.resized.connect(_on_label_resized)
	label.label_settings = CAR_LABEL_SETTINGS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label, false, Node.INTERNAL_MODE_FRONT)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	global_rotation = 0


func set_text(string : String):
	label.text = string


func set_label_rotation(angle : float):
	label.rotation = angle


func _on_label_resized() -> void:
	label.position = -(label.size / 2.0)
	label.pivot_offset = label.size / 2.0
