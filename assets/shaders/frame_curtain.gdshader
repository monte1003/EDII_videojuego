shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

//A low wall of light that rises from the edges of the frame and fades upward, so the frame shows from afar and over the props of
//a set. Dashes run along it like the edge of a viewfinder; it turns gold while the frame blinks before the shot. Up close it fades
//away, so it never hangs between the camera and its player, and so does a side seen edge on
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform float blink = 0.0;
uniform float dashes = 28.0;

void fragment() {
	float fade = pow(1.0 - UV.y, 1.7);
	float dash = 0.7 + 0.3 * step(0.5, fract(UV.x * dashes - TIME * 0.6));
	ALBEDO = mix(color.rgb, hot.rgb, blink);
	float far = smoothstep(8.0, 15.0, length(VERTEX));
	float facing = smoothstep(0.2, 0.55, abs(dot(normalize(NORMAL), VIEW)));
	ALPHA = fade * dash * (0.34 + 0.35 * blink) * far * facing;
}
