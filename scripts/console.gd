extends Control


@export var java_process_manager: JavaProcessManager : set = set_java_process_manager
@export var autostart := false
@export var auto_scroll := true : set = set_auto_scroll

@onready var text_edit: TextEdit = $MarginContainer/VBoxContainer/TextEdit
@onready var line_edit: LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/LineEdit
@onready var auto_scroll_option: CheckBox = $MarginContainer/VBoxContainer/AutoScrollOption
@onready var margin_container: MarginContainer = $MarginContainer


func _ready() -> void:
	if not Engine.is_editor_hint() and autostart and java_process_manager:
		java_process_manager.start()


func _interpret_input(input : String) -> bool:
	match input.strip_edges().to_lower():
		"clear", "cls":
			text_edit.clear()
		_:
			return false
	return true


func send_input() -> void:
	var input := line_edit.text
	line_edit.clear()
	if not _interpret_input(input):
		input += "\n"
		if java_process_manager and java_process_manager.is_running():
			java_process_manager.write_std_in(input)
		_append_text_edit(input)


func scroll_to_bottom() -> void:
	var scroll_pos := text_edit.get_scroll_pos_for_line(text_edit.get_line_count() - 1)
	text_edit.scroll_vertical = scroll_pos


func _append_text_edit(str : String) -> void:
	var prev_scroll := text_edit.scroll_vertical
		
	text_edit.text += str
	text_edit.scroll_vertical = prev_scroll
	
	if auto_scroll:
		scroll_to_bottom()


func set_java_process_manager(manager : JavaProcessManager) -> void:
	if java_process_manager:
		Util.disconnect_from_signal(_on_java_process_manager_message_received, java_process_manager.message_received)
		Util.disconnect_from_signal(_on_java_process_manager_err_message_received, java_process_manager.err_message_received)
	
	java_process_manager = manager
	
	if java_process_manager:
		java_process_manager.message_received.connect(_on_java_process_manager_message_received)
		java_process_manager.err_message_received.connect(_on_java_process_manager_err_message_received)


func set_auto_scroll(enabled : bool) -> void:
	if auto_scroll == enabled:
		return
	auto_scroll = enabled
	auto_scroll_option.set_pressed_no_signal(auto_scroll)
	if auto_scroll:
		scroll_to_bottom()


func _on_send_button_pressed() -> void:
	send_input()


func _on_line_edit_text_submitted(new_text: String) -> void:
	send_input()


func _on_java_process_manager_err_message_received(msg: String) -> void:
	_append_text_edit(msg)


func _on_java_process_manager_message_received(msg: String) -> void:
	_append_text_edit(msg)


func _on_auto_scroll_option_toggled(toggled_on: bool) -> void:
	auto_scroll = toggled_on


func _get_minimum_size() -> Vector2:
	if margin_container:
		return margin_container.get_minimum_size()
	else:
		return Vector2.ZERO
