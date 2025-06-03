class_name DataGraph
extends Control

const POPUP_ALWAYS_SHOW_LEGEND : int = 0
const POPUP_FILL_VOLUME : int = 1
const POPUP_LIMIT_MAX_VALUE : int = 2
const POPUP_LIMIT_MIN_VALUE : int = 3

@onready var graphing_area: Control = $Panel/VBoxContainer/Control/MarginContainer3/GraphingArea
@onready var legend: MarginContainer = $Panel/VBoxContainer/Legend
@onready var legend_container: HFlowContainer = $Panel/VBoxContainer/Legend/HFlowContainer
@onready var max_label : Label = $Panel/VBoxContainer/Control/MarginContainer/MaxLabel
@onready var current_label: Label = $Panel/VBoxContainer/Control/MarginContainer/CurrentLabel
@onready var min_label : Label = $Panel/VBoxContainer/Control/MarginContainer2/MinLabel
@onready var top_border: Line2D = $Panel/VBoxContainer/Control/MarginContainer3/GraphingArea/TopBorder
@onready var bottom_border: Line2D = $Panel/VBoxContainer/Control/MarginContainer3/GraphingArea/BottomBorder
@onready var update_timer: Timer = $UpdateTimer

@export var resolution : int = 100 : set = set_resolution
@export var update_period : float = 0.2 : set = set_update_period
@export var realtime : bool = false : set = set_realtime
@export var auto_update : bool = true : set = set_auto_update
@export var always_show_legend : bool = true : set = set_always_show_legend
@export var show_legend_on_hover : bool = true : set = set_show_legend_on_hover
@export var fill_volume : bool = true : set = set_fill_volume

@export_group("Limits")
@export_subgroup("Maximum", "max_value")
@export var max_value_use_padding := false
@export var max_value_padding_mode := PaddingMode.FRACTION
@export var max_value_padding := 0.0 : set = set_max_value_padding
@export var max_value_restrict_floor := false : set = set_limit_max_value
@export var max_value_floor := 0.0
@export_subgroup("Minimum", "min_value")
@export var min_value_use_padding := false
@export var min_value_padding_mode := PaddingMode.FRACTION
@export var min_value_padding := 0.0 : set = set_min_value_padding
@export var min_value_restrict_ceiling := false : set = set_limit_min_value
@export var min_value_cieling := 0.0


enum PaddingMode {
	FRACTION,
	VALUE
}


var series : Dictionary = {}

var graphing_area_size : Vector2

var maximum : float = max_value_floor if max_value_restrict_floor else -INF
var minimum : float = min_value_cieling if min_value_restrict_ceiling else INF
var max_value : float = -INF
var min_value : float = INF
var value_range : float
var range_updated : bool = false

var popup_menu : PopupMenu = PopupMenu.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	graphing_area_size = graphing_area.get_size()
	legend.visible = always_show_legend
	set_update_period(update_period)
	if not realtime and auto_update: update_timer.start()
	popup_menu.add_check_item("Always Show Legend", POPUP_ALWAYS_SHOW_LEGEND)
	popup_menu.add_check_item("Fill Volume", POPUP_FILL_VOLUME)
	popup_menu.add_check_item("Limit Max Value", POPUP_LIMIT_MAX_VALUE)
	popup_menu.add_check_item("Limit Min Value", POPUP_LIMIT_MIN_VALUE)
	popup_menu.id_pressed.connect(_on_popup_menu_id_pressed)
	popup_menu.visibility_changed.connect(__unparent_popup, CONNECT_DEFERRED)
	__update_popup_state()


func _process(_delta: float) -> void:
	update_all()
	if not realtime: set_process(false)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var window := get_window()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				window.add_child(popup_menu)
				popup_menu.popup_on_parent(Rect2i(Vector2i(get_global_mouse_position()), popup_menu.min_size))
				#popup_menu.current_screen = window.current_screen
				#popup_menu.position = window.get_mouse_position()
		elif popup_menu.visible:
			popup_menu.hide()


func update_all() -> void:
	update_series()
	if range_updated:
		redraw_graph()
		min_label.set_text("%-3.2f" % minimum)
		max_label.set_text("%-3.2f" % maximum)
		range_updated = false
	else:
		update_graph()
	
	var active_count : int = 0
	var active_series : GraphSeries
	for s : GraphSeries in series.values():
		if s.enabled:
			active_count += 1
			active_series = s
	
	if active_count == 1:
		current_label.visible = true
		current_label.text = "%-3.2f" % active_series.points.get_item(active_series.points.size() - 1)
	elif current_label.visible:
		current_label.visible = false


func clear_data_points():
	for s : GraphSeries in series.values():
		s.clear()


func has_series(series_name : String) -> bool:
	return series.has(series_name)


func get_series_count() -> int:
	return series.size()


func set_fill_volume(enabled : bool) -> void:
	if enabled == fill_volume:
		return
	
	fill_volume = enabled
	
	for s : GraphSeries in series.values():
		s.set_fill_volume(enabled)
	
	if is_node_ready():
		__update_popup_state()


func extract_series(series_name : String) -> DataGraph:
	if not series.has(series_name): return self
	var graph_scene : PackedScene = load("res://scenes/ui/graph.tscn")
	var graph : DataGraph = graph_scene.instantiate()
	var extracted : GraphSeries = series[series_name]
	graph.add(extracted)
	return graph

func clear_series():
	for s : GraphSeries in series.values():
		s.free_resources()
		s.free()
	series.clear()


func add_series(series_name : String, color : Color, data_supplier : Callable, data_points : Array[float] = []):
	var new_series := GraphSeries.new(series_name, color, data_supplier, resolution)
	for point in data_points:
		new_series.update(point)
	add(new_series)


func add(s : GraphSeries):
	s.set_parent(self)
	s.fill_volume = fill_volume
	series[s.title] = s
	if s.polygon2d.get_parent():
		s.polygon2d.get_parent().remove_child(s.polygon2d)
	if s.line2d.get_parent():
		s.line2d.get_parent().remove_child(s.line2d)
	graphing_area.add_child(s.polygon2d, false, Node.INTERNAL_MODE_BACK)
	graphing_area.add_child(s.line2d, false, Node.INTERNAL_MODE_BACK)
	legend_container.add_child(s.legend_item, false, Node.INTERNAL_MODE_BACK)


func release_series(s : GraphSeries):
	if not series.has(s.title): return
	series.erase(s.title)
	graphing_area.remove_child(s.line2d)
	legend_container.remove_child(s.legend_item)


func refresh():
	call_deferred("set_process", true)

func update_series():
	for s : GraphSeries in series.values():
		s.update()
	
	refresh_range()


func redraw_graph():
	var series_array : Array = series.values()
	
	for series_idx : int in range(series_array.size() - 1, -1, -1):
		var s : GraphSeries = series_array[series_idx]
		if not s.enabled: continue
		
		var index : int = s.points.size()
		var point_index : int = -1
		var left_most : Vector2
		
		var line_points : PackedVector2Array = []
		line_points.resize(s.points.size())
		
		var polygon_points : PackedVector2Array = []
		if s.fill_volume:
			polygon_points.resize(s.points.size() + 2)
		
		for i in range(resolution, -1, -1):
			index -= 1
			if index < 0: break
			point_index += 1
			var point := Vector2(i / float(resolution), 1 - ((s.points.get_item(index) - minimum) / value_range)) * graphing_area_size
			line_points[point_index] = point
			if s.fill_volume:
				polygon_points[point_index] = point
			left_most = point
		
		if left_most and s.fill_volume:
			polygon_points[polygon_points.size() - 2] = Vector2(left_most.x, graphing_area_size.y) #Bottom left
			polygon_points[polygon_points.size() - 1] = graphing_area_size #Bottom right
		
		s.line2d.points = line_points
		s.polygon2d.polygon = polygon_points


func update_graph() -> void:
	var series_array : Array = series.values()
	
	for series_idx : int in range(series_array.size() - 1, -1, -1):
		var s : GraphSeries = series_array[series_idx]
		if not s.enabled: continue
		
		var line_points : PackedVector2Array = s.line2d.points
		var polygon_points : PackedVector2Array
		
		var point := Vector2(1, 1 - ((s.points.get_item(s.points.size() - 1) - minimum) / value_range)) * graphing_area_size
		var point_offset := graphing_area_size * Vector2(1.0 / resolution, 0)
		
		if line_points.size() < resolution:
			line_points.resize(line_points.size() + 1)
		
		var index : int = line_points.size() - 1
		while true:
			if index == 0: break
			var next = index - 1
			line_points[index] = line_points[next] - point_offset
			index = next
		line_points[0] = point

		
		polygon_points = line_points.duplicate()
		polygon_points.resize(polygon_points.size() + 2)
		polygon_points[polygon_points.size() - 2] = Vector2(line_points[line_points.size() - 1].x, graphing_area_size.y) #Bottom left
		polygon_points[polygon_points.size() - 1] = graphing_area_size #Bottom right
		
		s.line2d.points = line_points
		s.polygon2d.polygon = polygon_points


func _on_graphing_area_resized() -> void:
	graphing_area_size = graphing_area.get_size()
	redraw_borders()
	redraw_graph()


func refresh_range() -> void:
	min_value = INF
	max_value = -INF
	
	for s : GraphSeries in series.values():
		if not s.enabled: continue
		
		if s.get_max() > max_value:
			max_value = s.get_max()
		if s.get_min() < min_value:
			min_value = s.get_min()
	
	var new_min : float = min_value
	var new_max : float = max_value
	
	if max_value_use_padding or min_value_use_padding:
		var new_range := (new_max - new_min)
		if max_value_use_padding:
			match max_value_padding_mode:
				PaddingMode.VALUE:
					new_max += max_value_padding
				PaddingMode.FRACTION:
					new_max += max_value_padding * new_range
		if min_value_use_padding:
			match min_value_padding_mode:
				PaddingMode.VALUE:
					new_min -= min_value_padding
				PaddingMode.FRACTION:
					new_min -= min_value_padding * new_range
	
	if min_value_restrict_ceiling: new_min = minf(new_min, min_value_cieling)
	if max_value_restrict_floor: new_max = maxf(new_max, max_value_floor)
	
	if new_max < new_min:
		new_max = 1
		new_min = -1
	elif is_equal_approx(new_max, new_min):
		new_max += 1
		new_min -= 1
	
	if (new_min != minimum) or (new_max != maximum):
		minimum = new_min
		maximum = new_max
		value_range = maximum - minimum
		range_updated = true


func redraw_borders() -> void:
	top_border.clear_points()
	top_border.add_point(Vector2.ZERO)
	top_border.add_point(Vector2.RIGHT * graphing_area_size.x)
	bottom_border.clear_points()
	bottom_border.add_point(Vector2.DOWN * graphing_area_size)
	bottom_border.add_point(graphing_area_size)

func set_always_show_legend(enabled : bool):
	always_show_legend = enabled
	if is_node_ready():
		legend.visible = always_show_legend
		__update_popup_state()


func set_show_legend_on_hover(enabled : bool):
	show_legend_on_hover = enabled
	if is_node_ready():
		legend.visible = _is_hovered()


func set_limit_max_value(enabled : bool):
	max_value_restrict_floor = enabled
	if is_node_ready():
		__update_popup_state()


func set_limit_min_value(enabled : bool):
	min_value_restrict_ceiling = enabled
	if is_node_ready():
		__update_popup_state()


func set_max_value_padding(padding : float):
	match max_value_padding_mode:
		PaddingMode.FRACTION:
			max_value_padding = clampf(padding, 0, 1)
		PaddingMode.VALUE:
			max_value_padding = max(0, padding)

func set_min_value_padding(padding : float):
	match max_value_padding_mode:
		PaddingMode.FRACTION:
			min_value_padding = clampf(padding, 0, 1)
		PaddingMode.VALUE:
			min_value_padding = max(0, padding)

func set_resolution(n : int):
	resolution = n
	for s : GraphSeries in series.values():
		s.max_data_points = resolution


func set_update_period(seconds : float):
	update_period = max(0.001, seconds)
	if is_node_ready():
		update_timer.set_wait_time(update_period)


func set_realtime(enabled : bool) -> void:
	if realtime == enabled:
		return
	
	realtime = enabled
	
	if realtime:
		auto_update = true
		update_timer.stop()
		set_process(true)
	elif auto_update:
		if is_node_ready() and update_timer.is_stopped():
			set_process(true)


func set_auto_update(enabled : bool) -> void:
	if auto_update == enabled:
		return
	
	auto_update = enabled
	
	if not auto_update:
		realtime = false
		if is_node_ready() and update_timer.is_stopped():
			update_timer.stop()
	elif update_timer.is_stopped():
		set_process(true)


func _on_timer_timeout() -> void:
	refresh()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (data is GraphSeries) and not (data in series.values())

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is GraphSeries) or (data in series.values()): return
	data.set_parent(self)
	add(data)

func _is_hovered() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())

func _on_mouse_entered() -> void:
	if always_show_legend: return
	if show_legend_on_hover:
		legend.visible = true


func _on_mouse_exited() -> void:
	if always_show_legend: return
	if show_legend_on_hover:
		legend.visible = false


func _on_popup_menu_id_pressed(id: int) -> void:
	match id:
		POPUP_ALWAYS_SHOW_LEGEND:
			always_show_legend = !always_show_legend
		POPUP_FILL_VOLUME:
			fill_volume = !fill_volume
		POPUP_LIMIT_MAX_VALUE:
			max_value_restrict_floor = !max_value_restrict_floor
		POPUP_LIMIT_MIN_VALUE:
			min_value_restrict_ceiling = !min_value_restrict_ceiling

func __update_popup_state():
	popup_menu.set_item_checked(POPUP_ALWAYS_SHOW_LEGEND, always_show_legend)
	popup_menu.set_item_checked(POPUP_FILL_VOLUME, fill_volume)
	popup_menu.set_item_checked(POPUP_LIMIT_MAX_VALUE, max_value_restrict_floor)
	popup_menu.set_item_checked(POPUP_LIMIT_MIN_VALUE, min_value_restrict_ceiling)

func __unparent_popup():
	if popup_menu.visible: return
	var parent = popup_menu.get_parent()
	if parent: parent.remove_child(popup_menu)
