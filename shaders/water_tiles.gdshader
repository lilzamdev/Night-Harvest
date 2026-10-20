shader_type canvas_item;
// Night Harvest 1.2 — living water on the ground tiles.
// Only pixels that match the tileset's water blues are animated, so grass,
// paths and soil are untouched. Waves are snapped to world pixels to stay crisp.

uniform vec3 water_light = vec3(0.0, 0.584, 0.914);
uniform vec3 water_dark = vec3(0.0, 0.427, 0.659);
uniform vec3 crest = vec3(0.56, 0.86, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float wind = 1.0;
#include "res://shaders/season.gdshaderinc"

varying vec2 world_pos;
varying vec4 v_mod;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	v_mod = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float dl = distance(c.rgb, water_light);
	float dd = distance(c.rgb, water_dark);
	bool is_water = min(dl, dd) < 0.07;
	float ice = season.w;
	if (strength > 0.0 && is_water && ice < 0.6) {
		vec2 p = floor(world_pos);
		float t = TIME * (0.8 + 0.4 * wind);
		// Long gentle swells
		float swell = sin(p.x * 0.11 + t * 1.3 + sin(p.y * 0.07 + t * 0.6) * 2.0);
		// Small ripples
		float ripple = sin(p.x * 0.42 - t * 2.1 + p.y * 0.17) * sin(p.y * 0.55 + t * 1.4);
		float w = swell * 0.55 + ripple * 0.45;
		if (dl < dd) {
			if (w > 0.78) {
				c.rgb = mix(c.rgb, crest, 0.7 * strength);
			} else if (w < -0.80) {
				c.rgb = mix(c.rgb, water_dark, 0.5 * strength);
			}
		} else if (w > 0.9) {
			c.rgb = mix(c.rgb, water_light, 0.6 * strength);
		}
		// Sun glints
		vec2 cell = floor(p / 3.0);
		float h = hash(cell);
		vec2 sub = mod(p, 3.0);
		float centre = step(0.5, sub.x) * step(sub.x, 1.5) * step(0.5, sub.y) * step(sub.y, 1.5);
		float glint = step(0.97, h) * step(0.9, sin(t * 2.6 + h * 60.0)) * centre;
		c.rgb = mix(c.rgb, vec3(1.0), glint * 0.85 * strength);
	}
	if (is_water) {
		c.rgb = season_water(c.rgb);
	} else {
		c.rgb = season_color(c.rgb, world_pos, 0.0);
	}
	// COLOR already holds texture * modulate; rebuild it from our own sample.
	COLOR = c * v_mod;
}
