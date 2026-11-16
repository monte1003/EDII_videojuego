shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

//Chunky round letters like the title of the game: the face goes from a light colour at the top to a deeper one at the bottom, the round
//sides turn darker, and a glossy coat with a soft rim makes them read as candy. "glow" lights them a little on a dark stage
uniform vec4 top : source_color = vec4(0.65, 0.93, 1.0, 1.0);
uniform vec4 bottom : source_color = vec4(0.23, 0.65, 0.94, 1.0);
uniform vec4 side : source_color = vec4(0.18, 0.5, 0.88, 1.0);
uniform float span = 0.8;
uniform float glow = 0.0;
varying float front;
varying float height;

void vertex() {
	front = NORMAL.z;
	height = clamp(VERTEX.y / span + 0.5, 0.0, 1.0);
}

void fragment() {
	float face = smoothstep(0.35, 0.9, front);
	vec3 base = mix(bottom.rgb, top.rgb, smoothstep(0.0, 1.0, height));
	vec3 colour = mix(side.rgb, base, face);
	ALBEDO = colour;
	ROUGHNESS = mix(0.4, 0.22, face);
	SPECULAR = 0.6;
	CLEARCOAT = 0.7;
	CLEARCOAT_ROUGHNESS = 0.18;
	RIM = 0.35;
	RIM_TINT = 0.7;
	EMISSION = colour * glow;
}
