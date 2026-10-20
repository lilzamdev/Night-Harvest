shader_type canvas_item;
// Night Harvest 1.2 — wind rustle for tree canopies drawn from tile atlases.
// Leaf-coloured pixels shift by up to one texel in waves that travel with the
// wind; other pixels (trunks, roofs, signs) never move.

uniform float wind = 1.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
#include "res://shaders/season.gdshaderinc"

varying vec2 world_pos;
varying vec4 v_mod;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	v_mod = COLOR;
}

bool is_leaf(vec4 c) {
	return c.a > 0.5 && c.g > c.r * 1.08 && c.g > c.b * 1.15 && c.g > 0.25;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (strength > 0.0 && is_leaf(c)) {
		vec2 p = floor(world_pos);
		float t = TIME * (0.9 + 0.8 * wind);
		float gust = sin(p.x * 0.045 + p.y * 0.02 - t * 1.2) * 0.5 + 0.5;
		float wave = sin(p.y * 0.35 + p.x * 0.08 + t * 2.4);
		float shift = (wave * gust * wind > 0.55) ? 1.0 : 0.0;
		vec4 s = texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x * shift, 0.0));
		if (is_leaf(s)) {
			c = s;
		}
		// Sun-lit flutter on the brightest leaves
		float lit = step(0.9, wave * gust) * 0.08 * strength;
		c.rgb += vec3(lit, lit * 1.2, lit * 0.4);
	}
	c.rgb = season_color(c.rgb, world_pos, 1.0);
	// COLOR already holds texture * modulate; rebuild it from our own sample.
	COLOR = c * v_mod;
}
