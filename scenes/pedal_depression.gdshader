shader_type canvas_item;

uniform float press : hint_range(0.0, 1.0) = 0;
uniform float max_squish : hint_range(0.0, 10.0) = 0.25;

void fragment() {
	vec2 uv = UV;
	
	uv.y = uv.y * (1.0 + max_squish * press);
	
	if (uv.y > 1.0) {
		COLOR = vec4(0, 0, 0, 0);
	} else {
		COLOR = texture(TEXTURE, uv);
	}
}
