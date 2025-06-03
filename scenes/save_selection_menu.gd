extends Control

signal item_pressed(list_item : SaveFileListItem)

@onready var save_file_list: SaveFileList = $VBoxContainer/SaveFileList
@onready var folder_path_edit: LineEdit = $VBoxContainer/MarginContainer/HBoxContainer/FolderPathEdit
@onready var load_button: Button = $VBoxContainer/MarginContainer2/Control/LoadButton
@onready var browse_button: Button = $VBoxContainer/MarginContainer/HBoxContainer/BrowseButton
@onready var refresh_button: Button = $VBoxContainer/MarginContainer/HBoxContainer/RefreshButton
@onready var sort_options: OptionButton = $VBoxContainer/MarginContainer/HBoxContainer/SortOptions

@export var initial_path := SaveManager.DEFAULT_SAVE_DIR_PATH

var _refresh_task_id : int = -1
var _task_id_valid := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	folder_path_edit.text = initial_path
	_on_refresh_button_pressed()
	
	for item in SaveFileList.SortBy.values():
		sort_options.add_item("Sort by " + SaveFileList.SortBy.keys()[item].capitalize(), item)


func browse_folder():
	browse_button.disabled = true
	save_file_list.disabled = true
	var current_path := Util.globalize_path(folder_path_edit.text)
	if FileAccess.file_exists(current_path):
		current_path = current_path.get_base_dir()
	var reenable_ui := func():
		browse_button.disabled = false
		save_file_list.disabled = false
	await get_tree().create_timer(0.25).timeout
	Util.browse_folder(FileDialog.FILE_MODE_OPEN_DIR, _on_folder_selected, reenable_ui, "Select Folder", current_path, [], FileDialog.Access.ACCESS_FILESYSTEM)


func switch_to_state(state : TrainingState):
	save_file_list.disabled = true
	#TODO: Allow selection
	GameSettings.track_scene = preload("res://scenes/track_3.tscn")
	GameSettings.training_state = state
	var prev_scene := SceneManager.set_scene(SceneManager.Scene.TRAINING)
	await _release_refresh_thread()
	prev_scene.queue_free()


func refresh_save_file_list():
	refresh_button.disabled = true
	await _release_refresh_thread()
	_refresh_task_id = WorkerThreadPool.add_task(save_file_list.refresh_file_list.bind(folder_path_edit.text))
	_task_id_valid = true
	await save_file_list.list_updated
	_update_list_sorting()
	refresh_button.disabled = false


func _on_folder_selected(path : String) -> void:
	folder_path_edit.text = Util.localize_path(path)
	refresh_save_file_list()


func _on_refresh_button_pressed() -> void:
	refresh_save_file_list()


func _on_back_button_pressed() -> void:
	await _release_refresh_thread()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_browse_button_pressed() -> void:
	browse_folder()


func _on_load_button_pressed() -> void:
	var selected_items := save_file_list.get_selected_items()
	if not selected_items or selected_items.is_empty(): return
	switch_to_state(selected_items[0].file_contents)


func _on_save_file_list_item_pressed(list_item: SaveFileListItem) -> void:
	if not list_item: return
	switch_to_state(list_item.file_contents)


func _release_refresh_thread() -> void:
	if _task_id_valid:
		if not WorkerThreadPool.is_task_completed(_refresh_task_id):
			await save_file_list.list_updated
		WorkerThreadPool.wait_for_task_completion(_refresh_task_id)
		_task_id_valid = false


func _on_save_file_list_selection_count_changed(num_selected: int) -> void:
	load_button.disabled = (num_selected != 1)


func _on_sort_options_item_selected(index: int) -> void:
	save_file_list.sorting_order = save_file_list.SortBy.values()[index]


func _update_list_sorting() -> void:
	if not is_node_ready():
		return
	
	save_file_list.wait_for_worker_tasks()
	
