class_name TrackProvider
extends Node

@warning_ignore("unused_signal")
signal track_updated(track : BaseTrack)

@export var track_parent : Node = self : set = set_track_parent
@export var track_internal_mode : Node.InternalMode = INTERNAL_MODE_DISABLED
@export var track_scene : PackedScene : set = set_track_scene

var track : BaseTrack : set = set_track, get = get_track

func _ready() -> void:
	if not track_scene:
		track_scene = GameSettings.get_track()
	else:
		_reparent_track()


func get_track() -> BaseTrack:
	return track


func has_track():
	return track != null and is_instance_valid(track)


func set_track_parent(parent : Node):
	track_parent = parent
	
	if track:
		_reparent_track()


func set_track(instance : BaseTrack):
	if track == instance:
		return
	
	if track:
		track.queue_free()
	
	track = instance
	
	if track:
		_reparent_track()


func set_track_scene(scene : PackedScene):
	track_scene = scene
	if track_scene:
		var instance = track_scene.instantiate()
		if instance is BaseTrack: 
			track = instance
		else:
			push_error("Track scene is not of type BaseTrack.")


func set_internal_mode(mode : Node.InternalMode):
	if track_internal_mode == mode: return
	track_internal_mode = mode
	if track:
		_reparent_track()


func _reparent_track():
	if track:
		var curr_parent := track.get_parent()
		if curr_parent:
			curr_parent.remove_child(track)
		
		if track_parent:
			track_parent.add_child(track, false, track_internal_mode)
			track_updated.emit(track)
