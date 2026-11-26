shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.68);
uniform vec2 shadow_offset = vec2(5.0, 5.0);
uniform float blur_radius : hint_range(0.0, 24.0, 0.5) = 8.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec4 fg = textureLod(screen_texture, SCREEN_UV, 0.0);
	vec3 fg_rgb = fg.a > 0.0001 ? fg.rgb / fg.a : vec3(0.0);

	vec2 sh_uv = SCREEN_UV - shadow_offset * SCREEN_PIXEL_SIZE;
	float blur_alpha = 0.0;
	if (blur_radius <= 0.01) {
		blur_alpha = textureLod(screen_texture, sh_uv, 0.0).a;
	} else {
		blur_alpha += textureLod(screen_texture, sh_uv, 0.0).a * 0.16;
		float inner_r = blur_radius * 0.45;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * (TAU / 8.0);
			vec2 suv = sh_uv + vec2(cos(a), sin(a)) * inner_r * SCREEN_PIXEL_SIZE;
			blur_alpha += textureLod(screen_texture, suv, 0.0).a * 0.055;
		}
		for (int i = 0; i < 16; i++) {
			float a = float(i) * (TAU / 16.0) + 0.19635;
			vec2 suv = sh_uv + vec2(cos(a), sin(a)) * blur_radius * SCREEN_PIXEL_SIZE;
			blur_alpha += textureLod(screen_texture, suv, 0.0).a * 0.025;
		}
	}

	vec4 sh = vec4(shadow_color.rgb, clamp(shadow_color.a * blur_alpha, 0.0, 1.0));
	float out_a = fg.a + sh.a * (1.0 - fg.a);
	vec3 out_rgb = out_a > 0.0001 ? (fg_rgb * fg.a + sh.rgb * sh.a * (1.0 - fg.a)) / out_a : vec3(0.0);
	COLOR = vec4(out_rgb * v_modulate.rgb, out_a * v_modulate.a);
}
