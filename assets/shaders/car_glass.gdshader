shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx;

//A toy car whose windows are painted dark on its texture: here those pixels turn into glass, so the people inside show through.
//Only the dark pixels in the band of the windows count, so the tyres and the lights stay as they are
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
//The roof can have its own colour: it starts at this share of the height of the car
uniform vec4 roof_tint : source_color = vec4(1.0);
uniform float roof_start : hint_range(0.0, 1.0) = 0.935;
uniform vec3 glass_color : source_color = vec3(0.55, 0.7, 0.95);
uniform float glass_alpha : hint_range(0.0, 1.0) = 0.16;
uniform float feet_y = 0.0;
uniform float body_height = 1.0;
//Where the windows are as a share of the height of the car, and how dark a pixel must be to be glass
uniform float glass_low : hint_range(0.0, 1.0) = 0.45;
uniform float glass_high : hint_range(0.0, 1.0) = 0.95;
uniform float glass_darkness : hint_range(0.0, 1.0) = 0.45;

varying float height_share;

void vertex() {
	height_share = (VERTEX.y - feet_y) / max(body_height, 0.001);
}

void fragment() {
	vec3 art = texture(albedo_tex, UV).rgb;
	float dark = 1.0 - smoothstep(glass_darkness - 0.06, glass_darkness + 0.06, dot(art, vec3(0.299, 0.587, 0.114)));
	float band = smoothstep(glass_low - 0.02, glass_low + 0.02, height_share) * (1.0 - smoothstep(glass_high - 0.02, glass_high + 0.02, height_share));
	float glass = dark * band;
	float roof = smoothstep(roof_start - 0.01, roof_start + 0.01, height_share);
	vec3 body = art * mix(tint.rgb, roof_tint.rgb, roof);
	ALBEDO = mix(body, glass_color, glass);
	ALPHA = mix(1.0, glass_alpha, glass);
	ROUGHNESS = mix(0.7, 0.15, glass);
	SPECULAR = 0.4;
}
