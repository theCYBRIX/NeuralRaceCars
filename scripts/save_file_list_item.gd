class_name SaveFileListItem
extends PanelContainer

signal selected
signal pressed
signal deselected

@onready var file_name_label: Label = $MarginContainer/VBoxContainer/FileNameLabel
@onready var generations_label: Label = $MarginContainer/VBoxContainer/MarginContainer/Details/Column1/GenerationsLabel
@onready var training_time_label: Label = $MarginContainer/VBoxContainer/MarginContainer/Details/Column1/TrainingTimeLabel
@onready var highest_score_label: Label = $MarginContainer/VBoxContainer/MarginContainer/Details/Column2/HighestScoreLabel
@onready var num_networks_label: Label = $MarginContainer/VBoxContainer/MarginContainer/Details/Column2/NumNetworksLabel
@onready var network_visualizer: NetworkVisualizer = $MarginContainer/VBoxContainer/MarginContainer/Details/MarginContainer/NetworkVisualizer

@export_color_no_alpha var default_color : Color = 0x3A3A3AFF : set = set_default_color
@export_color_no_alpha var hovered_color : Color = 0x494949FF : set = set_hovered_color
@export_color_no_alpha var selected_color : Color = 0x555555FF : set = set_selected_color
@export_color_no_alpha var disabled_color : Color = 0x2E2E2EFF : set = set_disabled_color

var default_stylebox : StyleBoxFlat
var hovered_stylebox : StyleBoxFlat
var selected_stylebox : StyleBoxFlat
var disabled_stylebox : StyleBoxFlat

var parent_list : SaveFileList

var _hovered := false : set = _set_hovered
var _selected := false : set = set_selected
var disabled := false : set = set_disabled

const NOT_AVAILABLE := "N/A"

var file_name : String = NOT_AVAILABLE : set = set_file_name
var file_path : String : set = set_file_path
var file_contents : TrainingState : set = set_file_contents

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	child_order_changed
	var panel_stylebox = get_theme_stylebox("panel")
	default_stylebox = panel_stylebox.duplicate()
	default_stylebox.bg_color = default_color
	
	hovered_stylebox = panel_stylebox.duplicate()
	hovered_stylebox.bg_color = hovered_color
	
	selected_stylebox = panel_stylebox.duplicate()
	selected_stylebox.bg_color = selected_color
	
	disabled_stylebox = panel_stylebox.duplicate()
	disabled_stylebox.bg_color = disabled_color
	disabled_stylebox.border_color = Color.DARK_GRAY
	
	_update_style_overrides()
	
	update_file_name_label()
	update_detail_labels()
	update_network_visualizer()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			accept_event()
			if disabled: return
			if event.is_double_click():
				_selected = true
				pressed.emit()
			elif event.is_pressed():
				_selected = !_selected


func set_file_name(string_name : String) -> void:
	file_name = NOT_AVAILABLE if not string_name or string_name.is_empty() else string_name
	if is_node_ready():
		update_file_name_label()


func set_file_path(string_name : String) -> void:
	file_path = string_name
	update_file_contents()


func set_file_contents(state : TrainingState) -> void:
	file_contents = state
	if is_node_ready() and not is_queued_for_deletion():
		call_thread_safe("update_detail_labels")
		call_thread_safe("update_network_visualizer")


func update_network_visualizer() -> void:
	if not file_contents:
		return
	if not file_contents.networks or file_contents.networks.is_empty():
		return
	var first_network = file_contents.networks.front()
	if not first_network or not first_network.has("layout"):
		return
	if not first_network.layout:
		return
	var layout := NetworkLayout.from_dict(first_network.layout)
	network_visualizer.network_layout = layout


func _set_hovered(enabled : bool) -> void:
	_hovered = enabled
	if is_node_ready():
		_update_style_overrides()


func set_disabled(value : bool) -> void:
	disabled = value
	if disabled:
		_selected = false
	if is_node_ready():
		_update_style_overrides()


func set_selected(enabled : bool) -> void:
	if _selected == enabled: return
	
	_selected = enabled
	if _selected:
		selected.emit()
	else:
		deselected.emit()
	
	if is_node_ready():
		_update_style_overrides()


func is_selected() -> bool:
	return _selected


func set_default_color(color : Color) -> void:
	default_color = color
	if is_node_ready():
		default_stylebox.bg_color = default_color

func set_hovered_color(color : Color) -> void:
	hovered_color = color
	if is_node_ready():
		hovered_stylebox.bg_color = hovered_color

func set_selected_color(color : Color) -> void:
	selected_color = color
	if is_node_ready():
		selected_stylebox.bg_color = selected_color

func set_disabled_color(color : Color) -> void:
	disabled_color = color
	if is_node_ready():
		disabled_stylebox.bg_color = disabled_color


func update_file_name_label() -> void:
	file_name_label.text = file_name


func update_detail_labels() -> void:
	var generation := NOT_AVAILABLE
	var time_elapsed := NOT_AVAILABLE
	var highest_score := NOT_AVAILABLE
	var network_count := NOT_AVAILABLE
	
	if file_contents:
		network_count = str(file_contents.networks.size())
		if file_contents.generation > 0:
			generation = str(file_contents.generation)
		if roundi(file_contents.time_elapsed) > 0:
			time_elapsed = Util.format_time(roundi(file_contents.time_elapsed))
		if is_nan(file_contents.highest_score):
			highest_score = NOT_AVAILABLE
			file_contents.highest_score = 0
		else:
			highest_score = "%-3.2f" % [roundf(file_contents.highest_score * 100) / 100]
		
	generations_label.text = "Generations: " + generation
	training_time_label.text = "Time Elapsed: " + time_elapsed
	highest_score_label.text = "Highest Score: " + highest_score
	num_networks_label.text = "Network Count: " + network_count


func update_file_contents() -> void:
	file_contents = _load_training_state(file_path)


static func _load_training_state(file_path : String) -> TrainingState:
	var contents = SaveManager.load_training_state(file_path)
	if not contents: return null
	contents = SaveManager.convert_save_state(contents)
	return contents


func _update_style_overrides() -> void:
	_update_panel_stylebox()
	_update_font_color()


func _update_panel_stylebox() -> void:
	var stylebox : StyleBoxFlat
	if disabled:
		stylebox = disabled_stylebox
	elif _selected:
		stylebox = selected_stylebox
	elif _hovered:
		stylebox = hovered_stylebox
	else:
		stylebox = default_stylebox
	
	add_theme_stylebox_override("panel", stylebox)


func _update_font_color() -> void:
	const theme_parent := "Button"
	
	var color : Color
	if disabled:
		color = get_theme_color("font_disabled_color", theme_parent)
	elif _selected:
		color = get_theme_color("font_focus_color", theme_parent)
	elif _hovered:
		color = get_theme_color("font_hover_color", theme_parent)
	else:
		color = get_theme_color("font_color", theme_parent)
	
	for label in [file_name_label, generations_label, training_time_label, highest_score_label, num_networks_label]:
		label.add_theme_color_override("font_color", color)


func _on_mouse_entered() -> void:
	_hovered = true


func _on_mouse_exited() -> void:
	_hovered = false
