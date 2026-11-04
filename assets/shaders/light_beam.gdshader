shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;

//A spotlight beam: it starts at its narrow bottom end, fades going up and softens toward its sides
uniform vec4 beam_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float strength = 0.4;
uniform float beam_length = 40.0;
varying float distance_share;

void vertex() {
	distance_share = clamp((VERTEX.y + beam_length * 0.5) / beam_length, 0.0, 1.0);
}

void fragment() {
	float side = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.4);
	ALBEDO = beam_color.rgb;
	ALPHA = strength * side * (1.0 - distance_share) * (1.0 - distance_share);
}
