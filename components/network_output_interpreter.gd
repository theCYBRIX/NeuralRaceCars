class_name NetworkOutputInterpreter
extends Node

enum Interpreter {
	BINARY_THRESHOLD,
	MAGNITUDE_BASED,
	CONTINUOUS
}

@export var interpreter : Interpreter = Interpreter.BINARY_THRESHOLD : set = set_interptreter

var steering_input : float = 0
var throttle_input : float = 0

var _interpreter_callable : Callable = interpret_binary_threshold


func interpret_network_outputs(outputs : Array) -> void:
	_interpreter_callable.call(outputs)


func reset() -> void:
	steering_input = 0
	throttle_input = 0


func interpret_binary_threshold(outputs : Array):
	var forwards : float = clampf(outputs[0], 0, 1)
	var backwards : float = clampf(outputs[1], 0, 1)
	var turn_left : float = clampf(outputs[3], 0, 1)
	var turn_right : float = clampf(outputs[2], 0, 1)
	
	if (forwards < 0.5 and backwards < 0.5) or is_equal_approx(forwards, backwards):
		throttle_input = 0
	else:
		throttle_input = 1 if forwards > backwards else -1
	
	if turn_left < 0.5 and turn_right < 0.5:
		steering_input = 0
	else:
		steering_input = 1 if turn_right > turn_left else -1


func interpret_magnitude_based(outputs : Array):
	var forwards : float = clampf(outputs[0], 0, 1)
	var backwards : float = clampf(outputs[1], 0, 1)
	var turn_left : float = clampf(outputs[3], 0, 1)
	var turn_right : float = clampf(outputs[2], 0, 1)
	
	throttle_input = forwards if forwards > backwards else -backwards
	steering_input = turn_right if turn_right > turn_left else -turn_left


func interpret_continuous(outputs : Array):
	var acceleration : float = clampf(outputs[0], -1, 1)
	var turning : float = clampf(outputs[1], -1, 1)
		
	throttle_input = acceleration
	steering_input = turning


func set_interptreter(type : Interpreter) -> void:
	if type == interpreter:
		return
	
	interpreter = type
	
	_update_interpreter_callable()


func _update_interpreter_callable() -> void:
	match interpreter:
		Interpreter.BINARY_THRESHOLD:
			_interpreter_callable = interpret_binary_threshold
		Interpreter.MAGNITUDE_BASED:
			_interpreter_callable = interpret_magnitude_based
		Interpreter.CONTINUOUS:
			_interpreter_callable = interpret_continuous
