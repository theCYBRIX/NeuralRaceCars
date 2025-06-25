shader_type canvas_item;

uniform vec4 even_color : source_color = vec4(0, 0, 0, 1);
uniform vec4 odd_color : source_color = vec4(1, 1, 1, 1);
uniform vec2 rectangle_size = vec2(40, 40);
uniform float speed = 0;
uniform float angle_degrees = 0;

void fragment() {
	float angle_radians = radians(angle_degrees);
	vec2 velocity = vec2(cos(angle_radians), sin(angle_radians)) * speed;
	vec2 uv_offset = velocity * TIME;
	vec2 pixel_coord = (UV + uv_offset) / SCREEN_PIXEL_SIZE;
	ivec2 grid_coord = ivec2(round(pixel_coord / rectangle_size));
	bool is_even = grid_coord.x % 2 == grid_coord.y % 2;
	if(is_even){
		COLOR = even_color;
	} else {
		COLOR = odd_color;
	}
}
