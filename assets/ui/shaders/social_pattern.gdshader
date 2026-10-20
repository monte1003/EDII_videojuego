shader_type canvas_item;

uniform sampler2D pattern : repeat_enable, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec2 area = vec2(1204.0, 700.0);
uniform float tile_size = 256.0;
uniform vec2 offset = vec2(0.0);
uniform float strength = 0.2;

//La lamina entera se desliza, asi todos los iconos van al mismo ritmo
void fragment() {
	vec2 uv = (UV * area - offset) / tile_size;
	COLOR = vec4(tint, texture(pattern, uv).a * strength);
}
