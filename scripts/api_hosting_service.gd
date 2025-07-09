extends Node


var JAVA_INSTALLED : bool
var ACTION_DOWNLOAD := "download"
var ACTION_EXIT := "exit"


@onready var java_process_manager: JavaProcessManager = $JavaProcessManager : get = get_process_manager


func _ready() -> void:
	JAVA_INSTALLED = Util.is_java_installed()
	if not JAVA_INSTALLED:
		var dialog = AcceptDialog.new()
		dialog.disable_3d = true
		dialog.dialog_text = "Java is required to run SimpleNeuralNetwork.\nPlease install Java and restart the game."
		dialog.custom_action.connect(_on_dialog_custom_action)
		dialog.add_button("Get Java", true, ACTION_DOWNLOAD)
		dialog.add_button("Exit", true, ACTION_EXIT)
		dialog.visibility_changed.connect(func(): if not dialog.visible: dialog.queue_free())
		add_child(dialog)
		dialog.popup_centered()


func _on_dialog_custom_action(action : String) -> void:
	match action:
		ACTION_DOWNLOAD:
			OS.shell_open("https://www.java.com/en/download/")
		ACTION_EXIT:
			get_tree().quit()


func is_running() -> bool:
	return java_process_manager.is_running()


func get_process_manager() -> JavaProcessManager:
	return java_process_manager


func _on_java_process_manager_err_message_received(msg: String) -> void:
	#print(msg)
	pass


func _on_java_process_manager_message_received(msg: String) -> void:
	#print(msg)
	pass
