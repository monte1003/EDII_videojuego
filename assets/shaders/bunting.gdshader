shader_type spatial;
render_mode cull_disabled, diffuse_burley;

//Flags on a rope: the colour is in the vertex and its alpha says how far a point is from the rope (0 on it, 1 at the tip), which is what flutters
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.z += sin(TIME * 2.6 + world.x * 0.9 + world.z * 0.7) * 0.16 * COLOR.a;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.8;
}
