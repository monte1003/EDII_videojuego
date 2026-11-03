shader_type spatial;
render_mode unshaded, fog_disabled;

// Face of a SocialDrop tile: the app icon with its rounded corners over a pale base, so the tiles read as a grid of apps.
// "tint" turns the whole face red as a warning
uniform sampler2D icon : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 base_color : source_color = vec4(0.93, 0.91, 1.0, 1.0);
uniform float saturation : hint_range(0.0, 1.0) = 0.92;
uniform float brightness : hint_range(0.0, 1.5) = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
// The way the camera turns around the platform: the icon turns with it, so it always reads upright
uniform float turn = 0.0;

void fragment() {
	float c = cos(turn);
	float s = sin(turn);
	// Shrunk a little when turned so its corners never leave the face
	vec2 centered = (UV - vec2(0.5)) * (abs(c) + abs(s));
	vec2 spun = vec2(c * centered.x - s * centered.y, s * centered.x + c * centered.y) + vec2(0.5);
	vec4 art = texture(icon, spun);
	float gray = dot(art.rgb, vec3(0.299, 0.587, 0.114));
	vec3 painted = mix(vec3(gray), art.rgb, saturation) * brightness;
	ALBEDO = mix(base_color.rgb, painted, art.a) * tint.rgb;
}
