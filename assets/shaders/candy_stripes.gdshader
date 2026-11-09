shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

//Candy stripes for bumpers and pillars: two colours alternate around the shape and can twist along it
uniform vec4 color_a : source_color = vec4(1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.3, 0.5, 1.0);
uniform float stripes = 12.0;
uniform float twist = 0.0;
uniform float glow = 0.0;

void fragment() {
	float x = UV.x * stripes + UV.y * twist;
	float soft = max(fwidth(x) * 1.5, 0.001);
	float band = smoothstep(0.5 - soft, 0.5 + soft, abs(fract(x) - 0.5) * 2.0);
	vec3 art = mix(color_a.rgb, color_b.rgb, band);
	ALBEDO = art;
	EMISSION = art * glow;
	ROUGHNESS = 0.32;
	SPECULAR = 0.65;
}
