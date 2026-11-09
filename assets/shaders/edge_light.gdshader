shader_type spatial;
render_mode unshaded;

//Light strips along the sides of the bridges, all in one draw call: the colour of each one is in its instance, and a wave of light runs
//along the course (it depends on where the strip is) so the whole level seems to pulse in one direction
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
