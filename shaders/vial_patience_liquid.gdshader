shader_type canvas_item;

uniform float fill_ratio : hint_range(0.0, 1.0) = 1.0;
uniform vec4 liquid_color : source_color = vec4(0.56, 0.94, 0.18, 1.0);
uniform float mask_left : hint_range(0.0, 1.0) = 0.0772;
uniform float mask_right : hint_range(0.0, 1.0) = 0.9623;
uniform float mask_top : hint_range(0.0, 1.0) = 0.05;
uniform float mask_bottom : hint_range(0.0, 1.0) = 0.9667;
uniform float urgent_amount : hint_range(0.0, 1.0) = 0.0;
uniform float paused_amount : hint_range(0.0, 1.0) = 0.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	float mask_a = texture(TEXTURE, UV).a;
	if (mask_a <= 0.01) {
		COLOR = vec4(0.0);
	} else {
		float span_x = max(0.001, mask_right - mask_left);
		float span_y = max(0.001, mask_bottom - mask_top);
		float x_norm = clamp((UV.x - mask_left) / span_x, 0.0, 1.0);
		float y_norm = clamp((UV.y - mask_top) / span_y, 0.0, 1.0);

		float speed_scale = mix(1.0, 0.25, paused_amount) + urgent_amount * 0.65;
		float t = TIME * speed_scale;

		// Subtle wavy vertical meniscus along the horizontal tube, attenuated at 0% and 100%
		float wave_env = smoothstep(0.0, 0.03, fill_ratio) * (1.0 - smoothstep(0.97, 1.0, fill_ratio));
		float wave_a = sin(y_norm * 10.0 + t * 4.2) * (0.004 + urgent_amount * 0.005);
		float wave_b = sin(y_norm * 19.0 - t * 6.5 + 1.4) * 0.002;
		float surface_x = clamp(fill_ratio + (wave_a + wave_b) * wave_env, 0.0, 1.0);

		float in_liquid = 1.0 - smoothstep(surface_x - 0.006, surface_x + 0.006, x_norm);

		// Dark translucent glass cavity tint for crisp contrast over bright skies
		vec3 empty_rgb = mix(vec3(0.06, 0.04, 0.11), liquid_color.rgb, 0.10);
		float empty_a = 0.44;

		// Cylindrical vertical depth shading across tube height
		float radial_y = abs(y_norm - 0.5) * 2.0;
		float cyl_shade = mix(1.16, 0.68, smoothstep(0.18, 0.96, radial_y));
		float horiz_grad = mix(0.84, 1.06, x_norm);
		vec3 base_liq = liquid_color.rgb * cyl_shade * horiz_grad;

		// Subtle drifting micro-bubbles
		float bub_grid_1 = sin(y_norm * 18.0 + 1.2) * sin((x_norm - t * 0.16) * 48.0);
		float bub_grid_2 = sin(y_norm * 29.0 - 2.1) * sin((x_norm - t * 0.26) * 74.0 + 1.8);
		float bubbles = smoothstep(0.86, 0.99, bub_grid_1) * 0.24 + smoothstep(0.90, 0.995, bub_grid_2) * 0.28;
		base_liq += vec3(0.42, 0.46, 0.50) * bubbles * (1.0 - paused_amount * 0.6);

		// Crisp luminous meniscus highlight at the draining liquid edge
		float meniscus_band = exp(-pow((x_norm - surface_x) / 0.012, 2.0)) * smoothstep(0.01, 0.04, fill_ratio);
		vec3 meniscus_col = mix(liquid_color.rgb, vec3(1.0), 0.72);
		base_liq = mix(base_liq, meniscus_col, clamp(meniscus_band * 0.78, 0.0, 0.95));

		// Soft urgent pulse shimmer when patience runs low
		float urgent_pulse = (0.5 + 0.5 * sin(TIME * 7.0)) * urgent_amount;
		base_liq += vec3(0.32, 0.08, 0.10) * urgent_pulse * 0.45;

		float liq_a = 0.93;
		vec3 final_rgb = mix(empty_rgb, base_liq, in_liquid);
		float final_a = mix(empty_a, liq_a, in_liquid) * mask_a;
		COLOR = vec4(final_rgb, final_a) * v_modulate;
	}
}
