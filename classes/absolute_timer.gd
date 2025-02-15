class_name AbsoluteTimer
extends RefCounted

const MICRO_PER_MILLIS := 1_000.0
const MICRO_PER_SEC := 1_000_000.0

var start_time : int
var end_time : int
var elapsed_time : float
var active : bool = false

func start() -> void:
	start_time = Time.get_ticks_usec()
	active = true

func stop() -> void:
	end_time = Time.get_ticks_usec()
	elapsed_time = end_time - start_time
	active = false

func get_elapsed_time_micro() -> float:
	if active:
		return Time.get_ticks_usec() - start_time
	else:
		return elapsed_time

func get_elapsed_time_millis() -> float:
	return get_elapsed_time_micro() / MICRO_PER_MILLIS

func get_elapsed_time_sec() -> float:
	return get_elapsed_time_micro() / MICRO_PER_SEC
