class_name IOHandler
extends Node


signal connecting
signal connected
signal disconnected
signal connection_error


func read() -> String:
	return ""

func write(msg : String) -> void:
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
