class_name CircularBuffer
extends RefCounted

var _buffer : PackedFloat32Array = []
var _start_index : int = 0
var _size : int = 0
var _max_size : int = 0

var _iterator_index : int = 0

func _init(max_size : int) -> void:
	self._max_size = max_size

func append(value : float) -> void:
	var index : int = _start_index + _size
	if index < _max_size:
		if _buffer.size() < _max_size:
			_buffer.append(value)
			_size += 1
			return
	else:
		index %= _max_size
	
	_buffer[index] = value
	if index == _start_index:
		_start_index += 1
		if _start_index == _buffer.size():
			_start_index = 0

func get_item(index : int) -> float:
	if index < 0 or index > _size:
		push_error("index %d out of bounds for buffer of size %d. Returning 0." % [index, _size])
		return 0
	
	var local_idx = __idx_to_local(index)
	
	return _buffer[local_idx]

func get_as_array() -> PackedFloat32Array:
	return PackedFloat32Array(_buffer.slice(_start_index, _buffer.size()) + _buffer.slice(0, _start_index))

func clear() -> void:
	_buffer.clear()
	_size = 0
	_start_index = 0

func size() -> int:
	return _size

func _iter_init(_arg) -> bool:
	_iterator_index = _start_index
	return _iter_should_continue()

func _iter_next(_arg) -> bool:
	if _iter_should_continue():
		_iterator_index = (_iterator_index + 1) % _size
		return true
	else:
		return false 

func _iter_get(_arg) -> float:
	return _buffer[_iterator_index]

func _iter_should_continue() -> bool:
	if _start_index > 0:
		return (_iterator_index > _start_index) or (_iterator_index < _start_index - 1) 
	else:
		return (_iterator_index < _size - 1)

func __idx_to_local(idx : int) -> int:
	var local_idx = _start_index + idx
	
	if local_idx >= _size:
		local_idx -= _size
	
	return local_idx
