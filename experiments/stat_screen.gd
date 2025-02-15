extends Control

@onready var columns: HBoxContainer = $MarginContainer/Columns

func add_column_child(column_idx : int, child : Control) -> bool:
	if not check_valid_column_index(column_idx):
		return false
	
	columns.get_child(column_idx).add_child(child)
	
	return true

func insert_column(index : int):
	if not check_valid_column_index(index, true):
		return
	
	columns.add_child(__new_column())

func remove_column(index : int, free_children := false ) -> Array[Node]:
	if not check_valid_column_index(index):
		return []
	
	var column := columns.get_child(index)
	var children := column.get_children()
	
	if free_children:
		children.clear()
	else:
		for child in children:
			column.remove_child(child)
	
	column.free()
	
	return children


func check_valid_column_index(index : int, inserting := false) -> bool:
	var max_index := columns.get_child_count() - (0 if inserting else 1)
	if index < 0 or index > max_index:
		push_error("Index %d is out of bounds for range [0, %d]" % [index, max_index])
		return false
	return true


func __new_column() -> ScrollContainer:
	var scroll_container := ScrollContainer.new()
	var v_box_container := VBoxContainer.new()
	
	scroll_container.add_child(v_box_container)
	
	scroll_container.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	v_box_container.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	
	return scroll_container
