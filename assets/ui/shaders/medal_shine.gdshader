shader_type canvas_item;

//A band of light that crosses the medal every now and then
uniform float span = 96.0;
uniform float strength = 0.45;
uniform float speed = 0.5;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float sweep = fract(TIME * speed) * 3.0 - 1.0;
	float along = (local.x + local.y * 0.6) / span;
	float band = smoothstep(0.18, 0.0, abs(along - sweep));
	COLOR.rgb += vec3(band * strength);
}
