class_name GraphSeries
extends RefCounted


const LEGEND_ITEM : PackedScene = preload("res://Scenes/UI/graph_legend_item.tscn")
const POINTS_REDUCTION_THRESH : int = 200

var parent_graph : DataGraph

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
	line2d.joint_mode = Line2D.LINE_JOINT_ROUND
	
	var line_gradient := Gradient.new()
	line_gradient.set_color(0, color)
	line_gradient.set_color(1, Color(color) * Color(1, 1, 1, 0.35))
	
	line2d.gradient = line_gradient
	#line2d.width_curve = Curve.new()
	#line2d.width_curve.add_point(Vector2(0, 1))
	#line2d.width_curve.add_point(Vector2(1, 0.5))
	#line2d.width_curve.bake()
	line2d.round_precision = 16
	line2d.antialiased = true
	line2d.set_default_color(color)
	line2d.set_width(2)
	legend_item = LEGEND_ITEM.instantiate()
	legend_item.series = self
	legend_item.set_color(color)
	legend_item.set_text(title)
	legend_item.pressed.connect(toggle_enabled)
	legend_item.ready.connect(func(): legend_item.line_2d.gradient = line_gradient, CONNECT_ONE_SHOT)
	self.data_supplier = data_supplier
	max_data_points = max_points

func set_parent(graph : DataGraph):
	if parent_graph:
		parent_graph.release_series(self)
	parent_graph = graph


func clear():
	points.clear()
	line2d.clear_points()
	min = INF
	max = -INF

func update(new_value : float = data_supplier.call()):
	
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
