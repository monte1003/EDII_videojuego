shader_type spatial;
render_mode diffuse_burley;

//Soft cloud puffs in few draw calls: the instance colour tints each cloud and a little of it glows so the shaded side never turns grey.
//The clouds also drift along X from the clock and wrap around between "left" and "left + width": the custom data of each puff
//holds where its cloud started and how fast it goes, so every puff of a cloud moves together
uniform float lift : hint_range(0.0, 1.0) = 0.4;
uniform float left = -170.0;
uniform float width = 340.0;
varying vec3 tint;

void vertex() {
	tint = COLOR.rgb;
	float start = INSTANCE_CUSTOM.x;
	float moved = mod(start - left + INSTANCE_CUSTOM.y * TIME, width) + left;
	//The basis of a puff is a plain scale, so a shift in the world is the same shift divided by that scale in its own space
	VERTEX.x += (moved - start) / length(MODEL_MATRIX[0].xyz);
}

void fragment() {
	ALBEDO = tint;
	EMISSION = tint * lift;
	ROUGHNESS = 1.0;
}
