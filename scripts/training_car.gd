extends NeuralCar

@onready var checkpoint_timer: Timer = $CheckpointTimer
@onready var lifetime_timer: Timer = $LifetimeTimer


func set_active(enabled := true) -> void:
	super.set_active(enabled)
	
	if is_node_ready():
		if active:
			checkpoint_timer.start()
			lifetime_timer.start()
		else:
			checkpoint_timer.stop()
			lifetime_timer.stop()


func _on_checkpoint_timer_timeout() -> void:
	deactivate()


func _on_lifetime_timer_timeout() -> void:
	deactivate()


func _on_checkpoint_tracker_checkpoint_updated() -> void:
	checkpoint_timer.start(0)
