class_name TrackProvider
extends Node

signal track_updated(track : BaseTrack)

@export var target_path : NodePath = ".." : set = set_target_path
@export var track_internal_mode : Node.InternalMode = INTERNAL_MODE_DISABLED
@export var track_scene : PackedScene : set = set_track_scene
var track : BaseTrack : set = set_track


func _ready() -> void:
	if not track and not track_scene:
		track_scene = GameSettings.track_scene


func has_track():
	return track != null and is_instance_valid(track)


func set_target_path(path : NodePath):
	var path_node := get_node_or_null(target_path)
	if path_node and track:
		var previous_parent := track.get_parent()
		if previous_parent:
			previous_parent.remove_child(track)
	
	target_path = path
	
	if is_node_ready() and track:
		call_deferred("_parent_track_to", get_node(target_path))


func set_track(instance : BaseTrack):
	if track:
		track.queue_free()
	
	track = instance
	
	if track and target_path:
		call_deferred("_parent_track_to", get_node(target_path))


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
		call_deferred("_parent_track_to", track.get_parent())


func _parent_track_to(node : Node):
	if node:
		if track.get_parent():
			track.get_parent().remove_child(track)
		
		if track.is_node_ready():
			track.request_ready()
		track.ready.connect(emit_signal.bind("track_updated", track), CONNECT_ONE_SHOT)
		node.add_child(track, false, track_internal_mode)
