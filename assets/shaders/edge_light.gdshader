shader_type spatial;
render_mode unshaded;

//Light strips on the bridge sides with a wave running along the course
varying vec3 tint;
varying float pulse;

void vertex() {
	tint = COLOR.rgb;
	pulse = 0.72 + 0.5 * sin(TIME * 3.2 - MODEL_MATRIX[3].z * 0.14);
}

void fragment() {
	ALBEDO = tint * (0.55 + 0.45 * pulse);
	EMISSION = tint * 0.9 * pulse;
}
