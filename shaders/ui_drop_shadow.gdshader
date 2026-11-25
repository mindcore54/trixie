shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.04, 0.02, 0.07, 0.56);
uniform vec2 shadow_offset = vec2(10.0, 14.0);
uniform float blur_radius : hint_range(0.0, 32.0, 0.5) = 12.0;
uniform vec2 render_size = vec2(0.0, 0.0);

varying vec4 v_modulate;

void vertex() {
	float pad = max(abs(shadow_offset.x), abs(shadow_offset.y)) + blur_radius + 6.0;
	vec2 base_size = (render_size.x > 0.0 && render_size.y > 0.0) ? render_size : (1.0 / TEXTURE_PIXEL_SIZE);
	vec2 corner = step(vec2(0.001), VERTEX) * 2.0 - 1.0;
	VERTEX += corner * pad;
	UV += (UV * 2.0 - 1.0) * (vec2(pad) / base_size);
	v_modulate = COLOR;
}

void fragment() {
	vec2 base_size = (render_size.x > 0.0 && render_size.y > 0.0) ? render_size : (1.0 / TEXTURE_PIXEL_SIZE);
	float flip_sx = dFdx(UV.x) < 0.0 ? -1.0 : 1.0;
	float flip_sy = dFdy(UV.y) < 0.0 ? -1.0 : 1.0;
	vec2 px_to_uv = vec2(flip_sx, flip_sy) / base_size;

	vec4 fg = vec4(0.0);
	if (UV.x >= 0.0 && UV.x <= 1.0 && UV.y >= 0.0 && UV.y <= 1.0) {
		fg = texture(TEXTURE, UV) * v_modulate;
	}

	vec2 sh_uv = UV - shadow_offset * px_to_uv;
	float blur_alpha = 0.0;
	if (blur_radius <= 0.01) {
		if (sh_uv.x >= 0.0 && sh_uv.x <= 1.0 && sh_uv.y >= 0.0 && sh_uv.y <= 1.0) {
			blur_alpha = texture(TEXTURE, sh_uv).a;
		}
	} else {
		if (sh_uv.x >= 0.0 && sh_uv.x <= 1.0 && sh_uv.y >= 0.0 && sh_uv.y <= 1.0) {
			blur_alpha += texture(TEXTURE, sh_uv).a * 0.18;
		}
		float inner_r = blur_radius * 0.5;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * (TAU / 8.0);
			vec2 suv = sh_uv + vec2(cos(a), sin(a)) * inner_r * px_to_uv;
			if (suv.x >= 0.0 && suv.x <= 1.0 && suv.y >= 0.0 && suv.y <= 1.0) {
				blur_alpha += texture(TEXTURE, suv).a * 0.055;
			}
		}
		for (int i = 0; i < 12; i++) {
			float a = float(i) * (TAU / 12.0) + 0.261799;
			vec2 suv = sh_uv + vec2(cos(a), sin(a)) * blur_radius * px_to_uv;
			if (suv.x >= 0.0 && suv.x <= 1.0 && suv.y >= 0.0 && suv.y <= 1.0) {
				blur_alpha += texture(TEXTURE, suv).a * 0.0316667;
			}
		}
	}

	vec4 sh = vec4(shadow_color.rgb, clamp(shadow_color.a * blur_alpha * v_modulate.a, 0.0, 1.0));
	float out_a = fg.a + sh.a * (1.0 - fg.a);
	vec3 out_rgb = out_a > 0.0001 ? (fg.rgb * fg.a + sh.rgb * sh.a * (1.0 - fg.a)) / out_a : vec3(0.0);
	COLOR = vec4(out_rgb, out_a);
}
