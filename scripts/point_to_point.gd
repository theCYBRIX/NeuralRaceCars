extends BaseTrack

var checkpoints : Array[CollisionShape2D]

const OPEN_AREA_COORD := Vector2i(3, 0)

@export var checkpoint_count : int : set = set_checkpoint_count
@export var checkpoint_shape : Shape2D : set = set_checkpoint_shape
@export var min_checkpoint_separation : float

@onready var tile_map: TileMapLayer = $TileMap


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	for collision_shape in checkpoints:
		checkpoints_area.add_child(collision_shape)
	
	randomize_checkpoints()


func get_progress(car : Car) -> float:
	var previous := spawn_point.global_position if car.checkpoint_index <= 0 else checkpoints[(car.checkpoint_index - 1) % checkpoints.size()].global_position
	var next := checkpoints[car.checkpoint_index % checkpoints.size()].global_position
	return car.checkpoint_index + (1 - (car.global_position.distance_squared_to(next) / previous.distance_squared_to(next)))


func randomize_checkpoints() -> void:
	var usable_cells : Array = tile_map.get_used_cells().filter(func(x): return tile_map.get_cell_atlas_coords(x) == OPEN_AREA_COORD)
	usable_cells = usable_cells
	usable_cells.shuffle()
	
	if usable_cells.size() < checkpoints.size():
		push_warning("Track has more checkpoints than available cells.")
	
	var prev_checkpoint_pos := tile_map.local_to_map(spawn_point.position)
	
	for point : CollisionShape2D in checkpoints:
		var chosen_pos : Vector2i = usable_cells.front()
		var chosen_separation := chosen_pos.distance_to(prev_checkpoint_pos)
		if chosen_separation < min_checkpoint_separation:
			var chosen_index : int = 0
			var index : int = 1
			while index < usable_cells.size():
				var separation : float = usable_cells[index].distance_to(prev_checkpoint_pos)
				if separation <= chosen_separation:
					continue
				
				chosen_index = index
				chosen_pos = usable_cells[index]
				chosen_separation = separation
				
				if chosen_separation >= min_checkpoint_separation:
					break
			
			chosen_pos = usable_cells.pop_at(chosen_index)
		else:
			usable_cells.pop_front()
		
		prev_checkpoint_pos = chosen_pos
		point.position = tile_map.map_to_local(prev_checkpoint_pos)


func set_checkpoint_count(count : int) -> void:
	checkpoint_count = count
	
	for i in checkpoints:
		i.queue_free()
	
	checkpoints.resize(checkpoint_count)
	for i in range(checkpoint_count):
		var collision_shape := CollisionShape2D.new()
		collision_shape.shape = checkpoint_shape
		checkpoints[i] = collision_shape


func set_checkpoint_shape(shape : Shape2D) -> void:
	checkpoint_shape = shape
	for collision_shape in checkpoints:
		collision_shape.shape = shape
