class_name IOHandler
extends Node


@warning_ignore("unused_signal")
signal connecting
@warning_ignore("unused_signal")
signal connected
@warning_ignore("unused_signal")
signal disconnected
@warning_ignore("unused_signal")
signal connection_error


func read() -> String:
	return ""

func write(_msg : String) -> void:
	pass

func query(msg : String) -> String:
	write(msg)
	return read()

func is_running() -> bool:
	return false

func start() -> bool:
	return false

func stop() -> bool:
	return false

func _exit_tree() -> void:
	if is_running():
		stop()
