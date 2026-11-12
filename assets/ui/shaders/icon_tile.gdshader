shader_type spatial;
render_mode unshaded, fog_disabled;

// Face of a SocialDrop tile: the icon with its own colours, only slightly desaturated so the
// board does not shout over the background. "tint" turns it red as a warning
uniform sampler2D icon : source_color, filter_linear_mipmap_anisotropic;
uniform float saturation : hint_range(0.0, 1.0) = 0.8;
uniform float brightness : hint_range(0.0, 1.5) = 0.95;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec3 color = texture(icon, UV).rgb;
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(gray), color, saturation) * brightness * tint.rgb;
}
