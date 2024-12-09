class_name DataGraph
extends Control

@onready var graphing_area: Control = $Panel/VBoxContainer/Control/MarginContainer3/GraphingArea
@onready var legend: MarginContainer = $Panel/VBoxContainer/Legend
@onready var legend_container: HFlowContainer = $Panel/VBoxContainer/Legend/HFlowContainer
@onready var max_label : Label = $Panel/VBoxContainer/Control/MarginContainer/MaxLabel
@onready var min_label : Label = $Panel/VBoxContainer/Control/MarginContainer2/MinLabel
@onready var top_border: Line2D = $Panel/VBoxContainer/Control/MarginContainer3/GraphingArea/TopBorder
@onready var bottom_border: Line2D = $Panel/VBoxContainer/Control/MarginContainer3/GraphingArea/BottomBorder
@onready var update_timer: Timer = $UpdateTimer


@export var show_legend : bool = true : set = set_show_legend
@export var resolution : int = 100 : set = set_resolution
@export var update_period : float = 0.2 : set = set_update_period

var series : Dictionary = {}

var graphing_area_size : Vector2

var maximum : float = -INF
var minimum : float = INF
var value_range : float


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	graphing_area_size = graphing_area.get_size()
	legend.visible = show_legend
	set_update_period(update_period)


func _process(_delta: float) -> void:
	redraw_graph()
	set_process(false)


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
	graphing_area.add_child(s.line2d, false, Node.INTERNAL_MODE_BACK)
	legend_container.add_child(s.legend_item, false, Node.INTERNAL_MODE_BACK)

func release_series(s : GraphSeries):
	if not series.has(s.title): return
	series.erase(s.title)
	graphing_area.remove_child(s.line2d)
	legend_container.remove_child(s.legend_item)


func refresh():
	update_series()
	call_deferred("set_process", true)

func update_series():
	var series_array : Array = series.values()
	
	maximum = -INF
	minimum = INF
	
	for s : GraphSeries in series_array:
		if s.points.size() - 20 > resolution:
			s.resize_points_list(resolution)
		
		s.update()
		
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


func redraw_graph():
	var series_array : Array = series.values()
	
	for series_idx : int in range(series_array.size() - 1, -1, -1):
		var s : GraphSeries = series_array[series_idx]
		if not s.enabled: continue
		s.line2d.clear_points()
		var index : int = s.points.size()
		
		for i in range(resolution, -1, -1):
			index -= 1
			if index < 0: break 
			s.line2d.add_point(Vector2(i / float(resolution), 1 - ((s.points.get_item(index) - minimum) / value_range)) * graphing_area_size)
	
	min_label.set_text("%-3.2f" % minimum)
	max_label.set_text("%-3.2f" % maximum)



func _on_graphing_area_resized() -> void:
	graphing_area_size = graphing_area.get_size()
	redraw_borders()
	redraw_graph()


func redraw_borders() -> void:
	top_border.clear_points()
	top_border.add_point(Vector2.ZERO)
	top_border.add_point(Vector2.RIGHT * graphing_area_size.x)
	bottom_border.clear_points()
	bottom_border.add_point(Vector2.DOWN * graphing_area_size)
	bottom_border.add_point(graphing_area_size)

func set_show_legend(enabled : bool):
	show_legend = enabled
	if is_node_ready():
		legend.visible = show_legend


func set_resolution(n : int):
	resolution = n
	for s : GraphSeries in series.values():
		s.max_data_points = resolution


func set_update_period(seconds : float):
	update_period = max(0.001, seconds)
	if is_node_ready():
		update_timer.set_wait_time(update_period)


func _on_timer_timeout() -> void:
	refresh()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (data is GraphSeries) and not (data in series.values())

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is GraphSeries) or (data in series.values()): return
	data.set_parent(self)
	add(data)
