shader_type spatial;
render_mode unshaded, fog_disabled;

// Face of a SocialDrop card: the app icon over a pale base, cut as a rounded square with a bevelled border, so the cards read as a grid of apps.
// "tint" turns the whole face red as a warning, "edge_glow" lights the border in "edge_color" (the card to stand on) and a soft shine
// sweeps over the glossy face now and then. The face with the question mark also gets a faint pattern of sparkles
uniform sampler2D icon : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 base_color : source_color = vec4(0.93, 0.91, 1.0, 1.0);
uniform float saturation : hint_range(0.0, 1.0) = 0.92;
uniform float brightness : hint_range(0.0, 1.5) = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.86, 0.35, 1.0);
uniform float edge_glow : hint_range(0.0, 2.0) = 0.0;
uniform float shine : hint_range(0.0, 1.0) = 0.18;
uniform float sparkle : hint_range(0.0, 1.0) = 0.0;
uniform float corner = 0.1;

float rounded(vec2 uv) {
	vec2 q = abs(uv - 0.5) - (0.5 - corner);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
}

void fragment() {
	float d = rounded(UV);
	ALPHA = 1.0 - smoothstep(-0.004, 0.004, d);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec4 art = texture(icon, UV);
	float gray = dot(art.rgb, vec3(0.299, 0.587, 0.114));
	vec3 painted = mix(vec3(gray), art.rgb, saturation) * brightness;
	vec3 color = mix(base_color.rgb, painted, art.a) * tint.rgb;
	//Faint sparkles on the face that hides the icon: small crosses on a slanted grid
	vec2 grid = fract(UV * 6.0 + vec2(UV.y * 2.0, 0.0)) - 0.5;
	float cross_shape = max(0.0, 0.07 - min(abs(grid.x), abs(grid.y))) * smoothstep(0.32, 0.0, length(grid));
	color += vec3(1.0) * cross_shape * 3.2 * sparkle;
	//The border: a bright thin line inside the edge that is brighter when the card must be found
	float border = smoothstep(-0.075, -0.045, d) * (1.0 - smoothstep(-0.02, 0.0, d));
	color = mix(color, mix(vec3(1.0), edge_color.rgb, clamp(edge_glow, 0.0, 1.0)), border * (0.35 + 0.65 * clamp(edge_glow, 0.0, 1.0)));
	color += edge_color.rgb * smoothstep(-0.22, 0.0, d) * edge_glow * 0.25;
	//A slanted shine that crosses the face every few seconds
	float sweep = fract(TIME * 0.22 + UV.x * 0.15) ;
	float band = smoothstep(0.07, 0.0, abs((UV.x + UV.y) * 0.5 - (sweep * 1.6 - 0.3)));
	color += vec3(1.0) * band * shine;
	ALBEDO = color;
}
