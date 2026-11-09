shader_type spatial;
render_mode unshaded;

//Little lights that chase one another along a rim: each one has its own phase in the custom data
uniform float speed = 3.2;
varying vec3 tint;
varying float lit;

void vertex() {
	tint = COLOR.rgb;
	lit = smoothstep(-0.2, 0.4, sin(TIME * speed + INSTANCE_CUSTOM.x));
}

void fragment() {
	ALBEDO = tint * (0.5 + 0.4 * lit);
	EMISSION = tint * lit * 1.8;
}
