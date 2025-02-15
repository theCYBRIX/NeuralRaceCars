shader_type canvas_item;

uniform vec3 target_color_1 : source_color;
uniform vec3 replacement_color_1 : source_color;
uniform vec3 target_color_2 : source_color;
uniform vec3 replacement_color_2 : source_color;
uniform float color_thresh;

void fragment() {
	vec3 pixel_color = texture(TEXTURE, UV).rgb;
	if(distance(pixel_color, target_color_1) <= color_thresh){
		pixel_color = replacement_color_1;
	} else if(distance(pixel_color, target_color_2) <= color_thresh){
		pixel_color = replacement_color_2;
	}
	COLOR.rgb = pixel_color;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
