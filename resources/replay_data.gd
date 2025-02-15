class_name ReplayData
extends Resource

const DEFAULT_BUFFER_SIZE : int = 1024

@export var _data : Array[Array] = []
@export var _frame_count : int = 0
@export var _is_delta := false

var _buffer_size : int : set = set_buffer_size
var _buffer : Array[TransformRecord] = []
var _buffer_index : int = 0
var _last_record : TransformRecord

var _iter_index : int

var _positon : Vector2 = Vector2.ZERO
var _rotation : float = 0

func _init(buffer_size := DEFAULT_BUFFER_SIZE) -> void:
	_buffer_size = buffer_size


func record(time_stamp : float, position : Vector2, rotation : float):
	if _last_record and _last_record.position == position and _last_record.rotation == rotation:
		return
	
	var curr_record : TransformRecord
	if _is_delta:
		curr_record = TransformRecord.new(time_stamp - _last_record.time_stamp, position - _last_record.position, rotation - _last_record.rotation)
	else:
		curr_record = TransformRecord.new(time_stamp, position, rotation)
	
	_buffer[_buffer_index] = curr_record
	_last_record = curr_record
	_buffer_index += 1
	if _buffer_index == _buffer.size():
		flush_buffer()
	_frame_count += 1


func get_record(idx : int) -> TransformRecord:
	if idx < 0 or idx >= _frame_count:
		push_warning("Index %d out of bounds for ReplayData of size %d." % [idx, _frame_count])
		return null
	return _data[idx / _buffer_size][idx % _buffer_size]



func flush_buffer() -> void:
	if _buffer_index == 0:
		return
	if _data.size() > 0:
		var prev_block_size : int = _data.back().size()
		if prev_block_size < _buffer_size:
			_data.back().append_array(_buffer.slice(0, _buffer_size - prev_block_size))
			_buffer = _buffer.slice(_buffer_size - prev_block_size)
			_buffer.resize(_buffer_size)
			return
	_data.append(_buffer.slice(0, _buffer_index))
	_reset_buffer()


func get_length_sec() -> float:
	return _buffer[_buffer_index - 1].time_stamp if _buffer_index > 0 else _data.back().back().time_stamp


func size() -> int:
	return _frame_count


func clear() -> void:
	_data.clear()
	_buffer.clear()
	_buffer_index = 0
	_frame_count = 0


func generate_animation(position_path : String, rotation_path : String) -> Animation:
	var animation := Animation.new()
	var animation_length := get_length_sec()
	animation.length = animation_length
	
	var position_track := animation.add_track(Animation.TYPE_VALUE)
	var rotation_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(position_track, position_path)
	animation.track_set_path(rotation_track, rotation_path)
	
	var frame_count := size()
	
	for frame_data in self:
		animation.track_insert_key(position_track, frame_data.time_stamp, frame_data.position)
		animation.track_insert_key(rotation_track, frame_data.time_stamp, frame_data.rotation)
	
	return animation


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


func convert_to_deltas() -> void:
	if _is_delta:
		return
	
	var prev_record := TransformRecord.new(0, Vector2.ZERO, 0)
	var block_index : int = 0
	var record_index : int = 0
	while block_index < _data.size():
		var block := _data[block_index]
		block_index += 1
		while record_index < block.size():
			var curr_record : TransformRecord = block[record_index]
			block[record_index] = TransformRecord.new(curr_record.time_stamp - prev_record.time_stamp, curr_record.position - prev_record.position, curr_record.rotation - prev_record.rotation)
			prev_record = curr_record
			record_index += 1
	
	_is_delta = true


func convert_to_absolute() -> void:
	if not _is_delta:
		return
	
	var prev_record := TransformRecord.new(0, Vector2.ZERO, 0)
	var block_index : int = 0
	var record_index : int = 0
	while block_index < _data.size():
		var block := _data[block_index]
		block_index += 1
		while record_index < block.size():
			var curr_record : TransformRecord = block[record_index]
			block[record_index] = TransformRecord.new(prev_record.time_stamp + curr_record.time_stamp, prev_record.position + curr_record.position, prev_record.rotation + curr_record.rotation)
			prev_record = curr_record
			record_index += 1
	
	_is_delta = false


func _reset_buffer():
	_buffer = []
	_buffer.resize(_buffer_size)
	_buffer_index = 0


func _rebundle_data() -> void:
	var total_snap_count : int = 0
	for chunk in _data:
		total_snap_count += chunk.size()
	
	var rebundled : Array[Array] = []
	rebundled.resize(total_snap_count / _buffer_size)
	
	var rebundled_idx : int = 0
	var buffer : Array[TransformRecord] = []
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


func save(file_path : String, overwrite := false) -> Error:
	if FileAccess.file_exists(file_path):
		if not overwrite: 
			return ERR_ALREADY_EXISTS
		else:
			var error := DirAccess.remove_absolute(Util.globalize_path(file_path))
			if error != OK: return error
	return ResourceSaver.save(self, file_path, ResourceSaver.FLAG_COMPRESS)


func should_continue():
	return (_iter_index < _frame_count)

func _iter_init(arg):
	_iter_index = 0
	return should_continue()

func _iter_next(arg):
	_iter_index += 1
	return should_continue()

func _iter_get(arg):
	return get_record(_iter_index)


class TransformRecord:
	var time_stamp : float
	var position : Vector2
	var rotation : float
	
	func _init(time : float, pos : Vector2, rot : float) -> void:
		time_stamp = time
		position = pos
		rotation = rot
