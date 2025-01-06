extends Control

signal item_pressed(list_item : SaveFileListItem)


@onready var save_file_list: SaveFileList = $VBoxContainer/SaveFileList
@onready var folder_path_edit: LineEdit = $VBoxContainer/MarginContainer/HBoxContainer/FolderPathEdit
@onready var load_button: Button = $VBoxContainer/MarginContainer2/Control/LoadButton
@onready var browse_button: Button = $VBoxContainer/MarginContainer/HBoxContainer/BrowseButton
@onready var refresh_button: Button = $VBoxContainer/MarginContainer/HBoxContainer/RefreshButton

@export var initial_path := SaveManager.DEFAULT_SAVE_DIR_PATH

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	folder_path_edit.text = initial_path
	_on_refresh_button_pressed()


func browse_folder():
	browse_button.set_disabled(true)
	var current_path := CommonTools.globalize_path(folder_path_edit.text)
	if FileAccess.file_exists(current_path):
		current_path = current_path.get_base_dir()
	CommonTools.browse_folder(FileDialog.FILE_MODE_OPEN_DIR, _on_folder_selected, browse_button.set_disabled.bind(false), "Select Folder", current_path, [], FileDialog.Access.ACCESS_USERDATA)


func load_state(state : TrainingState):
	GameSettings.training_state = state
	get_tree().change_scene_to_file("res://scenes/game_area.tscn")


func _on_folder_selected(path : String) -> void:
	folder_path_edit.text = CommonTools.localize_path(path)


func _on_refresh_button_pressed() -> void:
	refresh_button.disabled = true
	WorkerThreadPool.add_task(save_file_list.refresh_file_list.bind(folder_path_edit.text))
	await save_file_list.list_updated
	refresh_button.disabled = false
	


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_browse_button_pressed() -> void:
	browse_folder()


func _on_file_list_item_deselected() -> void:
	load_button.disabled = true


func _on_file_list_item_selected() -> void:
	load_button.disabled = false


func _on_load_button_pressed() -> void:
	var selected_item = save_file_list.get_selected_item()
	if not selected_item: return
	load_state(selected_item.file_contents)


func _on_save_file_list_item_pressed(list_item: SaveFileListItem) -> void:
	if not list_item: return
	load_state(list_item.file_contents)
