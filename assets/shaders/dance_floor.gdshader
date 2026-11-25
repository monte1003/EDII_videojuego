shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

//Dance floor whose tiles light up with the beat, no script needed
uniform vec4 color_a : source_color = vec4(1.0, 0.48, 0.52, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.78, 0.34, 1.0);
uniform vec4 color_c : source_color = vec4(0.25, 0.75, 0.68, 1.0);
uniform vec4 color_d : source_color = vec4(0.72, 0.52, 1.0, 1.0);
uniform vec4 grout : source_color = vec4(1.0, 0.95, 0.88, 1.0);
uniform float tile = 1.25;
uniform float beats = 2.2;

varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = floor(world.xz / tile);
	vec2 inside = fract(world.xz / tile);
	float beat = floor(TIME * beats);
	float pick = hash(cell + vec2(beat * 0.37, beat * 0.11));
	vec3 tint = pick < 0.25 ? color_a.rgb : (pick < 0.5 ? color_b.rgb : (pick < 0.75 ? color_c.rgb : color_d.rgb));
	float on = step(0.42, hash(cell * 1.7 + vec2(beat)));
	float rim = min(min(inside.x, inside.y), min(1.0 - inside.x, 1.0 - inside.y));
	float face = smoothstep(0.035, 0.07, rim);
	vec3 dark = tint * 0.38;
	vec3 lit = mix(dark, tint, on);
	ALBEDO = mix(grout.rgb, lit, face);
	EMISSION = tint * on * face * 1.1;
	ROUGHNESS = 0.12;
	SPECULAR = 0.8;
}
