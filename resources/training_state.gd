class_name TrainingState
extends Resource

@export var generation : int
@export var total_generations : int = 0

@export var total_time_elapsed := 0.0
@export var total_time_elapsed_int : int = -1

@export var since_randomized := 0.0
@export var since_randomized_int : int = 0

@export var networks_json : Array[Dictionary]
