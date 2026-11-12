shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, fog_disabled;

//A soap bubble: only its rim shows, with the colours of oil on water over the colour of what it holds, and a small shine.
//It adds light instead of blending, so it costs very little
uniform vec4 tint : source_color = vec4(1.0);
uniform float glow = 1.0;
uniform float fade = 1.0;

void fragment() {
	vec3 normal = normalize(NORMAL);
	float rim = pow(1.0 - clamp(dot(normal, normalize(VIEW)), 0.0, 1.0), 2.2);
	vec3 oil = 0.5 + 0.5 * cos(6.2831 * (rim * 1.3 + vec3(0.0, 0.33, 0.67)) + TIME * 0.8 + normal.y * 3.0);
	vec3 color = mix(tint.rgb, oil, 0.4) * (0.1 + rim * 1.5);
	float shine = pow(clamp(dot(normal, normalize(vec3(0.4, 0.8, 0.45))), 0.0, 1.0), 48.0);
	ALBEDO = (color * glow + vec3(shine) * 0.7) * fade;
}
