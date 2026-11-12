shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

//The viewfinder the drone draws on the floor: thick light corners with a dark outline so they read on any colour,
//the lines of thirds, and the circle of the centre. Widths are in meters whatever the size of the frame
uniform float side = 6.0;
uniform float center_share = 0.25;
uniform vec4 line_color : source_color = vec4(1.0);
uniform vec4 edge_color : source_color = vec4(0.16, 0.13, 0.27, 1.0);
uniform float blink = 0.0;
uniform float fill = 0.1;

float band(float distance_to, float half_width) {
	return 1.0 - smoothstep(half_width - 0.012, half_width + 0.012, distance_to);
}

void fragment() {
	vec2 at = (UV - 0.5) * side;
	vec2 from_edge = side * 0.5 - abs(at);
	float nearest = min(from_edge.x, from_edge.y);
	float corner_reach = side * 0.24;
	float in_corner = step(max(from_edge.x, from_edge.y), corner_reach);
	float bracket = band(nearest - 0.2, 0.11) * in_corner;
	float bracket_edge = band(nearest - 0.2, 0.2) * in_corner;
	float border = band(nearest - 0.2, 0.03);
	vec2 third = abs(abs(at) - side / 6.0);
	float thirds = max(band(third.x, 0.025), band(third.y, 0.025)) * step(0.3, nearest) * 0.55;
	float ring_distance = abs(length(at) - side * center_share);
	float ring = band(ring_distance, 0.06);
	float ring_edge = band(ring_distance, 0.12);
	float light = max(max(bracket, ring), max(thirds, border * 0.8));
	float dark = max(bracket_edge, ring_edge);
	vec3 lit = mix(line_color.rgb, vec3(1.0, 0.85, 0.3), blink);
	ALBEDO = mix(edge_color.rgb, lit, clamp(light / max(dark, 0.001), 0.0, 1.0) * step(0.001, light));
	ALPHA = max(max(light, dark * 0.85), fill + blink * 0.14) * step(0.0, nearest);
}
