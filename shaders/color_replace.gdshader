shader_type canvas_item;

uniform vec3 target_color : source_color;
uniform vec4 replacement_color : source_color;
uniform float color_thresh;

void fragment() {
	vec4 pixel_color = texture(TEXTURE, UV);
	if(distance(pixel_color.rgb, target_color) <= color_thresh){
		pixel_color = replacement_color;
	}
	COLOR = pixel_color;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
