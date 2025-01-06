class_name TrainingState
extends Resource

@export var time_elapsed : float = 0.0

@export var generation : int = 0

@export var highest_score : float = 0.0

@export var networks : Array

func to_dictionary() -> Dictionary:
	return {
		"time_elapsed" = time_elapsed,
		"generation" = generation,
		"highest_score" = highest_score,
		"networks" = networks
	}
