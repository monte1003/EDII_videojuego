shader_type spatial;
render_mode cull_disabled, diffuse_burley;

//Flags on a rope: vertex alpha is the distance from the rope, which flutters
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.z += sin(TIME * 2.6 + world.x * 0.9 + world.z * 0.7) * 0.16 * COLOR.a;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.8;
}
