extends OptionButton


func _ready() -> void:
	for track in SceneManager.Track.values():
		add_item(SceneManager.get_track_name(track), track)


func _on_item_selected(index: int) -> void:
	GameSettings.track_path = SceneManager.TRACKS[get_item_id(index)]
