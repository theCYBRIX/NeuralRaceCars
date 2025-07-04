class_name JavaProcessManager
extends Node

signal process_started
signal process_shutdown
signal startup_error
signal message_received(msg : String)
signal err_message_received(msg : String)

@export var app_name : String = "SimpleNeuralNetwork"
@export_file("*.jar") var app_path : String = "./SimpleNeuralNetwork/SimpleNeuralNetwork.jar"
@export var args : Array[String] = ["--mode=tcp", "--port=3050", "--parent-pid=%d" % OS.get_process_id()]
@export var stop_command : String = "exit"
@export var auto_read_stream := false

var app_properties : Dictionary
var std_io : FileAccess
var std_err : FileAccess

var shutdown_requested : bool = false


func _ready() -> void:
	set_process(false)


func is_running() -> bool:
	return app_properties and app_properties.has("pid") and OS.is_process_running(app_properties.pid)


func get_available_chars(file_access : FileAccess) -> int:
	return file_access.get_length() - file_access.get_position()


func write_std_in(string : String) -> void:
	std_io.store_string(string)


func read_std_out() -> String:
	return _read_stream(std_io)


func read_std_err() -> String:
	return _read_stream(std_err)


func _read_stream(stream : FileAccess) -> String:
	return stream.get_buffer(get_available_chars(stream)).get_string_from_utf8()


func _process(_delta: float) -> void:
	if is_running():
		if auto_read_stream:
			var out := read_std_out()
			if out and out.length() > 0:
				message_received.emit(out)
			var err_out := read_std_err()
			if err_out and err_out.length() > 0:
				err_message_received.emit(err_out)
	else:
		if not shutdown_requested:
			print(app_name + " exited unexpectedly.")
		process_shutdown.emit()
		set_process(false)


func start() -> bool:
	if app_properties and is_running():
		stop()
	var arguments := ["-jar", app_path]
	arguments.append_array(args)
	app_properties = OS.execute_with_pipe("java", arguments, false)
	std_io = app_properties.stdio
	std_err = app_properties.stderr
	std_io.big_endian = true
	std_err.big_endian = true
	if is_running():
		print(app_name + " started successfully.")
		process_started.emit()
		set_process(true)
		return true
	else:
		print(app_name + " failed to start.")
		startup_error.emit()
		return false


func stop(app_stop_command : String = stop_command, timeout := 5.0) -> bool:
	if is_running():
		set_process(false)
		shutdown_requested = true
		var err : Error = OK
		
		if app_stop_command.is_empty():
			err = OS.kill(app_properties.pid)
		
		else:
			std_io.store_string(app_stop_command + "\n")
			var timer = get_tree().create_timer(timeout)
			err = ERR_TIMEOUT
			while is_instance_valid(timer):
				await get_tree().create_timer(0.1).timeout
				if not is_running():
					err = OK
					break
		
		if err == OK:
			print(app_name + " shutdown properly.")
			process_shutdown.emit()
			return true
		
		print("%s did not shutdown gracefully: %s\n" % [app_name, error_string(err)])
		if is_running():
			print("Attempting to kill the process...")
			err = OS.kill(app_properties.pid)
		
			if err == OK:
				print(app_name + " was terminated.")
			else:
				print("Failed to shutdown %s: %s" % [app_name, error_string(err)])
		process_shutdown.emit()
	
	return true


func _exit_tree() -> void:
	cancel_free()
	await stop()
	queue_free()
