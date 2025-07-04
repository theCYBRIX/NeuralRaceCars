extends Node2D


@onready var color_rect: ColorRect = $ColorRect

var target_swap_duration := 0.5
var target : Node2D : set = set_target
var tracking : bool = false : set = set_tracking


var _target_swap_time := 0.0
var _swapping_target := false


func _ready() -> void:
	color_rect.visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not target:
		set_process(false)
		return
	
	if _swapping_target:
		_target_swap_time = minf(_target_swap_time + delta, target_swap_duration)
		_swapping_target = _target_swap_time < target_swap_duration
		self.global_position = lerp(self.global_position, target.global_position, smoothstep(0, target_swap_duration, _target_swap_time))
	else:
		self.global_position = target.global_position


func start_tracking(node : Node2D = target) -> void:
	if not node:
		stop_tracking()
		return
	
	target = node
	color_rect.visible = true
	tracking = true
	if not _swapping_target:
		_swapping_target = true
		_target_swap_time = 0.0


func stop_tracking() -> void:
	color_rect.visible = false
	tracking = false


func set_target(node : Node2D) -> void:
	target = node


func set_tracking(enabled : bool) -> void:
	tracking = enabled
	set_process(tracking)
