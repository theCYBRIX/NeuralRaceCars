extends IOHandler

@export var app_path : String = "./SimpleNeuralNetwork/SimpleNeuralNetwork.jar"
@export var autostart : bool = false

var app_properties : Dictionary
var std_io : FileAccess

var shutdown_requested : bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not Engine.is_editor_hint() and autostart:
		start()

func _process(_delta: float) -> void:
	if is_running(): return
	if not shutdown_requested:
		print("SimpleNNConsole exited unexpectedly.")
	disconnected.emit()
	set_process(false)

func write(msg : String) -> void:
	std_io.store_pascal_string(msg)

func read() -> String:
	return std_io.get_pascal_string()

func is_running() -> bool:
	return OS.is_process_running(app_properties.pid)

func start() -> bool:
	if app_properties and is_running():
		stop()
	
	app_properties = OS.execute_with_pipe("java", ["-jar", app_path])
	std_io = app_properties.stdio
	if is_running():
		print("SimpleNNConsole started successfully.")
		connected.emit()
		set_process(true)
		return true
	else:
		print("SimpleNNConsole failed to start.")
		connection_error.emit()
		return false


func stop() -> bool:
	if is_running():
		write(JSON.stringify({ "request" : "exit" }))
		shutdown_requested = true
		
		var response : Dictionary = JSON.parse_string(read())
		
		if !response or !response.has("status") or !(response["status"] == "ok"):
			OS.kill(app_properties.pid)
		else:
			print("SimpleNNConsole shutdown properly.")
		
		if OS.is_process_running(app_properties.pid):
			get_tree().create_timer(0.25).timeout.connect(OS.kill.bind(app_properties.pid), CONNECT_ONE_SHOT)
			
	return true


func _exit_tree() -> void:
	stop()
