extends Control

@onready var state_label: Label = $CenterContainer/VBoxContainer/StateLabel
@onready var generation_label: Label = $CenterContainer/VBoxContainer/GenerationLabel
@onready var error_label: Label = $CenterContainer/VBoxContainer/ErrorLabel
@onready var time_label: Label = $CenterContainer/VBoxContainer/TimeLabel
@onready var refresh_timer: Timer = $RefreshTimer

@onready var save_button: Button = $SaveButton
@onready var start_button: Button = $StartButton
@onready var stop_button: Button = $StopButton
@onready var connect_button: Button = $ConnectButton

@onready var api_client: NeuralAPIClient = $NeuralAPIClient

const DRIVING_DATA_PATH := "user://resources/driving_data.tres"

@export var num_networks : int = 200
@export var parent_selector : NeuralAPIClient.ParentSelection = 0
@export var load_saved_networks : bool = false

var connected : bool = true : set = set_connected
var dataset : DrivingData

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	assert(ResourceLoader.exists(DRIVING_DATA_PATH))
	dataset = ResourceLoader.load(DRIVING_DATA_PATH, "DrivingData")
	assert(dataset != null)
	dataset.convert()
	api_client.setup_session(num_networks, parent_selector, load_networks() if load_saved_networks else [] )
	#api_client.connect_to_host()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_refresh_timer_timeout() -> void:
	var response := await api_client.get_training_status()
	if response.is_empty() or not response.has("payload"): return
	var status : Dictionary = response["payload"]
	if status.has("state"):
		state_label.text = "Status: " + str(status["state"])
	if status.has("generation"):
		generation_label.text = "Generation: " + str(status["generation"])
	if status.has("averageError"):
		error_label.text = "Average Error: %4.3f" % float(status["averageError"])
	if status.has("elapsedTimeMS"):
		time_label.text = "Time Elapsed: " + format_time(int(status["elapsedTimeMS"]))


func format_time(millis : int):
	var formatted : String = ""
	
	if millis >= 3600000:
		formatted += str(millis / 3600000) + "h "
		millis %= 3600000
	if millis >= 60000:
		formatted += str(millis / 60000) + "m "
		millis %= 60000
	if millis >= 1000:
		formatted += str(millis / 1000) + "s "
	
	return formatted

func _on_start_button_pressed() -> void:
	if not connected: return
	api_client.train_on_dataset(dataset)
	refresh_timer.start(0)


func _on_stop_button_pressed() -> void:
	if not connected: return
	api_client.stop_training()


func _on_neural_api_client_connected() -> void:
	connected = true


func _on_neural_api_client_disconnected() -> void:
	connected = false
	refresh_timer.stop()


func set_connected(state : bool):
	connected = state
	if is_node_ready():
		connect_button.disabled = connected
		save_button.disabled = not connected
		start_button.disabled = not connected
		stop_button.disabled = not connected


func _on_save_button_pressed() -> void:
	save_button.disabled = true
	save_networks()
	save_button.disabled = false


func _on_connect_button_pressed() -> void:
	api_client.connect_to_host()


func save_networks(n : int = num_networks):
	var networks : Array = (await api_client.get_best_networks(n))["networks"]
	var save_file = FileAccess.open("user://saved_networks.json", FileAccess.WRITE)
	save_file.store_string(JSON.stringify(networks))
	save_file.close()
	
func load_networks() -> Array:
	var save_file = FileAccess.open("user://saved_networks.json", FileAccess.READ)
	var file_contents = save_file.get_as_text()
	save_file.close()
	if save_file.get_error() != OK: return []
	var networks : Array = JSON.parse_string(file_contents)
	return networks
