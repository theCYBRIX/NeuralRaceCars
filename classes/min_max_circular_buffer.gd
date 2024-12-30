class_name MinMaxCircularBuffer
extends CircularBuffer

var _min : float = INF
var _max : float = -INF
var _min_idx : int = 0
var _max_idx : int = 0

func _init(max_size : int) -> void:
	super._init(max_size)


func append(value : float) -> void:
	var relative_new_idx : int = _max_size - 1 if _buffer.size() == _max_size else _buffer.size()
	
	super.append(value)
	
	_value_appended(value, relative_new_idx)


func clear() -> void:
	super.clear()
	_reset_min_max()


func _reset_min_max() -> void:
	_min = INF
	_min_idx = 0
	_max = -INF
	_max_idx = 0


func _refresh_min_max() -> void:
	if _buffer.is_empty():
		_reset_min_max()
		return
	
	_min = _buffer[0]
	_min_idx = 0
	_max = _buffer[0]
	_max_idx = 0
	
	var idx : int = 1
	var local_idx : int = __idx_to_local(idx) + 1
	while idx < _buffer.size():
		if local_idx == _buffer.size():
			local_idx = 0
		
		_check_update_min_max(_buffer[local_idx], local_idx)
		
		idx += 1
		local_idx += 1

func _value_appended(value : float, relative_idx : int) -> void:
	var idx = __idx_to_local(relative_idx)
	if (idx == _max_idx) or (idx == _min_idx):
		_min = INF if _min_idx >= _size else _buffer[__idx_to_local(_min_idx)]
		_max = -INF if _max_idx >= _size else _buffer[__idx_to_local(_max_idx)]
		_refresh_min_max()
		return
	
	_check_update_min_max(value, idx)

func _check_update_min_max(value : float, idx : int) -> void:
	if value > _max:
		_max = value
		_max_idx = idx
	if value < _min:
		_min = value
		_min_idx = idx

func get_min() -> float:
	return _min

func get_max() -> float:
	return _max
