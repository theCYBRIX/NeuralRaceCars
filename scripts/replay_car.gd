class_name ReplayCar
extends Node2D


const ANIMATION_NAME := "replay"
const POSITION_PATH := ".:position"
const ROTATION_PATH := ".:rotation"
const ANIMATION_LIBRARY_NAME := "ReplayCar"


@export var replay_data : ReplayData : set = set_replay_data


@onready var animation_player: AnimationPlayer = $AnimationPlayer : get = get_animation_player
@onready var checkpoint_tracker: CheckpointTracker = $CheckpointTracker


func _ready() -> void:
	_on_replay_data_changed()


func start(custom_blend: float = -1, custom_speed: float = 1.0, from_end: bool = false) -> void:
	animation_player.play(ANIMATION_LIBRARY_NAME + "/" + ANIMATION_NAME, custom_blend, custom_speed, from_end)


func get_animation_player() -> AnimationPlayer:
	return animation_player


func update_animation() -> void:
	var animation_library : AnimationLibrary
	if animation_player.has_animation_library(ANIMATION_LIBRARY_NAME):
		animation_library = animation_player.get_animation_library(ANIMATION_LIBRARY_NAME);
		remove_animation(animation_library)
	else:
		animation_library = AnimationLibrary.new()
		animation_player.add_animation_library(ANIMATION_LIBRARY_NAME, animation_library)
	
	animation_library.add_animation(ANIMATION_NAME, replay_data.generate_animation(POSITION_PATH, ROTATION_PATH))


func remove_animation(library : AnimationLibrary) -> void:
	if library.has_animation(ANIMATION_NAME):
		library.remove_animation(ANIMATION_NAME)


func set_replay_data(data : ReplayData) -> void:
	replay_data = data
	_on_replay_data_changed()


func _on_replay_data_changed() -> void:
	if is_node_ready():
		if replay_data:
			update_animation()
		elif animation_player.has_animation_library(ANIMATION_LIBRARY_NAME):
			var animation_library := animation_player.get_animation_library(ANIMATION_LIBRARY_NAME);
			remove_animation(animation_library)
			animation_player.remove_animation_library(ANIMATION_LIBRARY_NAME)
