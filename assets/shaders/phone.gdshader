shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

//Phone with a coloured case and a lit screen toward +Z, colours per instance
instance uniform vec3 case_color : source_color = vec3(0.17, 0.15, 0.28);
instance uniform vec3 screen_color : source_color = vec3(0.75, 0.9, 1.0);

varying float on_screen;

void vertex() {
	on_screen = step(0.9, NORMAL.z);
}

void fragment() {
	ALBEDO = mix(case_color, vec3(0.02), on_screen);
	EMISSION = screen_color * 1.6 * on_screen;
	ROUGHNESS = 0.45;
}
