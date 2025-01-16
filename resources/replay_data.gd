class_name ReplayData
extends Resource

const DEFAULT_BUFFER_SIZE : int = 1024
const DEFAULT_FRAME_RATE : int = 24

@export var _data : Array[Array] = []
@export var frame_rate : int = DEFAULT_FRAME_RATE

var _buffer_size : int : set = set_buffer_size
var _buffer : Array[Snapshot] = []
var _buffer_index = 0
var _frame_count : int = 0


func _init(buffer_size := DEFAULT_BUFFER_SIZE) -> void:
	_buffer_size = buffer_size
	_frame_count = _count_frames()


func record(position : Vector2, rotation : float):
	_buffer[_buffer_index] = Snapshot.new(position, rotation)
	_buffer_index += 1
	if _buffer_index == _buffer_size:
		_data.append(_buffer)
		_reset_buffer()
	_frame_count += 1


func get_frame(idx : int) -> Snapshot:
	if idx < 0 or idx >= _frame_count:
		push_warning("Index %d out of bounds for ReplayData of size %d." % [idx, _frame_count])
		return null
	return _data[idx / _buffer_size][idx % _buffer_size]


func get_length_sec() -> float:
	return _frame_count / float(frame_rate)


func size() -> int:
	return _frame_count


func clear() -> void:
	_data.clear()
	_buffer.clear()
	_buffer_index = 0


func _count_frames() -> int:
	return _data.size() * _buffer_size + (_buffer_index + 1)


func generate_animation(position_path : String, rotation_path : String) -> Animation:
	var animation := Animation.new()
	var animation_length := get_length_sec()
	animation.length = animation_length
	
	var position_track := animation.add_track(Animation.TYPE_ANIMATION)
	var rotation_track := animation.add_track(Animation.TYPE_ANIMATION)
	animation.track_set_path(position_track, position_path)
	animation.track_set_path(rotation_track, rotation_path)
	
	var frame_count := size()
	var time_offset := animation_length / float(frame_count)
	
	var frame_index : int = 0
	while frame_index < frame_count:
		var time := time_offset * frame_index
		var frame_data = get_frame(frame_index)
		animation.track_insert_key(position_track, time, frame_data.position)
		animation.track_insert_key(rotation_track, time, frame_data.rotation)
		frame_index += 1
	
	return animation


func _reset_buffer():
	_buffer = []
	_buffer.resize(_buffer_size)
	_buffer_index = 0


func set_buffer_size(size : int):
	if size == _buffer_size: return
	_buffer_size = size
	
	var slice_start_idx : int = 0
	var slice_end_idx : int = _buffer_size
	while slice_end_idx <= _buffer.size():
		_data.append(_buffer.slice(slice_start_idx, slice_end_idx))
		slice_start_idx = slice_end_idx
		slice_end_idx += _buffer_size
	
	if _buffer.size() != _buffer_size:
		_buffer.resize(_buffer_size)
	
	_rebundle_data()


func _rebundle_data() -> void:
	var total_snap_count : int = 0
	for chunk in _data:
		total_snap_count += chunk.size()
	
	var rebundled : Array[Array] = []
	rebundled.resize(total_snap_count / _buffer_size)
	
	var rebundled_idx : int = 0
	var buffer : Array[Snapshot] = []
	buffer.resize(_buffer_size)
	var buffer_index = 0
	
	for chunk in _data:
		for snap in chunk:
			buffer[buffer_index] = snap
			buffer_index += 1
			if buffer_index == _buffer_size:
				rebundled[rebundled_idx] = buffer
				rebundled_idx += 1
				buffer = []
				buffer.resize(_buffer_size)
				buffer_index = 0
	
	_buffer = buffer
	_buffer_index = buffer_index


class Snapshot:
	var position : Vector2
	var rotation : float
	
	func _init(pos : Vector2, rot : float) -> void:
		position = position
		rotation = rot
