class_name IOHandler
extends Node


signal connecting
signal connected
signal disconnected
signal connection_error

signal data_received(data : String)

var io_mutex : Mutex = Mutex.new()


func read() -> String:
	return ""

func write(msg : String) -> void:
	pass

func query(msg : String) -> Signal:
	io_mutex.lock()
	
	write(msg)
	var data := read()
	
	io_mutex.unlock()
	
	call_deferred("emit_signal", "data_received", data)
	return data_received 

func is_running() -> bool:
	return false

func start() -> bool:
	return false

func stop() -> bool:
	return false
