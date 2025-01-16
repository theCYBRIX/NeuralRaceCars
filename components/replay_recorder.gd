extends Node

@onready var timer: Timer = $Timer

var replay_data := ReplayData.new()

func _ready() -> void:
	_update_timer()


func start() -> void:
	timer.start()


func stop() -> void:
	timer.stop()


func reset() -> void:
	replay_data.clear()


func set_replay_data(data : ReplayData):
	replay_data = data
	if replay_data and is_node_ready():
		_update_timer()

func _update_timer():
	timer.wait_time = 1.0 / replay_data.frame_rate


func _on_timer_timeout() -> void:
	var parent := get_parent()
	if parent and parent is Node2D:
		replay_data.record(parent.position, parent.rotation)
	else:
		push_error("Parent is not a Node2D")
		timer.stop()
