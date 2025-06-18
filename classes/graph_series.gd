class_name GraphSeries
extends RefCounted


const LEGEND_ITEM : PackedScene = preload("res://scenes/ui/graph_legend_item.tscn")

var parent_graph : DataGraph

var title : String
var points : MinMaxCircularBuffer
var line2d : Line2D
var polygon2d : Polygon2D
var legend_item : Control
var data_supplier : Callable
var max_data_points : int
var enabled : bool = true : set = set_enabled
var fill_volume : bool = true : set = set_fill_volume

@warning_ignore("shadowed_variable", "narrowing_conversion")
func _init(title : String, color : Color, data_supplier : Callable, max_points : int) -> void:
	self.title = title
	var darkened_color := color * 0.65
	darkened_color.a = 0.75
	
	points = MinMaxCircularBuffer.new(max_points)
	
	line2d = Line2D.new()
	line2d.joint_mode = Line2D.LINE_JOINT_ROUND
	
	var line_gradient := Gradient.new()
	line_gradient.set_color(0, color)
	line_gradient.set_color(1, darkened_color)
	
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
	
	polygon2d = Polygon2D.new()
	polygon2d.color = darkened_color
	
	self.data_supplier = data_supplier
	max_data_points = max_points


func set_parent(graph : DataGraph):
	if parent_graph:
		parent_graph.release_series(self)
	parent_graph = graph


func clear():
	points.clear()
	line2d.clear_points()
	polygon2d.polygon.clear()


func update(new_value : float = data_supplier.call()):
	var _min = points.get_min()
	var _max = points.get_max()
	if new_value < _min or new_value > _max:
		legend_item.call_deferred("set_tooltip_text", "Max: %-3.2f\nMin: %-3.2f" % [_max, _min])
	
	points.append(new_value)


func toggle_enabled():
	enabled = !enabled


func set_enabled(state : bool):
	if state == enabled: return
	enabled = state
	line2d.visible = enabled
	polygon2d.visible = enabled if fill_volume else false
	if enabled:
		legend_item.modulate = Color(1, 1, 1, 1)
	else:
		legend_item.modulate = Color(0.5, 0.5, 0.5, 0.5)


@warning_ignore("shadowed_variable")
func set_fill_volume(enabled : bool) -> void:
	if fill_volume == enabled:
		return
	
	fill_volume = enabled
	
	polygon2d.visible = fill_volume


func free_resources():
	line2d.queue_free()
	polygon2d.queue_free()
	legend_item.queue_free()

func get_min():
	return points.get_min()

func get_max():
	return points.get_max()
