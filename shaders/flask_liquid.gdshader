shader_type canvas_item;

uniform float fill_ratio : hint_range(0.0, 1.0) = 0.0;
uniform vec4 liquid_color : source_color = vec4(0.98, 0.28, 0.34, 1.0);
uniform float mask_top : hint_range(0.0, 1.0) = 0.1646;
uniform float mask_bottom : hint_range(0.0, 1.0) = 0.9829;
uniform float slosh_amp : hint_range(0.0, 1.5) = 0.0;
uniform float slosh_tilt : hint_range(-1.5, 1.5) = 0.0;
uniform float pour_glow : hint_range(0.0, 1.5) = 0.0;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float flash_negative : hint_range(0.0, 1.0) = 0.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	float mask_a = texture(TEXTURE, UV).a;
	if (mask_a <= 0.01) {
		COLOR = vec4(0.0);
	} else {
		float span = max(0.001, mask_bottom - mask_top);
		float h_norm = clamp((mask_bottom - UV.y) / span, 0.0, 1.0);

		// Attenuate slosh near 0% and 100% so empty is clean and 100% fills to the neck
		float wave_env = smoothstep(0.0, 0.04, fill_ratio) * (1.0 - smoothstep(0.96, 1.0, fill_ratio));
		float wave_a = sin(UV.x * 13.0 + TIME * 4.4) * (0.006 + slosh_amp * 0.018);
		float wave_b = sin(UV.x * 23.0 - TIME * 7.2 + 1.1) * (0.002 + slosh_amp * 0.009);
		float tilt_off = (UV.x - 0.5) * slosh_tilt * 0.065;
		float surface_h = clamp(fill_ratio + (wave_a + wave_b + tilt_off) * wave_env, 0.0, 1.0);

		float in_liquid = 1.0 - smoothstep(surface_h - 0.007, surface_h + 0.007, h_norm);

		// Empty interior tint (subtle dark translucent glass cavity for high contrast over bright skies)
		vec3 empty_rgb = mix(vec3(0.06, 0.04, 0.12), liquid_color.rgb, 0.12);
		float empty_a = 0.42;

		// Cylindrical liquid depth shading + glowing core
		float radial = abs(UV.x - 0.5) * 2.0;
		float cyl_shade = mix(1.14, 0.72, smoothstep(0.20, 0.96, radial));
		float depth_grad = mix(0.76, 1.08, h_norm);
		vec3 base_liq = liquid_color.rgb * cyl_shade * depth_grad;

		// Rising effervescent micro-bubbles
		float bub_boost = 1.0 + slosh_amp * 0.8 + pour_glow * 1.1;
		float bub_grid_1 = sin(UV.x * 42.0 + 1.5) * sin((h_norm - TIME * 0.48) * 58.0);
		float bub_grid_2 = sin(UV.x * 68.0 - 2.3) * sin((h_norm - TIME * 0.72) * 86.0 + 2.0);
		float bubbles = smoothstep(0.86, 0.99, bub_grid_1) * 0.30 + smoothstep(0.90, 0.995, bub_grid_2) * 0.35;
		base_liq += vec3(0.45, 0.45, 0.50) * bubbles * bub_boost;

		// Frothy luminous meniscus highlight along the liquid surface
		float meniscus_band = exp(-pow((h_norm - surface_h) / 0.014, 2.0)) * smoothstep(0.01, 0.04, fill_ratio);
		vec3 meniscus_col = mix(liquid_color.rgb, vec3(1.0), 0.72);
		base_liq = mix(base_liq, meniscus_col, clamp(meniscus_band * (0.72 + pour_glow * 0.25), 0.0, 0.95));

		// Pour glow & hit flashes
		base_liq += mix(vec3(1.0, 0.96, 0.88), liquid_color.rgb, 0.35) * (pour_glow * 0.22);
		vec3 flash_col = mix(vec3(1.0, 0.98, 0.90), vec3(1.0, 0.22, 0.26), flash_negative);
		base_liq = mix(base_liq, flash_col, clamp(flash_amount * 0.58, 0.0, 0.65));

		float liq_a = 0.92;
		vec3 final_rgb = mix(empty_rgb, base_liq, in_liquid);
		float final_a = mix(empty_a, liq_a, in_liquid) * mask_a;
		COLOR = vec4(final_rgb, final_a) * v_modulate;
	}
}
