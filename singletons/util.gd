extends Node


const INT_32_MAX_VALUE := 0xFFFFFFFF

const SECONDS_PER_MINUTE : int = 60
const SECONDS_PER_HOUR : int = 3600
const SECONDS_PER_DAY : int = 86400
const MINUTES_PER_HOUR : int = 60
const HOURS_PER_DAY : int = 24


var USER_DATA_FOLDER : String = ProjectSettings.globalize_path("user://")


func localize_path(path : String) -> String:
	if not FileAccess.file_exists(path) and DirAccess.dir_exists_absolute(path): if not path.ends_with("/"): path += "/"
	if path.begins_with(USER_DATA_FOLDER):
		path = "user://" + path.substr(USER_DATA_FOLDER.length(), path.length() - USER_DATA_FOLDER.length())
	else:
		path = ProjectSettings.localize_path(path)
	return path


func globalize_path(path : String) -> String:
	return ProjectSettings.globalize_path(path)


func make_path_unique(path := SaveManager.DEFAULT_SAVE_FILE_PATH) -> String:
	var extension := path.get_extension()
	if not extension.is_empty(): extension = "." + extension
	var raw_path := path.get_basename()
	var duplicate_number : int = 0
	var unique_path := path
	while FileAccess.file_exists(unique_path):
		duplicate_number += 1
		unique_path = raw_path + ("(%d)" % duplicate_number) + extension
	return unique_path


func browse_folder(file_mode : FileDialog.FileMode, on_item_selected : Callable, on_dialog_dispose : Callable, title := "Browse", initial_path : String = USER_DATA_FOLDER, filters : Array[FileFilter] = [], access : FileDialog.Access = FileDialog.Access.ACCESS_FILESYSTEM):
	var dialog = FileDialog.new()
	dialog.title = title
	dialog.access = access
	dialog.file_mode = file_mode
	
	initial_path = Util.globalize_path(initial_path)
	
	for filter in filters:
		dialog.add_filter("*." + filter.file_extension, filter.description)
	
	if file_mode != FileDialog.FILE_MODE_OPEN_DIR and FileAccess.file_exists(initial_path):
		if filters.is_empty() or filters.has(initial_path.get_extension()):
			dialog.current_file = initial_path
		else:
			dialog.current_path = initial_path.get_base_dir()
			dialog.current_file = initial_path.get_base_dir()
	elif DirAccess.dir_exists_absolute(initial_path):
		dialog.current_path = initial_path
		dialog.current_file = initial_path
	else:
		dialog.current_path = USER_DATA_FOLDER
		dialog.current_file = USER_DATA_FOLDER
	
	dialog.dialog_hide_on_ok = true
	dialog.use_native_dialog = true
	
	var free_dialog := func(_x): dialog.queue_free()
	
	if file_mode == FileDialog.FileMode.FILE_MODE_OPEN_ANY or file_mode == FileDialog.FileMode.FILE_MODE_OPEN_DIR:
		dialog.dir_selected.connect(on_item_selected, CONNECT_ONE_SHOT)
		dialog.dir_selected.connect(free_dialog, CONNECT_ONE_SHOT)
	if file_mode == FileDialog.FileMode.FILE_MODE_OPEN_ANY or file_mode != FileDialog.FileMode.FILE_MODE_OPEN_DIR:
		dialog.file_selected.connect(on_item_selected, CONNECT_ONE_SHOT)
		dialog.file_selected.connect(free_dialog, CONNECT_ONE_SHOT)
	
	dialog.canceled.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.confirmed.connect(dialog.queue_free, CONNECT_ONE_SHOT)
	dialog.tree_exiting.connect(on_dialog_dispose, CONNECT_ONE_SHOT)
	get_tree().get_root().add_child(dialog)
	dialog.show()

@warning_ignore("integer_division")
func format_time(seconds : int) -> String:
	
	var formatted := "%ds" % (seconds % SECONDS_PER_MINUTE)
	
	if seconds > SECONDS_PER_MINUTE:
		formatted = ("%dm " % ((seconds / SECONDS_PER_MINUTE) % MINUTES_PER_HOUR)) + formatted
	if seconds > SECONDS_PER_HOUR:
		formatted = ("%dh " % ((seconds / SECONDS_PER_HOUR) % HOURS_PER_DAY)) + formatted
	if seconds > SECONDS_PER_DAY:
		formatted = ("%dd " % (seconds / SECONDS_PER_DAY)) + formatted
	
	return formatted


func disconnect_from_signal(callable : Callable, from : Signal) -> bool:
	if from.is_connected(callable):
		from.disconnect(callable)
		return true
	return false
