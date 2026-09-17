shader_type canvas_item;

uniform vec4 sky_top : source_color = vec4(0.33, 0.76, 0.96, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.78, 0.95, 1.0, 1.0);
uniform vec4 far_hills : source_color = vec4(0.93, 0.55, 0.85, 1.0);
uniform vec4 near_hills : source_color = vec4(0.49, 0.85, 0.36, 1.0);
uniform vec4 ground : source_color = vec4(0.36, 0.74, 0.27, 1.0);

float edge(float value, float limit) {
	float width = fwidth(value);
	return smoothstep(limit - width, limit + width, value);
}

void fragment() {
	vec4 color = mix(sky_top, sky_bottom, UV.y);
	float far_line = 0.58 + 0.07 * sin(UV.x * 7.0 + 0.8) + 0.03 * sin(UV.x * 19.0);
	color = mix(color, far_hills, edge(UV.y, far_line));
	float near_line = 0.7 + 0.05 * sin(UV.x * 5.0 + 2.4);
	color = mix(color, near_hills, edge(UV.y, near_line));
	color = mix(color, ground, clamp((UV.y - near_line) * 2.5, 0.0, 1.0) * edge(UV.y, near_line));
	COLOR = color;
}
