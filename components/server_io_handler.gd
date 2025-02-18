class_name ServerIOHandler
extends IOHandler


@export var host_address : String
@export_range(0, 65535) var host_port : int
@export var autostart : bool = false

var socket : StreamPeerTCP
var status : StreamPeerTCP.Status = StreamPeerTCP.STATUS_NONE
var socket_mutex : Mutex = Mutex.new()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(false)
	
	socket = StreamPeerTCP.new()
	socket.big_endian = true
	
	if not Engine.is_editor_hint() and autostart:
		connect_to_host()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	socket.poll()
	var new_status : StreamPeerTCP.Status = socket.get_status()
	if status != new_status:
		status = new_status
		match status:
			StreamPeerTCP.STATUS_ERROR:
				print("Connection Error!")
				connection_error.emit()
				set_process(false)
			StreamPeerTCP.STATUS_NONE:
				print("Disconnected.")
				disconnected.emit()
				set_process(false)
			StreamPeerTCP.STATUS_CONNECTED:
				print("Connection Success.")
				connected.emit()
			StreamPeerTCP.STATUS_CONNECTING:
				print("Connecting...")
				connecting.emit()



func connect_to_host() -> Error:
	disconnect_from_host()
	print("Connecting to host...\nAddress: " + host_address + "\nPort: " + str(host_port))
	var error = socket.connect_to_host(host_address, host_port)
	if error == OK:
		set_process(true)
	return error 


func disconnect_from_host() -> Error:
	match socket.get_status():
		StreamPeerTCP.STATUS_CONNECTING or StreamPeerTCP.STATUS_CONNECTED:
			socket.disconnect_from_host()
	return OK


func is_socket_connected() -> bool:
	return (status == StreamPeerTCP.STATUS_CONNECTED)


func is_running() -> bool:
	return is_socket_connected()


func _exit_tree() -> void:
	if is_socket_connected(): disconnect_from_host()


func write(msg : String) -> void:
	socket_mutex.lock()
	socket.put_string(msg)
	socket_mutex.unlock()


func read() -> String:
	return socket.get_string()


func start() -> bool:
	return (connect_to_host() == OK)

func stop() -> bool:
	return (disconnect_from_host() == OK)
