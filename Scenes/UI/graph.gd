extends Control

const LEGEND_ITEM : PackedScene = preload("res://Scenes/UI/graph_legend_item.tscn")

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
	for s : Series in series.values():
		s.clear()


func clear_series():
	for s : Series in series.values():
		s.free_resources()
		s.free()
	series.clear()


func add_series(series_name : String, color : Color, data_supplier : Callable):
	var new_series := Series.new(series_name, color, data_supplier, resolution)
	series[series_name] = new_series
	graphing_area.add_child(new_series.line2d, false, Node.INTERNAL_MODE_BACK)
	legend_container.add_child(new_series.legend_item, false, Node.INTERNAL_MODE_BACK)


func refresh():
	update_series()
	call_deferred("set_process", true)

func update_series():
	var series_array : Array = series.values()
	
	maximum = -INF
	minimum = INF
	
	for s : Series in series_array:
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
		var s : Series = series_array[series_idx]
		if not s.enabled: continue
		s.line2d.clear_points()
		var index : int = s.points.size()
		for i in range(resolution, -1, -1):
			index -= 1
			if index < 0: break 
			s.line2d.add_point(Vector2(i / float(resolution), 1 - ((s.points[index] - minimum) / value_range)) * graphing_area_size)
	
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
	for s : Series in series.values():
		s.max_data_points = resolution


func set_update_period(seconds : float):
	update_period = max(0.001, seconds)
	if is_node_ready():
		update_timer.set_wait_time(update_period)

class Series:
	const POINTS_REDUCTION_THRESH : int = 200
	
	var title : String
	var points : Array[float] = []
	var line2d : Line2D
	var legend_item : Control
	var data_supplier : Callable
	var max_data_points : int
	var enabled : bool = true : set = set_enabled
	
	@warning_ignore("shadowed_global_identifier")
	var min : float = INF
	var min_index : int
	@warning_ignore("shadowed_global_identifier")
	var max : float = -INF
	var max_index : int
	
	@warning_ignore("shadowed_variable", "narrowing_conversion")
	func _init(title : String, color : Color, data_supplier : Callable, max_points : float) -> void:
		self.title = title
		line2d = Line2D.new()
		line2d.set_default_color(color)
		line2d.set_width(2)
		legend_item = LEGEND_ITEM.instantiate()
		legend_item.set_color(color)
		legend_item.set_text(title)
		legend_item.pressed.connect(toggle_enabled)
		self.data_supplier = data_supplier
		max_data_points = max_points
	
	func clear():
		points.clear()
		line2d.clear_points()
		min = INF
		max = -INF
	
	func update():
		var new_value : float = data_supplier.call()
		
		if new_value <= min or new_value >= max:
			if new_value < min or new_value > max:
				legend_item.call_deferred("set_tooltip_text", "Max: %-3.2f\nMin: %-3.2f" % [max, min])
				
			if new_value <= min:
				min = new_value
				min_index = points.size()
			elif new_value >= max:
				max = new_value
				max_index = points.size()
			
		points.append(new_value)
		
		if points.size() > max_data_points:
			var list_start : int = points.size() - max_data_points
			if min_index < list_start or max_index < list_start:
				update_extremes_in_range(list_start, points.size())
			if list_start >= POINTS_REDUCTION_THRESH:
				points = points.slice(list_start)
				min_index -= list_start
				max_index -= list_start
	
	# start included, end excluded
	func update_extremes_in_range(start : int, end : int):
		max = points[start]
		min = points[start]
		max_index = start
		min_index = start
		for i : int in range(start + 1, end):
			if points[i] >= max:
				max = points[i]
				max_index = i
			elif points[i] <= min:
				min = points[i]
				min_index = i
	
	
	func toggle_enabled():
		enabled = !enabled
	
	func set_enabled(state : bool):
		if state == enabled: return
		enabled = state
		line2d.visible = enabled
		if enabled:
			legend_item.modulate = Color(1, 1, 1, 1)
		else:
			legend_item.modulate = Color(0.5, 0.5, 0.5, 0.5)
	
	
	func resize_points_list(new_size : int):
		points = points.slice(points.size() - new_size, points.size())
		refresh_extremes()
	
	
	func refresh_extremes():
		max = points.max()
		min = points.min()
	
	func free_resources():
		line2d.queue_free()
		legend_item.queue_free()


func _on_timer_timeout() -> void:
	refresh()
