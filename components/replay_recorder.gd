class_name ReplayRecorder
extends Node

const DEFAULT_FRAME_RATE : int = 24


signal started
signal stopped


@export var frame_rate : int = DEFAULT_FRAME_RATE : set = set_frame_rate

@export var target : Node2D : set = set_target

var replay_data := ReplayData.new()
var active := false

var _elapsed_time : float = 0
var _timer : Timer

func _init() -> void:
	name = "ReplayRecorder"
	_timer = Timer.new()
	_timer.timeout.connect(_on_timer_timeout)
	_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	add_child(_timer, false, Node.INTERNAL_MODE_FRONT)


func _ready() -> void:
	if not target:
		var parent := get_parent()
		if parent is Node2D:
			target = parent
	_update_wait_time()


func _physics_process(delta: float) -> void:
	_elapsed_time += delta


func start() -> void:
	if active:
		return
	if not target:
		push_error("Unable to start recording: Target is null.")
		return
	active = true
	_elapsed_time = 0
	_snapshot()
	_timer.start()
	set_physics_process(true)
	started.emit()


func stop() -> void:
	if not active:
		return
	active = false
	_timer.stop()
	_snapshot()
	set_physics_process(false)
	stopped.emit()


func reset() -> void:
	replay_data = ReplayData.new()


func set_replay_data(data : ReplayData):
	replay_data = data


func set_frame_rate(rate : float) -> void:
	if rate <= 0:
		push_error("Frame rate cannot be <= 0")
		return
	frame_rate = rate
	if _timer:
		_update_wait_time()


func _update_wait_time() -> void:
	_timer.wait_time = 1.0 / frame_rate


func set_target(node : Node2D) -> void:
	target = node


func _snapshot() -> void:
	replay_data.record(_elapsed_time, target.position, target.rotation)


func _on_timer_timeout() -> void:
	_snapshot()
