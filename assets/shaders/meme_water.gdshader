shader_type spatial;
render_mode diffuse_burley;

//Cartoon water with wandering lines of light, laid in world space
uniform vec4 deep : source_color = vec4(0.22, 0.5, 0.98, 1.0);
uniform vec4 shallow : source_color = vec4(0.42, 0.78, 1.0, 1.0);
uniform vec4 shine : source_color = vec4(0.9, 0.98, 1.0, 1.0);
uniform float scale = 0.6;
uniform float speed = 0.4;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float wander(vec2 at, float time) {
	return sin(at.x + sin(at.y * 0.8 + time) * 1.3) * sin(at.y * 1.1 - sin(at.x * 0.7 - time * 0.8) * 1.2);
}

void fragment() {
	vec2 at = world.xz * scale;
	float time = TIME * speed;
	float slow = wander(at, time);
	float fast = wander(at * 1.7 + vec2(3.1, 1.7), -time * 1.3);
	float lines = 1.0 - smoothstep(0.0, 0.09, abs(slow * 0.6 + fast * 0.4));
	vec3 water = mix(deep.rgb, shallow.rgb, 0.5 + 0.5 * slow);
	ALBEDO = mix(water, shine.rgb, lines * 0.75);
	EMISSION = ALBEDO * 0.3;
	ROUGHNESS = 0.2;
	SPECULAR = 0.6;
}
