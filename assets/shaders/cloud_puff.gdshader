shader_type spatial;
render_mode diffuse_burley;

//Soft cloud puffs in one draw call: the instance colour tints each cloud and a little of it glows so the shaded side never turns grey
uniform float lift : hint_range(0.0, 1.0) = 0.4;
varying vec3 tint;

void vertex() {
	tint = COLOR.rgb;
}

void fragment() {
	ALBEDO = tint;
	EMISSION = tint * lift;
	ROUGHNESS = 1.0;
}
