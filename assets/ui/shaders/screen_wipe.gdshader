shader_type canvas_item;

//progress: 0 nothing, 1 everything covered, 2 everything revealed again.
//A slanted band sweeps across: its front covers the screen and its tail uncovers it.
uniform float progress = 2.0;
uniform vec4 lead_color : source_color = vec4(0.992, 0.337, 0.498, 1.0);
uniform vec4 fill_color : source_color = vec4(0.165, 0.129, 0.271, 1.0);

const float SKEW = 0.35;
const float BAND = 0.1;

void fragment() {
	float x = UV.x + UV.y * SKEW;
	float total = 1.0 + SKEW + BAND * 2.0;
	float cover_edge = min(progress, 1.0) * total - BAND;
	float reveal_edge = max(progress - 1.0, 0.0) * total - BAND;
	float covered = step(x, cover_edge) * step(reveal_edge, x);
	float lead = step(cover_edge - BAND, x) + (1.0 - step(reveal_edge + BAND, x));
	vec3 color = mix(fill_color.rgb, lead_color.rgb, clamp(lead, 0.0, 1.0));
	COLOR = vec4(color, covered);
}
