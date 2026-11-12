shader_type spatial;
render_mode unshaded;

//A glow in the colour of each vertex, for the rings of light under the islands that are joined in one mesh
uniform float energy = 1.9;

vec3 to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void fragment() {
	ALBEDO = to_linear(COLOR.rgb) * energy;
}
