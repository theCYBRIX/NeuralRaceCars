class_name NeuralCarReplayRecorder
extends ReplayRecorder

@export var neural_car : NeuralCar : set = set_neural_car
@export var enabled := true : set = set_enabled

func set_target(node : Node2D) -> void:
	super.set_target(node)
	if not target or target is NeuralCar:
		neural_car = target
	else:
		push_warning("No valid parent to record.")


func start() -> void:
	if enabled:
		super.start()


func set_enabled(value := true) -> void:
	if enabled == value:
		return
	
	enabled = value
	
	if (not enabled) and active:
		stop()


func set_neural_car(car : NeuralCar) -> void:
	if neural_car:
		Util.disconnect_from_signal(stop, neural_car.deactivated)
		Util.disconnect_from_signal(reset, neural_car.respawned)
		Util.disconnect_from_signal(start, neural_car.respawned)
	neural_car = car
	if car:
		car.deactivated.connect(stop)
		car.respawned.connect(reset)
		car.respawned.connect(start)
