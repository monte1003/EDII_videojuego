shader_type canvas_item;

//Cartoon iris that closes to hide a camera jump and opens again
uniform float radius = 1.3;
uniform float aspect = 1.78;
uniform vec4 night : source_color = vec4(0.06, 0.05, 0.14, 1.0);
uniform vec4 ring : source_color = vec4(1.0, 0.36, 0.54, 1.0);

void fragment() {
	vec2 offset = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	float away = length(offset);
	float outside = smoothstep(radius - 0.004, radius + 0.004, away);
	float edge = smoothstep(radius - 0.018, radius - 0.008, away) * (1.0 - outside);
	COLOR = mix(vec4(ring.rgb, edge), night, outside);
}
