shader_type canvas_item;
render_mode blend_add;

uniform float frenzy_amount : hint_range(0.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 2.0) = 0.72;

void fragment() {
	vec2 p = (UV - vec2(0.5, 0.54)) * vec2(2.0, 2.2);

	// Layered organic flame flicker under the cauldron belly
	float wave_a = sin(TIME * 4.8 + UV.x * 11.0);
	float wave_b = sin(TIME * 7.6 - UV.x * 17.0 + 1.3);
	float flicker = 0.88 + 0.12 * sin(TIME * 6.2 + wave_a * 0.7);
	vec2 wobble = vec2(wave_a * 0.045, (wave_a * 0.055 + wave_b * 0.035));

	vec2 p_outer = p + wobble * 0.65;
	vec2 p_core = p + wobble * 1.15;

	float gauss_outer = exp(-dot(p_outer, p_outer) * 2.8);
	float gauss_core = exp(-dot(p_core, p_core) * 6.5);

	// Smooth rect-edge fade so glow reaches strictly 0 before ColorRect bounds
	float edge_x = smoothstep(0.0, 0.16, UV.x) * smoothstep(1.0, 0.84, UV.x);
	float edge_y = smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.82, UV.y);
	float edge_mask = edge_x * edge_y;

	vec3 hearth_outer = vec3(0.95, 0.32, 0.08);
	vec3 hearth_core = vec3(1.0, 0.78, 0.28);
	vec3 frenzy_outer = vec3(0.95, 0.14, 0.48);
	vec3 frenzy_core = vec3(1.0, 0.55, 0.82);

	float fmix = clamp(frenzy_amount, 0.0, 1.0);
	vec3 col_outer = mix(hearth_outer, frenzy_outer, fmix);
	vec3 col_core = mix(hearth_core, frenzy_core, fmix);

	vec3 rgb = (col_outer * gauss_outer * 0.75 + col_core * gauss_core * 0.95) * intensity * flicker * edge_mask;
	float alpha = clamp((gauss_outer * 0.65 + gauss_core * 0.75) * intensity * flicker * edge_mask, 0.0, 1.0);

	COLOR = vec4(rgb, alpha) * COLOR;
}
