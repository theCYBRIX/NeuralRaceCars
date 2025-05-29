class_name TrainingRecordingManager
extends Node


@export var evolution_manager : EvolutionManager : set = set_evolution_manager
@export var enabled := true : set = set_enabled
@export var recordings_per_gen : int = 1
@export var frame_rate : int = ReplayRecorder.DEFAULT_FRAME_RATE

var training_replay_data := TrainingReplayData.new()

var _current_recordings : Array[ScoredReplay] = []
var _replay_recorders : Dictionary = {}


func set_enabled(value := true) -> void:
	if enabled == value:
		return
	enabled = value
	for recorder in _replay_recorders.values():
		recorder.enabled = enabled
	if enabled:
		_update_replay_recorders()


func set_evolution_manager(manager : EvolutionManager) -> void:
	if evolution_manager:
		Util.disconnect_from_signal(_on_evolution_manager_generation_finished, evolution_manager.generation_finished)
		Util.disconnect_from_signal(_on_evolution_manager_car_instantiated, evolution_manager.car_instanciated)
		Util.disconnect_from_signal(_on_evolution_manager_car_freed, evolution_manager.car_freed)
		_release_all_replay_recorders()
	
	evolution_manager = manager
	
	if evolution_manager:
		_update_replay_recorders()
		
		evolution_manager.generation_finished.connect(_on_evolution_manager_generation_finished)
		evolution_manager.car_instanciated.connect(_on_evolution_manager_car_instantiated)
		evolution_manager.car_freed.connect(_on_evolution_manager_car_freed)


func _update_replay_recorders() -> void:
	if not evolution_manager or not enabled:
		return
	var missing_recorders := evolution_manager.cars.filter(func(x : NeuralCar) -> bool: return not _replay_recorders.has(x))
	for car in missing_recorders:
		_attach_replay_recorder(car)


func _release_all_replay_recorders() -> void:
	for car in _replay_recorders.keys():
		_release_replay_recorder(car)


func _release_replay_recorder(car : NeuralCar) -> void:
	_replay_recorders[car].queue_free()
	_replay_recorders.erase(car)


func _attach_replay_recorder(car : NeuralCar) -> void:
	if not enabled:
		return
	var replay_recorder := _instantiate_replay_recorder()
	replay_recorder.stopped.connect(_on_replay_recorder_stopped.bind(car))
	_replay_recorders[car] = replay_recorder
	replay_recorder.target = car
	add_child(replay_recorder, false, INTERNAL_MODE_FRONT)


func _instantiate_replay_recorder() -> NeuralCarReplayRecorder:
	var replay_recorder := NeuralCarReplayRecorder.new()
	replay_recorder.frame_rate = frame_rate
	return replay_recorder


func _on_replay_recorder_stopped(car : NeuralCar) -> void:
	var score : float = evolution_manager.get_network_score(car.id)
	if _current_recordings.size() < recordings_per_gen:
		_current_recordings.append(ScoredReplay.new(_replay_recorders[car].replay_data, score))
	elif score > _current_recordings.front().score:
		_current_recordings[0] = ScoredReplay.new(_replay_recorders[car].replay_data, score)
		_current_recordings.sort_custom(ScoredReplay.sort_ascending)


func _on_evolution_manager_car_instantiated(car : NeuralCar) -> void:
	_attach_replay_recorder(car)


func _on_evolution_manager_car_freed(car : NeuralCar) -> void:
	if _replay_recorders.has(car):
		_release_replay_recorder(car)


func _on_evolution_manager_generation_finished(generation : int) -> void:
	if evolution_manager.improvement_flag or not evolution_manager.improvement_flag: #TODO: Remove
		for recording in _current_recordings:
			recording.replay.flush_buffer()
			recording.replay.convert_to_deltas()
		training_replay_data.replays[str(generation)] = _current_recordings
		_current_recordings = []


class ScoredReplay:
	var score : float
	var replay : ReplayData
	
	@warning_ignore("shadowed_variable")
	func _init(replay : ReplayData, score : float) -> void:
		self.score = score
		self.replay = replay
	
	static func sort_ascending(a : ScoredReplay, b : ScoredReplay) -> bool:
		return a.score < b.score
	
	static func sort_descending(a : ScoredReplay, b : ScoredReplay) -> bool:
		return a.score > b.score
