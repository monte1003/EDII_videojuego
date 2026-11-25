shader_type spatial;
render_mode unshaded, fog_disabled;

//Glowing frame under a SocialDrop card; "energy" above 1 blooms
uniform vec4 glow_color : source_color = vec4(1.0, 0.36, 0.54, 1.0);
uniform float energy = 1.0;
uniform float corner = 0.095;

float rounded(vec2 uv) {
	vec2 q = abs(uv - 0.5) - (0.5 - corner);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
}

void fragment() {
	ALPHA = 1.0 - smoothstep(-0.004, 0.004, rounded(UV));
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = glow_color.rgb * energy;
}
