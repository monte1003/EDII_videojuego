shader_type spatial;
render_mode unshaded, fog_disabled;

// The glass of a giant screen of SocialDrop: a deep gradient with slow slanted bands in the colour of the screen, fine scanlines, a vignette
// and a glowing border, so the numbers and icons that are drawn in front of it stand out
uniform vec4 accent : source_color = vec4(1.0, 0.36, 0.54, 1.0);

void fragment() {
	vec2 p = UV;
	vec3 col = mix(vec3(0.13, 0.09, 0.32), vec3(0.04, 0.03, 0.15), p.y);
	float bands = 0.5 + 0.5 * sin((p.x * 1.6 + p.y * 1.2) * 7.0 - TIME * 0.8);
	col += accent.rgb * 0.08 * bands;
	col *= 0.94 + 0.06 * sin(p.y * 260.0);
	float vignette = smoothstep(0.95, 0.3, length(p - 0.5) * 1.35);
	col *= mix(0.65, 1.0, vignette);
	vec2 edge = min(p, 1.0 - p);
	float rim = smoothstep(0.05, 0.0, min(edge.x, edge.y));
	col += accent.rgb * rim * 0.7;
	ALBEDO = col;
}
