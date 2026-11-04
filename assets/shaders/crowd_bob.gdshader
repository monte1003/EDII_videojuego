shader_type spatial;
render_mode diffuse_burley;

//A crowd of fans in one draw call: each one hops on its own beat and "excitement" makes the whole crowd jump higher
uniform float excitement : hint_range(0.0, 3.0) = 1.0;
uniform float hop_height = 0.22;
varying vec3 tint;

void vertex() {
	tint = COLOR.rgb;
	vec3 base = MODEL_MATRIX[3].xyz;
	float phase = base.x * 3.7 + base.z * 5.3 + base.y * 1.9;
	float beat = 3.2 + fract(phase * 0.37) * 2.2;
	float hop = max(sin(TIME * beat + phase), 0.0);
	VERTEX.y += hop * hop_height * excitement;
	VERTEX.y *= 1.0 + 0.05 * hop * excitement * (1.0 - UV.y);
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.8;
}
