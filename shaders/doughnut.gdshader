shader_type canvas_item;

uniform vec4 circle_color : source_color = vec4(1.0, 1.0, 0.0, 1.0); // Yellow
uniform float radius = 0.4;
uniform float thickness = 0.04;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);

    float edge = smoothstep(radius - thickness, radius, dist) * (1.0 - smoothstep(radius, radius + thickness, dist));
    COLOR = circle_color * edge;
}
