shader_type spatial;
render_mode diffuse_burley;

//Cloud puffs tinted per instance that drift along X and wrap around
uniform float lift : hint_range(0.0, 1.0) = 0.4;
uniform float left = -170.0;
uniform float width = 340.0;
varying vec3 tint;

void vertex() {
	tint = COLOR.rgb;
	float start = INSTANCE_CUSTOM.x;
	float moved = mod(start - left + INSTANCE_CUSTOM.y * TIME, width) + left;
	//Undo the puff scale to move it in world space
	VERTEX.x += (moved - start) / length(MODEL_MATRIX[0].xyz);
}

void fragment() {
	ALBEDO = tint;
	EMISSION = tint * lift;
	ROUGHNESS = 1.0;
}
