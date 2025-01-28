extends NeuralCar

@onready var checkpoint_timer: Timer = $CheckpointTimer
@onready var lifetime_timer: Timer = $LifetimeTimer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


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


func _on_checkpoint_updated(idx: int) -> void:
	checkpoint_timer.start(0)
