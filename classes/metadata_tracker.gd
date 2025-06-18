class_name MetadataTracker
extends RefCounted


var types : Dictionary[String, TypeDetails] = {}


func get_member_count(type : String) -> float:
	if not types.has(type):
		return 0
	else:
		return types[type].count


func get_best_score(type : String) -> float:
	if not types.has(type):
		return 0
	else:
		return types[type].best_score


func get_worst_score(type : String) -> float:
	if not types.has(type):
		return 0
	else:
		return types[type].worst_score


func get_average_score(type : String) -> float:
	if not types.has(type):
		return 0
	else:
		return types[type].average_score


func analyze(scores : Dictionary, metadata : Dictionary) -> void:
	for type in types.values():
		type.reset()
	
	for id in scores.keys():
		var score : float = scores[id]
		if not metadata.has(id) or not metadata[id].has("offspringGenerator"):
			continue
		var type_name : String = strip_after_parenthesis(metadata[id].offspringGenerator)
		var type : TypeDetails
		
		if not types.has(type_name):
			type = TypeDetails.new(type_name)
			types[type_name] = type
		else:
			type = types[type_name]
		
		type.register(score)


func strip_after_parenthesis(s: String) -> String:
	var index := s.find(" (")
	if index == -1:
		return s
	return s.substr(0, index)


class TypeDetails:
	var type_name : String
	var count : int = 0
	var best_score : float = 0
	var worst_score : float = 0
	var average_score : float = 0 : get = get_average
	var scores : Array[float] = []
	var _average_changed := false
	
	
	func _init(name : String):
		type_name = name
	
	
	func reset() -> void:
		count = 0
		best_score = 0
		worst_score = 0
		average_score = 0
		scores = []
		_average_changed = false
	
	
	func register(score : float) -> void:
		count += 1
		scores.append(score)
		_average_changed = true
		if count == 1:
			best_score = score
			worst_score = score
		elif score > best_score:
			best_score = score
		elif score < worst_score:
			worst_score = worst_score
	
	
	func get_average() -> float:
		if _average_changed:
			_update_average()
		return average_score
	
	
	func get_top_average(fraction: float) -> float:
		if scores.is_empty():
			return 0.0
		
		@warning_ignore("shadowed_variable")
		var count := int(round(scores.size() * fraction))
		count = clamp(count, 1, scores.size())
		
		var sorted_scores := scores.duplicate()
		sorted_scores.sort()
		sorted_scores.reverse()
		
		var top_scores := sorted_scores.slice(0, count)
		
		var total := 0.0
		for score in top_scores:
			total += score
		
		return total / count
	
	
	func _update_average() -> void:
		var sum : float = 0
		
		for score in scores:
			sum += score
		
		average_score = sum / scores.size()
		_average_changed = false
