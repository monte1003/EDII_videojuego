shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

//Paints a plain white figure in three bands by height: legs, body and head. The model files stay as they are
uniform vec3 lower_color : source_color = vec3(0.24, 0.23, 0.42);
uniform vec3 body_color : source_color = vec3(1.0, 0.44, 0.49);
uniform vec3 head_color : source_color = vec3(1.0, 0.82, 0.7);
uniform float feet_y = 0.0;
uniform float body_height = 1.8;
//Where the legs end and where the head starts, as a share of the height
uniform float lower_end : hint_range(0.0, 1.0) = 0.47;
uniform float head_start : hint_range(0.0, 1.0) = 0.84;
//A little of the tint of the sky from above, so the figure sits in the scene
uniform float top_light : hint_range(0.0, 1.0) = 0.12;

varying float height_share;
varying vec3 world_normal;

void vertex() {
	height_share = (VERTEX.y - feet_y) / max(body_height, 0.001);
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float to_body = smoothstep(lower_end - 0.012, lower_end + 0.012, height_share);
	float to_head = smoothstep(head_start - 0.012, head_start + 0.012, height_share);
	vec3 color = mix(lower_color, body_color, to_body);
	color = mix(color, head_color, to_head);
	color += vec3(1.0) * top_light * clamp(world_normal.y, 0.0, 1.0);
	ALBEDO = color;
	ROUGHNESS = 0.72;
	SPECULAR = 0.25;
}
