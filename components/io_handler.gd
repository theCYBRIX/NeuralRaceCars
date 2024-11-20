class_name IOHandler
extends Node


signal connecting
signal connected
signal disconnected
signal connection_error

signal data_received(data : String)


func read() -> String:
	return ""

func write(msg : String) -> void:
	pass

func is_running() -> bool:
	return false

func start() -> bool:
	return false

func stop() -> bool:
	return false
