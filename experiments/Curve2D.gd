@tool
extends Node2D

@onready var point_a : Marker2D = $A
@onready var point_b : Marker2D = $B
@onready var bezier : Marker2D = $Bezier

@export_range(0, 100) var resolution : int = 20 : set = set_resolution

@onready var static_body: StaticBody2D = $StaticBody2D
var shapes : Array[CollisionShape2D] = []

var a : Vector2
var b : Vector2
var c : Vector2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update()
	set_process(Engine.is_editor_hint())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	check_update()

func check_update():
	if a == point_a.position and b == point_b.position and c == bezier.position: return
	update()


func update() -> void:
	a = point_a.position
	b = point_b.position
	c = bezier.position
	
	for s : CollisionShape2D in shapes:
		static_body.remove_child(s)
		s.queue_free()
	
	shapes.clear()
	shapes.resize(resolution)
	
	var new_segment = SegmentShape2D.new()
	var new_shape = CollisionShape2D.new()
	shapes[0] = new_shape
	new_shape.shape = new_segment
	
	new_segment.a = a
	
	for i : int in range(1, resolution):
		var t : float = float(i) / (resolution + 1)
		var lerp_1 : Vector2 = lerp(a, c, t)
		var lerp_2 : Vector2 = lerp(c, b, t)
		var lerp_3 : Vector2 = lerp(lerp_1, lerp_2, t)
		new_segment.b = lerp_3
		new_segment = SegmentShape2D.new()
		new_shape = CollisionShape2D.new()
		shapes[i] = new_shape
		new_shape.shape = new_segment
		new_segment.a = lerp_3
	
	new_segment.b = b
	
	for s : CollisionShape2D in shapes:
		static_body.add_child(s)

func set_resolution(n : int):
	resolution = clampi(n, 0, 100)
	if is_node_ready(): update()
