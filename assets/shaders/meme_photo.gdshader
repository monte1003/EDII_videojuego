shader_type spatial;
render_mode unshaded, cull_back;

//Meme picture with rounded corners; "extent" is the quad size in meters
uniform sampler2D picture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 extent = vec2(1.0);
uniform float radius = 0.1;

void fragment() {
	vec2 from_middle = abs((UV - 0.5) * extent) - (extent * 0.5 - vec2(radius));
	if (length(max(from_middle, 0.0)) > radius) {
		discard;
	}
	ALBEDO = texture(picture, UV).rgb;
}
