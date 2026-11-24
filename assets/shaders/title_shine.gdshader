shader_type canvas_item;

//A band of light that crosses the logo on a slant, only over its letters (not over its soft glow)
uniform float sweep = -1.0;
uniform float width = 0.09;
uniform float strength = 0.7;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float band = 1.0 - smoothstep(0.0, width, abs(UV.x - UV.y * 0.45 - sweep));
	float letters = smoothstep(0.6, 0.95, base.a);
	COLOR = vec4(mix(base.rgb, vec3(1.0), band * strength * letters), base.a);
}
