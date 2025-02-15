extends Node

const TRAINING_STATE_FILE_EXTENSION := FileType.TYPE_JSON
const DEFAULT_SAVE_DIR_PATH := "user://"
const DEFAULT_SAVE_FILE_PATH := DEFAULT_SAVE_DIR_PATH + "training_state." + TRAINING_STATE_FILE_EXTENSION

var _load_error : Error = OK : get = get_load_error


func save_training_state(training_state : TrainingState, save_path : String, overwrite := false) -> Error:
	var extension := save_path.get_extension()
	if extension == "": extension = TRAINING_STATE_FILE_EXTENSION
	match extension:
		FileType.TYPE_RES, FileType.TYPE_TRES:
			return save_training_state_res(training_state, save_path, overwrite)
		FileType.TYPE_JSON:
			return save_training_state_json(training_state, save_path, overwrite)
		_:
			return ERR_FILE_MISSING_DEPENDENCIES


func load_training_state(path : String, default_value : TrainingState = null) -> TrainingState:
	var extension := path.get_extension()
	if extension == "":
		extension = TRAINING_STATE_FILE_EXTENSION
		path += "." + extension
	match extension:
		FileType.TYPE_RES, FileType.TYPE_TRES:
			return load_training_state_res(path, default_value)
		FileType.TYPE_JSON:
			return load_training_state_json(path, default_value)
		_:
			return default_value


func load_training_state_res(path : String, default_value : TrainingState = null) -> TrainingState:
	path = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(path): return _load_error_occurred(path, ERR_FILE_NOT_FOUND, default_value)
	var loaded_state = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not loaded_state: return _load_error_occurred(path, ERR_PARSE_ERROR, default_value)
	if not (loaded_state is TrainingState): return _load_error_occurred(path, ERR_INVALID_DATA, default_value)
	return loaded_state


func load_training_state_json(path : String, default_value : TrainingState = null) -> TrainingState:
	path = ProjectSettings.globalize_path(path)
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return _load_error_occurred(path, FileAccess.get_open_error())
	
	var file_contents = file.get_as_text()
	var error = file.get_error()
	file.close()
	if error != OK: return _load_error_occurred(path, error)
	
	var parser := JSON.new()
	error = parser.parse(file_contents)
	if error != OK: return _json_parse_error_occurred(path, error, parser.get_error_line(), parser.get_error_message(), default_value)
	return convert_save_state(parser.data)


func save_training_state_res(training_state : TrainingState, save_path : String, overwrite := false) -> Error:
	if save_path.get_extension() != TRAINING_STATE_FILE_EXTENSION: save_path += "." + TRAINING_STATE_FILE_EXTENSION
	if not overwrite: Util.make_path_unique(save_path)
	return ResourceSaver.save(training_state, save_path)


func save_training_state_json(training_state : TrainingState, path := DEFAULT_SAVE_DIR_PATH, overwrite := false) -> Error:
	if path.get_extension() != TRAINING_STATE_FILE_EXTENSION: path += "." + TRAINING_STATE_FILE_EXTENSION
	if not overwrite: path = Util.make_path_unique(path)
	var save_file = FileAccess.open(path, FileAccess.WRITE)
	if not save_file: return FileAccess.get_open_error()
	save_file.store_string(JSON.stringify(training_state.to_dict(), "", true, true))
	save_file.close()
	return OK


func can_load_file(path : String) -> bool:
	match path.get_extension():
		FileType.TYPE_JSON, FileType.TYPE_RES, FileType.TYPE_TRES:
			return true
	return false


func convert_save_state(state) -> TrainingState:
	if state is TrainingState:
		return state
	
	var converted : TrainingState
	
	var data = state.data if state is JSON else state
	
	if data is Dictionary:
		converted = TrainingState.from_dict(state)
		
	elif data is Array:
		converted = TrainingState.new()
		converted.networks = data
	
	return converted

func get_load_error() -> Error:
	return _load_error


func _json_parse_error_occurred(file_path : String, error : Error, error_line : int, error_message : String, return_value : Variant = null) -> Variant:
	_load_error = error
	push_warning("Error on line %d when parsing file %s: %s" %[error_line, file_path, error_message])
	return return_value


func _load_error_occurred(file_path : String, error : Error, return_value : Variant = null) -> Variant:
	_load_error = error
	push_load_warning(file_path, error)
	return return_value


func push_load_warning(file_path : String, error : Error) -> void:
	push_warning("Failed to load file %s: %s" %[file_path, error_string(error)])
