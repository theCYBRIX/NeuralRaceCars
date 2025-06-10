extends OptionButton


const TRACKS := {
	"Track 2" : "res://scenes/track_2.tscn",
	"Track 3" : "res://scenes/track_3.tscn",
	"Point to Point" : "res://scenes/point_to_point.tscn",
}


func _ready() -> void:
	for track in TRACKS.keys():
		add_item(track)


func _on_item_selected(index: int) -> void:
	GameSettings.track_scene = ResourceLoader.load(TRACKS.values()[index])
