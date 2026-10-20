shader_type canvas_item;
// Night Harvest 1.4 - season colours for decoration layers (bushes, grass tufts, hedges).
#include "res://shaders/season.gdshaderinc"
uniform float foliage = 1.0;

varying vec2 world_pos;
varying vec4 v_mod;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	v_mod = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = season_color(c.rgb, world_pos, foliage);
	COLOR = c * v_mod;
}
