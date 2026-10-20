shader_type canvas_item;
// Night Harvest 1.2 — screen overlay for drifting fog banks and cloud shadows.
// The noise is sampled in world space (camera position + screen position), so
// fog and shadows stay glued to the ground while the camera moves.

uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec2 cam_pos = vec2(0.0);
uniform vec2 view_size = vec2(427.0, 240.0);
uniform vec2 drift = vec2(0.0);
uniform float fog_amount : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fog_color : source_color = vec4(0.78, 0.82, 0.86, 1.0);

void fragment() {
	vec2 world = cam_pos + (SCREEN_UV - 0.5) * view_size;
	// Cloud shadows: large, slow blobs
	float n1 = texture(noise, (world + drift * 0.6) / 900.0).r;
	float shadow = smoothstep(0.52, 0.72, n1) * cloud_amount * 0.32;
	// Fog: two layers drifting at different speeds
	float f1 = texture(noise, (world + drift) / 520.0).r;
	float f2 = texture(noise, (world * 1.7 - drift * 1.4) / 420.0).r;
	float fog = clamp((f1 * 0.65 + f2 * 0.55) - 0.25, 0.0, 1.0) * fog_amount;
	vec3 col = mix(vec3(0.02, 0.03, 0.08), fog_color.rgb, fog / max(fog + shadow, 0.0001));
	COLOR = vec4(col, clamp(shadow + fog * 0.75, 0.0, 0.85));
}
