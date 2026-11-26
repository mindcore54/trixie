shader_type canvas_item;

uniform vec4 glow_color_a : source_color = vec4(1.0, 0.82, 0.34, 0.92);
uniform vec4 glow_color_b : source_color = vec4(0.76, 0.36, 1.0, 0.85);
uniform float halo_radius : hint_range(0.0, 0.03) = 0.012;
uniform float halo_intensity : hint_range(0.0, 2.5) = 1.25;
uniform float pulse_speed : hint_range(0.1, 6.0) = 2.1;
uniform float shimmer_strength : hint_range(0.0, 0.6) = 0.16;
uniform float contrast_filter : hint_range(0.0, 1.0) = 1.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);

	// 16-tap radial alpha sample for a smooth outer magical aura hugging the sign
	float aura_alpha = 0.0;
	const int SAMPLES = 16;
	for (int i = 0; i < SAMPLES; i++) {
		float angle = float(i) * (6.2831853 / float(SAMPLES));
		vec2 dir = vec2(cos(angle), sin(angle));
		aura_alpha += texture(TEXTURE, UV + dir * halo_radius).a;
		aura_alpha += texture(TEXTURE, UV + dir * (halo_radius * 0.55)).a * 0.7;
	}
	aura_alpha /= float(SAMPLES) * 1.7;

	float pulse = 0.78 + 0.22 * sin(TIME * pulse_speed);
	float color_wave = 0.5 + 0.5 * sin(TIME * 1.15 + UV.x * 3.2 - UV.y * 2.0);
	vec3 halo_rgb = mix(glow_color_a.rgb, glow_color_b.rgb, color_wave * 0.48);

	// Outer halo only where the sign itself is transparent/feathered
	float outer_mask = clamp(aura_alpha * (1.0 - base.a), 0.0, 1.0);
	float outer_alpha = clamp(outer_mask * halo_intensity * pulse, 0.0, 0.95);

	// Subtle traveling golden shimmer across the 3D lettering every ~4.5s
	float sweep_cycle = fract(TIME * 0.22);
	float diag = UV.x * 0.85 + UV.y * 0.45;
	float band = exp(-pow((diag - (sweep_cycle * 2.4 - 0.5)) * 11.0, 2.0));
	vec3 lit_base = base.rgb + vec3(1.0, 0.90, 0.58) * (band * shimmer_strength * base.a);
	lit_base = mix(lit_base, lit_base * base.rgb, contrast_filter);

	vec3 final_rgb = mix(halo_rgb, lit_base, base.a);
	float final_a = max(base.a, outer_alpha);

	COLOR = vec4(final_rgb, final_a) * v_modulate;
}
