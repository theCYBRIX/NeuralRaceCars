extends Control

signal save_button_pressed(save_path : String, network_count : int)
signal exit_button_pressed

@onready var gen_label: Label = $MarginContainer/Columns/Items/PanelContainer/MarginContainer/VBoxContainer/GenLabel
@onready var batch_label: Label = $MarginContainer/Columns/Items/PanelContainer/MarginContainer/VBoxContainer/BatchLabel

@onready var graph: Control = $MarginContainer/Columns/VBoxContainer/HBoxContainer/ScrollContainer2/Items/Graph
@onready var graph_2: DataGraph = $MarginContainer/Columns/VBoxContainer/HBoxContainer/ScrollContainer2/Items/Graph2
@onready var manual_graph: DataGraph = $MarginContainer/Columns/VBoxContainer/HBoxContainer/ScrollContainer2/Items/ManualGraph
@onready var manual_graph_2: DataGraph = $MarginContainer/Columns/VBoxContainer/HBoxContainer/ScrollContainer2/Items/ManualGraph2

@onready var popout_component: Node = $PopoutComponent
@onready var popout_button: Button = $MarginContainer/Columns/VBoxContainer/HBoxContainer/VFlowContainer/PopoutButton
@onready var pause_button: Button = $MarginContainer/Columns/Items/VBoxContainer/ButtonRow/PauseButton
@onready var save_path_edit: LineEdit = $MarginContainer/Columns/Items/VBoxContainer/VBoxContainer/HBoxContainer/SavePathEdit
@onready var num_networks: SpinBox = $MarginContainer/Columns/Items/VBoxContainer/VBoxContainer/HBoxContainer2/NumNetworks
@onready var improvement_label: Label = $MarginContainer/Columns/Items/PanelContainer/MarginContainer/VBoxContainer/ImprovementLabel
@onready var since_randomized_label: Label = $MarginContainer/Columns/Items/PanelContainer/MarginContainer/VBoxContainer/SinceRandomizedLabel
@onready var browse_button: Button = $MarginContainer/Columns/Items/VBoxContainer/VBoxContainer/HBoxContainer/BrowseButton
@onready var color_rect_2: ColorRect = $ColorRect2
@onready var exit_dialog: ConfirmationDialog = $ExitDialog

@onready var time_elapsed_label: Label = $MarginContainer/Columns/Items/PanelContainer2/MarginContainer/VBoxContainer/TimeElapsedLabel
@onready var total_gens_label: Label = $MarginContainer/Columns/Items/PanelContainer2/MarginContainer/VBoxContainer/TotalGensLabel


@export var minimum_graph_size : Vector2


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	save_path_edit.text = SaveManager.DEFAULT_SAVE_FILE_PATH
	
	if minimum_graph_size:
		graph.custom_minimum_size = minimum_graph_size
		graph.custom_minimum_size = minimum_graph_size


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		match event.keycode:
			KEY_ESCAPE:
				if event.is_pressed():
					if popout_component.popped_out:
						popout_component.close_popout()
					else:
						toggle_pause()
			KEY_M:
				if event.is_pressed():
					visible = !visible
			_:
				return
		accept_event()
		get_viewport().set_input_as_handled()


func pause():
	get_tree().paused = true
	update_pause_button_state()


func resume():
	get_tree().paused = false
	update_pause_button_state()


func toggle_pause():
	get_tree().paused = !get_tree().paused
	update_pause_button_state()


func update_pause_button_state():
	pause_button.text = "Resume" if get_tree().paused else "Pause"


func _on_popout_button_pressed() -> void:
	popout_component.popout()


func _on_popout_component_popout_state_changed(popped_out: bool) -> void:
	popout_button.visible = not popped_out


func _on_pause_button_pressed() -> void:
	toggle_pause()


func _on_browse_button_pressed() -> void:
	browse_button.disabled = true
	browse_save_folder()


func browse_save_folder():
	var current_path := get_selected_save_path()
	
	var filters = FileFilter.get_file_filters([
		FileType.TYPE_JSON,
		FileType.TYPE_RES,
		FileType.TYPE_TRES
	])
	
	Util.browse_folder(FileDialog.FILE_MODE_SAVE_FILE, _on_file_selected, browse_button.set_disabled.bind(false), "Select save file", current_path, filters, FileDialog.Access.ACCESS_USERDATA)


func _on_file_selected(path : String) -> void:
	save_path_edit.set_text(Util.localize_path(path.replace("\\", "/")))


func get_selected_save_path() -> String:
	var current_path := save_path_edit.get_text()
	
	if (not current_path.is_empty()) and current_path.is_relative_path():
		current_path = Util.globalize_path(current_path)
	
	return current_path


func _on_file_manager_button_pressed() -> void:
	var save_path := Util.globalize_path(get_selected_save_path())
	
	if not FileAccess.file_exists(save_path) and not DirAccess.dir_exists_absolute(save_path):
		save_path = save_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(save_path):
			save_path = Util.USER_DATA_FOLDER
	
	OS.shell_show_in_file_manager(save_path)


func _on_save_button_pressed() -> void:
	var save_path := save_path_edit.get_text()
	save_button_pressed.emit(save_path, roundi(num_networks.value))


func _on_exit_button_pressed() -> void:
	exit_dialog.popup_on_parent(Rect2i(get_window().size / 2 - exit_dialog.min_size / 2, exit_dialog.min_size))


func _on_exit_dialog_confirmed() -> void:
	exit_button_pressed.emit()


func _on_visibility_changed() -> void:
	if visible and is_node_ready(): update_pause_button_state()
