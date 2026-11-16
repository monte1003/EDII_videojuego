shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

//Letters with volume: the face of each letter in a light colour and its sides in a deep one, so a word reads as a solid piece and not as a
//sticker, from the front and from an angle
uniform vec4 face : source_color = vec4(0.99, 0.98, 1.0, 1.0);
uniform vec4 side : source_color = vec4(0.27, 0.21, 0.64, 1.0);
varying float front;

void vertex() {
	front = abs(NORMAL.z);
}

void fragment() {
	float lit = smoothstep(0.55, 0.85, front);
	ALBEDO = mix(side.rgb, face.rgb, lit);
	ROUGHNESS = mix(0.55, 0.32, lit);
	RIM = 0.25;
	RIM_TINT = 0.6;
}
