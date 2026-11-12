shader_type spatial;
render_mode cull_disabled, diffuse_burley;

//A fan drawn like the picture of an account with no photo: a rounded colour tile with a pale head and shoulders.
//Each hops on its own beat, "excitement" makes the whole crowd jump higher and a wave of fans stands up as its crest goes by
uniform float excitement : hint_range(0.0, 3.0) = 1.0;
uniform float hop_height = 0.22;
uniform float silhouette_light : hint_range(0.0, 1.0) = 0.55;
uniform float wave_front = -100000.0;
uniform float wave_lift = 0.0;
uniform float wave_width = 11.0;
varying vec3 tint;
varying float seed;

void vertex() {
	tint = COLOR.rgb;
	vec3 base = MODEL_MATRIX[3].xyz;
	float phase = base.x * 3.7 + base.z * 5.3 + base.y * 1.9;
	seed = fract(phase * 0.173);
	float beat = 3.2 + fract(phase * 0.37) * 2.2;
	float wave = sin(TIME * beat + phase);
	float hop = max(wave, 0.0);
	float height_share = 1.0 - UV.y;
	float crest = exp(-pow((base.z - wave_front) / wave_width, 2.0));
	VERTEX.y += hop * hop_height * excitement + crest * wave_lift;
	VERTEX.x += height_share * wave * 0.07 * excitement + height_share * crest * wave_lift * 0.1;
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	p.y = -p.y;
	//The tile: a square with big rounded corners
	vec2 q = abs(p) - vec2(0.5 - 0.17);
	float tile = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 0.17;
	//The head and the shoulders: a circle over a wide ellipse, a little different in every fan
	float head_radius = 0.17 + seed * 0.04;
	float head = length(p - vec2(0.0, 0.1)) - head_radius;
	vec2 s = (p - vec2(0.0, -0.36)) / vec2(0.36 + seed * 0.05, 0.3);
	float shoulders = (length(s) - 1.0) * 0.3;
	float body = min(head, shoulders);
	float soft = max(fwidth(tile), 0.002);
	float inside = 1.0 - smoothstep(-soft, soft, tile);
	float figure = 1.0 - smoothstep(-soft, soft, body);
	ALBEDO = mix(tint, mix(tint, vec3(1.0), silhouette_light), figure);
	ROUGHNESS = 0.9;
	ALPHA = inside;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
