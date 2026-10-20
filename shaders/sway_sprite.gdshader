shader_type canvas_item;
// Night Harvest 1.2 — whole-sprite wind sway for trees and bushes.
// The base stays planted; the top bends with the wind. Offsets are rounded to
// whole texels so the pixel art never smears. Every tree gets its own phase
// from its world position, so a forest never moves in lock-step.

uniform float wind = 1.0;
uniform float amount = 1.6;
uniform float uv_top = 0.0;
uniform float uv_bottom = 1.0;
#include "res://shaders/season.gdshaderinc"

varying vec2 world_pos;
varying vec4 v_mod;

void vertex() {
	float h = clamp((uv_bottom - UV.y) / max(0.0001, uv_bottom - uv_top), 0.0, 1.0);
	vec2 origin = MODEL_MATRIX[3].xy;
	float t = TIME * (1.0 + 0.6 * wind) + origin.x * 0.031 + origin.y * 0.017;
	float sway = sin(t * 1.3) * 0.7 + sin(t * 2.9 + 1.7) * 0.3;
	VERTEX.x += round(sway * amount * wind * h * h);
	world_pos = origin;
	v_mod = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = season_color(c.rgb, world_pos, 1.0);
	COLOR = c * v_mod;
}
