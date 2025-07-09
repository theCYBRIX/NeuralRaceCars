class_name ConsoleIOHandler
extends IOHandler


@export_node_path("JavaProcessManager") var process_manager_path : NodePath = NodePath("")
@export var autostart : bool = false


var java_process_manager : JavaProcessManager : set = set_process_manager
var shutdown_requested : bool = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not Engine.is_editor_hint() and autostart:
		start()
	set_process(false)
	
	if not process_manager_path or process_manager_path.is_empty():
		process_manager_path = get_path_to(ApiHostingService.java_process_manager)
	
	java_process_manager = get_node_or_null(process_manager_path)


func _process(_delta: float) -> void:
	if is_running(): return
	if not shutdown_requested:
		print("SimpleNNConsole exited unexpectedly.")
	disconnected.emit()
	set_process(false)


func write(msg : String) -> void:
	java_process_manager.std_io.store_pascal_string(msg)


func read() -> String:
	return java_process_manager.std_io.get_pascal_string()


func is_running() -> bool:
	return java_process_manager and java_process_manager.is_running()


func start() -> bool:
	if not java_process_manager:
		return false
	connecting.emit()
	return java_process_manager.start()


func stop() -> bool:
	if not java_process_manager:
		return false
	else:
		return await java_process_manager.stop()


func _exit_tree() -> void:
	cancel_free()
	await stop()
	queue_free()


func set_process_manager(manager : JavaProcessManager) -> void:
	if java_process_manager:
		Util.disconnect_from_signal(_on_process_manager_process_started, java_process_manager.process_started)
		Util.disconnect_from_signal(_on_process_manager_process_shutdown, java_process_manager.process_shutdown)
		Util.disconnect_from_signal(_on_process_manager_startup_error, java_process_manager.startup_error)
		Util.disconnect_from_signal(_on_process_manager_err_message_received, java_process_manager.err_message_received)
	
	java_process_manager = manager
	
	if java_process_manager:
		java_process_manager.process_started.connect(_on_process_manager_process_started)
		java_process_manager.process_shutdown.connect(_on_process_manager_process_shutdown)
		java_process_manager.startup_error.connect(_on_process_manager_startup_error)
		java_process_manager.err_message_received.connect(_on_process_manager_err_message_received)
		java_process_manager.auto_read_err_stream = true


func _on_process_manager_process_started() -> void:
	connected.emit()


func _on_process_manager_process_shutdown() -> void:
	disconnected.emit()


func _on_process_manager_startup_error() -> void:
	connection_error.emit()


func _on_process_manager_err_message_received(msg : String) -> void:
	var lines : PackedStringArray = ["[%s]:\n" % java_process_manager.app_name]
	lines.append_array(msg.strip_edges().split("\n"))
	print("~\t".join(lines), "\n")


func _on_process_manager_message_received(msg : String) -> void:
	print(msg)
