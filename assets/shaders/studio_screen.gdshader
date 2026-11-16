shader_type spatial;
render_mode unshaded;

//The big screen of a set: a soft gradient between two colours with wide bands that drift across it and a lighter glow in the middle,
//inside a thin bright border. It needs no texture
uniform vec4 color_a : source_color = vec4(1.0, 0.45, 0.55, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.76, 0.42, 1.0);
uniform vec4 border : source_color = vec4(1.0, 0.97, 0.92, 1.0);
uniform float speed = 0.12;
uniform float bands = 3.0;

void fragment() {
	vec2 uv = UV;
	float wave = 0.5 + 0.5 * sin((uv.x * 1.3 + uv.y * 0.7 - TIME * speed) * bands * 6.2832);
	vec3 base = mix(color_a.rgb, color_b.rgb, smoothstep(0.0, 1.0, uv.x * 0.7 + uv.y * 0.3));
	base = mix(base, base * 1.18, wave * 0.35);
	float glow = 1.0 - smoothstep(0.0, 0.75, length(uv - vec2(0.5)));
	base += vec3(0.12) * glow;
	float edge = min(min(uv.x, uv.y), min(1.0 - uv.x, 1.0 - uv.y));
	ALBEDO = mix(border.rgb, base, smoothstep(0.012, 0.022, edge));
}
