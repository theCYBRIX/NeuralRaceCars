class_name SaveFileList
extends PanelContainer

signal list_updated(item_count : int)
signal selection_count_changed(num_selected : int)
signal item_pressed(list_item : SaveFileListItem)

const SAVE_FILE_LIST_ITEM = preload("res://scenes/ui/save_file_list_item.tscn")

enum SortBy {
	DATE,
	NAME,
}

@export var allow_select_multiple := false

var disabled := false : set = set_disabled, get = is_disabled

var sorting_order : SortBy = SortBy.DATE : set = set_sorting_order

var _sorting_method : Callable = sort_by_date.bind(false)

var _selected_items : Array[SaveFileListItem] = [] : set = set_selected_items

var _item_array : Array[SaveFileListItem] = []
var _file_paths : Dictionary = {}

var _worker_thread_tasks : Array[int] = []

@onready var list_items: VBoxContainer = $VBoxContainer/MarginContainer4/ScrollContainer/MarginContainer/ListItems
@onready var scroll_container: ScrollContainer = $VBoxContainer/MarginContainer4/ScrollContainer

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_action("ui_accept"):
			if event.is_pressed() and _is_item_selected():
				call_deferred("emit_signal", "item_pressed", _selected_items)
		elif event.is_action("ui_up"):
			if event.is_pressed():
				_select_next_list_item(-1)
		elif event.is_action("ui_down"):
			if event.is_pressed():
				_select_next_list_item(1)
		else:
			return
		get_viewport().set_input_as_handled()
		accept_event()


func _select_next_list_item(offset : int = 1) -> bool:
	if offset == 0:
		return false
	
	if _item_array.size() > 1:
		var current_index : int 
		if _is_item_selected():
			current_index = _item_array.find(_selected_items)
		elif offset > 0:
			current_index = -1
		else:
			current_index = _item_array.size()
		
		var next_index : int = (current_index + offset) % _item_array.size()
		if next_index < 0:
			next_index += _item_array.size()
		_item_array[next_index].set_selected(true)
		scroll_container.ensure_control_visible(_item_array[next_index])
	else:
		_item_array.front().set_selected(true)
	
	return true


func refresh_file_list(path : String) -> Error:
	call_deferred("_free_all", _item_array.duplicate())
	
	path = Util.globalize_path(path)
	
	if not DirAccess.dir_exists_absolute(path):
		push_warning("The specified path does not exist or is not a directory: " + path)
		return ERR_FILE_NOT_FOUND
	
	var folder := DirAccess.open(path)
	if not folder: return DirAccess.get_open_error()
	
	var files : Array[String] = []
	files.append_array(folder.get_files())
	files = files.filter(SaveManager.can_load_file)
	
	_item_array.clear()
	_file_paths.clear()
	
	var load_file_tasks : Array[Callable] = []
	
	for file in files:
		var list_item := SAVE_FILE_LIST_ITEM.instantiate()
		list_item.file_name = file.get_file()
		load_file_tasks.append(list_item.set_file_path.bind(path + "\\" + file))
		list_item.selected.connect(_on_item_selected.bind(list_item))
		list_item.deselected.connect(_on_item_deselected.bind(list_item))
		list_item.pressed.connect(_on_item_pressed.bind(list_item))
		list_item.disabled = disabled
		list_items.call_deferred("add_child", list_item, false, Node.INTERNAL_MODE_FRONT)
		_item_array.append(list_item)
		_file_paths[list_item] = file
	
	var task_id := WorkerThreadPool.add_task(
		func():
			for task in load_file_tasks:
				task.call()
	)
	_worker_thread_tasks.append(task_id)
	await wait_for_worker_tasks()
	
	_sort_item_array()
	call_deferred("_update_item_order")
	
	call_deferred("_item_count_changed")
	
	return OK


func refresh_file_list_asynch(path : String) -> void:
	_worker_thread_tasks.append(WorkerThreadPool.add_task(refresh_file_list.bind(path)))


func wait_for_worker_tasks() -> void:
	while _worker_thread_tasks.size() > 0:
		WorkerThreadPool.wait_for_task_completion(_worker_thread_tasks.pop_back())



func _exit_tree() -> void:
	if _worker_thread_tasks.is_empty():
		return
	if is_queued_for_deletion():
		cancel_free()
	
	wait_for_worker_tasks()
	
	queue_free()


#NOTE: Side effect - Does not keep track of previous disabled state of list items
func set_disabled(value := true):
	if disabled == value: return
	disabled = value
	
	for item in _item_array:
		item.disabled = disabled


func set_sorting_order(order : SortBy) -> void:
	if sorting_order == order:
		return
	
	sorting_order = order
	
	match sorting_order:
		SortBy.DATE:
			_sorting_method = sort_by_date.bind(false)
		SortBy.NAME:
			_sorting_method = sort_by_name.bind(true)
	
	_sort_item_array()
	_update_item_order()


func _update_item_order() -> void:
	var new_index : int = 0
	for item in _item_array:
		var current_index := item.get_index(true)
		if current_index != new_index:
			list_items.move_child(item, new_index)
		new_index += 1


func _sort_item_array() -> void:
	_item_array.sort_custom(_sorting_method)


static func sort_by_date(a : SaveFileListItem, b : SaveFileListItem, ascending := true) -> bool:
	var a_modified := FileAccess.get_modified_time(a.file_path)
	var b_modified := FileAccess.get_modified_time(b.file_path)
	if a_modified == 0:
		push_warning("File not Found: \"%s\"" % a.file_path)
	if b_modified == 0:
		push_warning("File not Found: \"%s\"" % b.file_path)
	var a_smaller := a_modified < b_modified
	return a_smaller if ascending else not a_smaller


static func sort_by_name(a : SaveFileListItem, b : SaveFileListItem, ascending := true) -> bool:
	return a.file_name.filenocasecmp_to(b.file_name) > 0 if ascending else a.file_name.filenocasecmp_to(b.file_name) < 0


func is_disabled() -> bool:
	return disabled


func clear():
	_free_all(_item_array)
	_item_array.clear()
	
	_item_count_changed()


func _free_all(list_items : Array[SaveFileListItem]):
	for item in list_items:
		item.queue_free()


func _item_count_changed():
	list_updated.emit(_item_array.size())


func get_selected_items() -> Array[SaveFileListItem]:
	if _is_item_selected():
		return _selected_items
	return []


func _is_item_selected():
	return not _selected_items.is_empty()


func _on_item_selected(list_item : SaveFileListItem):
	if not allow_select_multiple:
		deselect_all()
	if not list_item in _selected_items:
		_selected_items.append(list_item)
		selection_count_changed.emit(_selected_items.size())


func _on_item_deselected(list_item : SaveFileListItem):
	_selected_items.erase(list_item)
	selection_count_changed.emit(_selected_items.size())


func _on_item_pressed(list_item : SaveFileListItem):
	item_pressed.emit(list_item)


func set_selected_items(items : Array[SaveFileListItem]):
	if not _selected_items.is_empty():
		deselect_all()
	
	items = items.filter(func(x): return x in _item_array)
	
	if (not allow_select_multiple) and (not items.is_empty()):
		items = [items.front()]
	
	_selected_items.resize(items.size())
	var index : int = 0
	for item in items:
		item.set_block_signals(true)
		item.set_selected(true)
		_selected_items[index] = item
		item.set_block_signals(false)
		index += 1
	selection_count_changed.emit(_selected_items.size())


func deselect_all():
	for item in _selected_items:
		if not is_instance_valid(item):
			continue
		item.set_block_signals(true)
		item.set_selected(false)
		item.set_block_signals(false)
	_selected_items.clear()
	selection_count_changed.emit(_selected_items.size())
