shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

//A phone in one piece: its back has the colour of the case and the face that looks toward +Z is the lit screen.
//The colours are per instance, so every phone of the street shares this one material
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
