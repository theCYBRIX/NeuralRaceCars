extends Node

signal popout_state_changed(popped_out : bool)

@export var window_title := "Popout"
@export var initial_pos : Vector2i
@export var initial_size : Vector2i
@export var keep_position := false
@export var relative_position := false
@export var keep_size := false
@export var relative_size := false
var initial_pos_larger := true

var original_parent : Node
var popout_window : Window
var popped_out := false : set = set_popped_out


func _ready() -> void:
	var root_window = get_tree().get_root()
	if not initial_pos: initial_pos = root_window.position
	if not initial_size: initial_size = root_window.size
	if relative_position: initial_pos = root_window.position - initial_pos - Vector2i(root_window.size.x, 0)
	if relative_size: initial_size = root_window.size - initial_size

func popout(header_text := window_title, size := initial_size, position := initial_pos):
	if is_instance_valid(popout_window): return
	
	popout_window = Window.new()
	popout_window.close_requested.connect(set_popped_out.bind(false))
	
	get_tree().get_root().add_child(popout_window)
	popout_window.title = header_text
	
	if relative_position or relative_size:
		var root_window = get_tree().get_root()
		if relative_size:
			size = root_window.size + size
		if relative_position:
			if initial_pos_larger:
				position += root_window.position + Vector2i(root_window.size.x, 0)
			else:
				position += root_window.position - Vector2i(size.x, 0)
	
	popout_window.size = size
	popout_window.position = position
	
	original_parent = get_parent().get_parent()
	get_parent().reparent(popout_window)
	
	popped_out = true
	popout_state_changed.emit(popped_out)

func close_popout():
	if not is_instance_valid(popout_window): return
	
	if keep_position or keep_size:
		var root_window = get_tree().get_root()
		if keep_size:
			initial_size = popout_window.size
			if relative_size: initial_size -= root_window.size 
		if keep_position:
			initial_pos = popout_window.position
			if relative_position:
				initial_pos_larger = initial_pos >= root_window.position
				if initial_pos_larger:
					initial_pos -= root_window.position + Vector2i(root_window.size.x, 0)
				else:
					initial_pos -= root_window.position - Vector2i(popout_window.size.x, 0)
	
	get_parent().reparent(original_parent)
	popout_window.queue_free()
	
	popped_out = false
	popout_state_changed.emit(popped_out)

func set_popped_out(enabled := true):
	if popped_out == enabled: return
	popped_out = enabled
	
	if enabled:
		popout()
	else:
		close_popout()
