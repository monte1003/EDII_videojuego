shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

//Candy stripes for the bumpers of many islands joined in one mesh: the first colour is the same for all, the second one is the colour
//of each vertex and the stripes are counted in the UV, so one material serves every island
uniform vec4 color_a : source_color = vec4(0.99, 0.98, 1.0, 1.0);
uniform float glow = 0.25;

vec3 to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void fragment() {
	float x = UV.x;
	float soft = max(fwidth(x) * 1.5, 0.001);
	float band = smoothstep(0.5 - soft, 0.5 + soft, abs(fract(x) - 0.5) * 2.0);
	vec3 art = mix(color_a.rgb, to_linear(COLOR.rgb), band);
	ALBEDO = art;
	EMISSION = art * glow;
	ROUGHNESS = 0.32;
	SPECULAR = 0.65;
}
