shader_type canvas_item;

uniform int resolution;
uniform int data_points;
uniform int num_series;
uniform sampler2D series;

void fragment() {
	// Called for every pixel the material is visible on.
	float x = UV.x * float(resolution);
	if (x >= float(resolution - data_points)){
		vec3 cummulative_color = COLOR.rgb;
		int num_series_drawn = 0;
		for(int i = 0; i < num_series; i++){
			vec4 series_value = texture(series, vec2(x / float(i), float(i)));
			if(series_value.a >= (1.0 - UV.y)){
				cummulative_color += series_value.rgb;
				num_series_drawn ++;
			}
		}
		
		COLOR.rgb = cummulative_color / float(num_series_drawn);
		COLOR.a = 1.0;
	}
	//COLOR = vec4(1, 1, 1, 1);
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
