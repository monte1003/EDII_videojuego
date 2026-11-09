shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

//The colours of a hero's texture in another tone: only the coloured pixels turn, so the white mask, the black boots and the greys stay
uniform sampler2D albedo_tex : source_color, filter_linear;
//Turns of the colour wheel (0 to 1), and how much colour and light the coloured parts keep
uniform float hue_shift = 0.0;
uniform float saturation = 1.0;
uniform float value = 1.0;

vec3 to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 hsv = to_hsv(texture(albedo_tex, UV).rgb);
	float coloured = smoothstep(0.12, 0.3, hsv.y) * smoothstep(0.1, 0.25, hsv.z);
	hsv.x = fract(hsv.x + hue_shift * coloured);
	hsv.y = clamp(hsv.y * mix(1.0, saturation, coloured), 0.0, 1.0);
	hsv.z = clamp(hsv.z * mix(1.0, value, coloured), 0.0, 1.0);
	ALBEDO = to_rgb(hsv);
	ROUGHNESS = 0.62;
	SPECULAR = 0.3;
}
