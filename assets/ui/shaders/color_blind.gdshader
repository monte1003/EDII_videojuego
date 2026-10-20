shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform int mode = 0;

//Simulates what the eye misses and pushes that error into the channels it still sees
void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	vec3 seen = color;
	if (mode == 1) {
		seen = vec3(dot(color, vec3(0.567, 0.433, 0.0)), dot(color, vec3(0.558, 0.442, 0.0)), dot(color, vec3(0.0, 0.242, 0.758)));
	} else if (mode == 2) {
		seen = vec3(dot(color, vec3(0.625, 0.375, 0.0)), dot(color, vec3(0.7, 0.3, 0.0)), dot(color, vec3(0.0, 0.3, 0.7)));
	} else if (mode == 3) {
		seen = vec3(dot(color, vec3(0.95, 0.05, 0.0)), dot(color, vec3(0.0, 0.433, 0.567)), dot(color, vec3(0.0, 0.475, 0.525)));
	}
	vec3 error = color - seen;
	vec3 fix = vec3(0.0, error.r * 0.7 + error.g, error.r * 0.7 + error.b);
	COLOR = vec4(clamp(color + fix, 0.0, 1.0), 1.0);
}
