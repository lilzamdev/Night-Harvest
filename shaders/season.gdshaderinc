// Night Harvest 1.4 - the four seasons, shared by every world shader.
// season = weights of (spring, summer, fall, winter); the Seasons node blends them.
// Only leaf/grass-green pixels change, so trunks, paths, roofs and water stay put.
uniform vec4 season = vec4(1.0, 0.0, 0.0, 0.0);
uniform float season_on = 1.0;     // 0 = never changes (cactus)
uniform float evergreen = 0.0;     // 1 = stays green in fall (pines), still gets snow

float s_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

bool s_green(vec3 c) {
	return c.g > c.r * 1.04 && c.g > c.b * 1.08 && c.g > 0.16;
}

// foliage: 0 = ground grass, 1 = leaves
vec3 season_color(vec3 c, vec2 wp, float foliage) {
	if (season_on < 0.5 || season.x > 0.999 || !s_green(c)) {
		return c;
	}
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 summer = clamp(c * vec3(1.07, 1.01, 0.78), 0.0, 1.0);
	// Fall: each tree (or patch of grass) picks its own amber, gold or red
	float h = s_hash(floor(wp / mix(40.0, 18.0, foliage)));
	vec3 tone = mix(vec3(0.96, 0.50, 0.13), vec3(0.98, 0.74, 0.20), h);
	tone = h > 0.8 ? vec3(0.86, 0.27, 0.13) : tone;
	vec3 fall_leaf = tone * (0.30 + lum * 1.35);
	vec3 fall_grass = mix(c, vec3(0.80, 0.66, 0.30) * (0.42 + lum * 1.05), 0.72);
	vec3 fall = mix(fall_grass, fall_leaf, foliage * (1.0 - evergreen));
	fall = mix(fall, c * vec3(0.92, 0.96, 0.9), foliage * evergreen);
	// Winter: snow on the ground, frosted dark canopies with snowy tops
	vec3 snow_ground = mix(vec3(0.76, 0.83, 0.94), vec3(0.97, 0.98, 1.0), smoothstep(0.30, 0.62, lum));
	vec3 frost = vec3(0.20, 0.33, 0.33) * (0.55 + lum);
	vec3 snow_leaf = mix(frost, vec3(0.94, 0.97, 1.0), smoothstep(0.46, 0.66, lum));
	vec3 winter = mix(snow_ground, snow_leaf, foliage);
	return c * season.x + summer * season.y + fall * season.z + winter * season.w;
}

// Lakes freeze over a little in winter
vec3 season_water(vec3 c) {
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 ice = mix(vec3(0.62, 0.80, 0.92), vec3(0.86, 0.94, 0.99), smoothstep(0.35, 0.7, lum + 0.2));
	return mix(c, ice, season.w * 0.82);
}
