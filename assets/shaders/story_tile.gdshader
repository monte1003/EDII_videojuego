shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

//Story tile top: ring like an unseen story that empties while the tile shakes
uniform vec4 fill : source_color = vec4(0.88, 0.97, 1.0, 1.0);
uniform vec4 ring_a : source_color = vec4(0.93, 0.31, 0.72, 1.0);
uniform vec4 ring_b : source_color = vec4(1.0, 0.68, 0.32, 1.0);
instance uniform float drain = 0.0;
instance uniform float flash = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float edge = max(abs(p.x), abs(p.y));
	float soft = fwidth(edge) * 1.5;
	float ring = smoothstep(0.72 - soft, 0.72 + soft, edge) * (1.0 - smoothstep(0.9 - soft, 0.9 + soft, edge));
	float angle = fract(atan(p.x, -p.y) / 6.2831853 + 1.0);
	float kept = step(drain, angle);
	vec3 frame = mix(ring_a.rgb, ring_b.rgb, clamp(0.5 + 0.35 * (p.x - p.y), 0.0, 1.0));
	vec3 color = mix(fill.rgb, frame, ring * kept);
	float spot = 1.0 - smoothstep(0.36 - soft, 0.36 + soft, length(p));
	color = mix(color, mix(fill.rgb, frame, 0.3), spot);
	color = mix(color, vec3(1.0), flash);
	ALBEDO = color;
	EMISSION = frame * ring * kept * 0.3 + vec3(flash) * 0.5;
	ROUGHNESS = 0.4;
}
