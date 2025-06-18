class_name TrainingState
extends Resource

@export var time_elapsed : float = 0.0

@export var generation : int = 0

@export var highest_score : float = 0.0

@export var networks : Array = []

@export var input_map : Array[NetworkInputMapper.InputProperty] = NetworkInputMapper.DEFAULT_MAPPING

@export var replays : Dictionary = {}

func to_dict() -> Dictionary:
	return {
		"time_elapsed" = time_elapsed,
		"generation" = generation,
		"highest_score" = highest_score,
		"networks" = networks,
		"input_map" = input_map,
		"replays" = replays,
	}

static func from_dict(dict : Dictionary) -> TrainingState:
	var state := TrainingState.new()
	if dict.has("time_elapsed"):
		state.time_elapsed = dict.time_elapsed
	if dict.has("generation"):
		state.generation = dict.generation
	if dict.has("highest_score"):
		state.highest_score = dict.highest_score
	if dict.has("networks"):
		@warning_ignore("shadowed_variable")
		var networks = dict.networks
		if networks is Array:
			var network_array : Array[Dictionary] = []
			network_array.resize(networks.size())
			var index = 0
			for item in networks:
				if item is Dictionary and item.has("network"):
					network_array[index] = item.network
				else:
					network_array[index] = item
				index += 1
			state.networks = network_array
	if dict.has("input_map"):
		state.input_map = []
		state.input_map.append_array(dict.input_map.map(_float_to_input_property))
	if dict.has("replays"):
		state.replays = dict.replays
	return state

static func _float_to_input_property(num : float) -> NetworkInputMapper.InputProperty:
	return roundi(num) as NetworkInputMapper.InputProperty 
