class_name SpriteColorManager
extends Node

@export var default_color : Color = Color.GREEN
@export var color_thresh : float = 0

@export var texture : Texture2D
var texture_cache : Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	texture_cache[default_color] = texture.get_image()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func change_body_color(new_color : Color) -> Image:
	if texture_cache.has(new_color): return texture_cache.get(new_color)
	var image : Image = color_replace(default_color, new_color, color_thresh)
	texture_cache[new_color] = image
	return image

func color_replace(old_color : Color, new_color : Color, thresh : float) -> Image:
	var image : Image = texture.get_image().duplicate()
	for x in range(image.get_width()):
		for y in range(image.get_height()):
			if image.get_pixel(x, y) == old_color:
				image.set_pixel(x, y, new_color)
	image.clear_mipmaps()
	image.generate_mipmaps()
	
	return image

func is_color_within_thresh(color_a : Color, color_b : Color, thresh : float):
	return is_within_thresh(color_a.r, color_b.r, thresh) and is_within_thresh(color_a.g, color_b.g, thresh) and is_within_thresh(color_a.b, color_b.b, thresh)

func is_within_thresh(a : float, b : float, thresh : float) -> bool:
	return abs(a - b) <= thresh
