class_name SaveFileList
extends PanelContainer

signal list_updated(item_count : int)
signal item_selected
signal item_deselected
signal item_pressed(list_item : SaveFileListItem)

const SAVE_FILE_LIST_ITEM = preload("res://scenes/ui/save_file_list_item.tscn")

@onready var list_items: VBoxContainer = $VBoxContainer/MarginContainer4/ScrollContainer/MarginContainer/ListItems

var selected_item : SaveFileListItem : set = set_selected_item

var _item_array : Array[SaveFileListItem] = []

func refresh_file_list(path : String) -> Error:
	call_deferred("_free_all", _item_array.duplicate())
	
	path = CommonTools.globalize_path(path)
	
	if not DirAccess.dir_exists_absolute(path):
		push_warning("The specified path does not exist or is not a directory: " + path)
		return ERR_FILE_NOT_FOUND
	
	var folder := DirAccess.open(path)
	if not folder: return DirAccess.get_open_error()
	
	var files : Array[String] = []
	files.append_array(folder.get_files())
	files = files.filter(SaveManager.can_load_file)
	
	_item_array.clear()
	
	for file in files:
		var contents = SaveManager.load_training_state(path + "\\" + file)
		if not contents: continue
		contents = SaveManager.convert_save_state(contents)
		var list_item := SAVE_FILE_LIST_ITEM.instantiate()
		list_item.file_name = file.get_file()
		list_item.file_contents = contents
		list_item.selected.connect(_on_item_selected.bind(list_item))
		list_item.pressed.connect(_on_item_pressed.bind(list_item))
		list_items.call_deferred("add_child", list_item, false, Node.INTERNAL_MODE_FRONT)
		
		_item_array.append(list_item)
	
	call_deferred("_item_count_changed")
	
	return OK
	

func clear():
	_free_all(_item_array)
	_item_array.clear()
	
	_item_count_changed()


func _free_all(list_items : Array[SaveFileListItem]):
	for item in list_items:
		item.queue_free()


func _item_count_changed():
	list_updated.emit(_item_array.size())


func get_selected_item() -> SaveFileListItem:
	var selected : SaveFileListItem = null
	if selected_item and is_instance_valid(selected_item) and selected_item.is_selected():
		selected = selected_item
	return selected

func _on_item_selected(list_item : SaveFileListItem):
	set_selected_item(list_item)

func _on_item_deselected(_list_item : SaveFileListItem):
	item_deselected.emit()

func _on_item_pressed(list_item : SaveFileListItem):
	item_pressed.emit(list_item)

func set_selected_item(list_item : SaveFileListItem):
	if selected_item:
		if selected_item != list_item and is_instance_valid(selected_item):
			selected_item.set_selected(false)
	selected_item = list_item
	list_item.deselected.connect(_on_item_deselected.bind(list_item), CONNECT_ONE_SHOT)
	item_selected.emit()
