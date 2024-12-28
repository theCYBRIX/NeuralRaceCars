class_name DataGraph
extends Control

const POPUP_ALWAYS_SHOW_LEGEND : int = 0

@onready var graphing_area: Control = $Panel/VBoxContainer/Control/MarginContainer3/GraphingArea
@onready var legend: MarginContainer = $Panel/VBoxContainer/Legend
@onready var legend_container: HFlowContainer = $Panel/VBoxContainer/Legend/HFlowContainer
@onready var max_label : Label = $Panel/VBoxContainer/Control/MarginContainer/MaxLabel
@onready var min_label : Label = $Panel/VBoxContainer/Control/MarginContainer2/MinLabel
@onready var top_border: Line2D = $Panel/VBoxContainer/Control/MarginContainer3/GraphingArea/TopBorder
@onready var bottom_border: Line2D = $Panel/VBoxContainer/Control/MarginContainer3/GraphingArea/BottomBorder
@onready var update_timer: Timer = $UpdateTimer


@export var always_show_legend : bool = true : set = set_always_show_legend
@export var show_legend_on_hover : bool = true : set = set_show_legend_on_hover
@export var resolution : int = 100 : set = set_resolution
@export var update_period : float = 0.2 : set = set_update_period
@export var realtime : bool = false

var series : Dictionary = {}

var graphing_area_size : Vector2

var maximum : float = -INF
var minimum : float = INF
var value_range : float

var popup_menu : PopupMenu = PopupMenu.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	graphing_area_size = graphing_area.get_size()
	legend.visible = always_show_legend
	set_update_period(update_period)
	if not realtime: update_timer.start()
	popup_menu.add_check_item("Always Show Legend", POPUP_ALWAYS_SHOW_LEGEND)
	popup_menu.id_pressed.connect(_on_popup_menu_id_pressed)
	popup_menu.visibility_changed.connect(__unparent_popup, CONNECT_DEFERRED)
	__update_popup_state()


func _process(_delta: float) -> void:
	update_series()
	redraw_graph()
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


func clear_data_points():
	for s : GraphSeries in series.values():
		s.clear()


func extract_series(series_name) -> DataGraph:
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
		polygon_points.resize(s.points.size() + 2)
		
		for i in range(resolution, -1, -1):
			index -= 1
			if index < 0: break
			point_index += 1
			var point := Vector2(i / float(resolution), 1 - ((s.points.get_item(index) - minimum) / value_range)) * graphing_area_size
			line_points[point_index] = point
			polygon_points[point_index] = point
			left_most = point
		
		if left_most:
			polygon_points[polygon_points.size() - 2] = Vector2(left_most.x, graphing_area_size.y) #Bottom left
			polygon_points[polygon_points.size() - 1] = graphing_area_size #Bottom right
		
		s.line2d.points = line_points
		s.polygon2d.polygon = polygon_points
	
	min_label.set_text("%-3.2f" % minimum)
	max_label.set_text("%-3.2f" % maximum)



func _on_graphing_area_resized() -> void:
	graphing_area_size = graphing_area.get_size()
	redraw_borders()
	redraw_graph()


func refresh_range():
	maximum = -INF
	minimum = INF
	for s : GraphSeries in series.values():
		if not s.enabled: continue
		
		if s.max > maximum:
			maximum = s.max
		if s.min < minimum:
			minimum = s.min
	
	if maximum < minimum:
		maximum = 1
		minimum = -1
	elif is_equal_approx(maximum, minimum):
		maximum += 1
		minimum -= 1 
	
	value_range = maximum - minimum


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
		#__update_popup_state()


func set_show_legend_on_hover(enabled : bool):
	show_legend_on_hover = enabled
	if is_node_ready():
		legend.visible = _is_hovered()


func set_resolution(n : int):
	resolution = n
	for s : GraphSeries in series.values():
		s.max_data_points = resolution


func set_update_period(seconds : float):
	update_period = max(0.001, seconds)
	if is_node_ready():
		update_timer.set_wait_time(update_period)


func set_realtime(enabled : bool):
	if realtime == enabled: return
	realtime = enabled
	if is_node_ready():
		update_timer.stop()
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
	if id == POPUP_ALWAYS_SHOW_LEGEND:
		always_show_legend = !always_show_legend

func __update_popup_state():
	popup_menu.set_item_checked(POPUP_ALWAYS_SHOW_LEGEND, always_show_legend)

func __unparent_popup():
	if popup_menu.visible: return
	var parent = popup_menu.get_parent()
	if parent: parent.remove_child(popup_menu)
