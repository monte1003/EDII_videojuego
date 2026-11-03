shader_type canvas_item;

//A soft colour that grows from the edges of the screen: danger ahead or the flash of a hit
uniform vec4 glow_color : source_color = vec4(0.88, 0.29, 0.42, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;
//Distance from the centre where the glow starts
uniform float reach : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 offset = UV - vec2(0.5);
	offset.x *= 1.1;
	float edge = smoothstep(reach, 1.0, length(offset) * 1.55);
	COLOR = vec4(glow_color.rgb, edge * amount * glow_color.a);
}
