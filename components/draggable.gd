extends Node

@export var enable_draggig := true
@export var enable_rotating := false
@export var enable_scaling := false
@export var rotation_hold_key : Key = KEY_CTRL

var dragging := false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		var parent = get_parent()
		if not parent:
			return
		
		if event is InputEventMouseMotion:
			if dragging:
				parent.position += event.relative.rotated(parent.rotation) * parent.scale
				parent.get_viewport().set_input_as_handled()
				parent.accept_event()
		
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if Rect2(Vector2.ZERO, parent.size).has_point(event.position):
					dragging = event.is_pressed()
					parent.get_viewport().set_input_as_handled()
					parent.accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP:
				if enable_rotating and Input.is_key_pressed(rotation_hold_key):
					var delta : float = PI * event.factor * 0.05
					if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: delta *= -1
					parent.rotation += delta
				elif enable_scaling:
					var delta : float = -0.1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else 0.1
					parent.scale *= 1 + delta
				else:
					return
				
				parent.get_viewport().set_input_as_handled()
				parent.accept_event()
