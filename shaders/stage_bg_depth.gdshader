shader_type canvas_item;

uniform float blur_radius : hint_range(0.0, 6.0) = 2.0;
uniform float darken : hint_range(0.0, 0.7) = 0.16;
uniform float vignette_strength : hint_range(0.0, 0.7) = 0.28;
uniform float frenzy_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur_radius;

	vec4 col = texture(TEXTURE, UV) * 0.24;
	col += texture(TEXTURE, UV + vec2(px.x, 0.0)) * 0.12;
	col += texture(TEXTURE, UV - vec2(px.x, 0.0)) * 0.12;
	col += texture(TEXTURE, UV + vec2(0.0, px.y)) * 0.12;
	col += texture(TEXTURE, UV - vec2(0.0, px.y)) * 0.12;
	col += texture(TEXTURE, UV + vec2(px.x, px.y)) * 0.07;
	col += texture(TEXTURE, UV + vec2(-px.x, px.y)) * 0.07;
	col += texture(TEXTURE, UV + vec2(px.x, -px.y)) * 0.07;
	col += texture(TEXTURE, UV + vec2(-px.x, -px.y)) * 0.07;

	vec2 d = UV - vec2(0.5, 0.5);
	float dist = length(d * vec2(1.15, 1.0));
	float vig = smoothstep(0.32, 0.92, dist) * vignette_strength;

	vec3 rgb = col.rgb * (1.0 - darken - vig);
	vec3 frenzy_tint = mix(rgb, rgb * vec3(1.18, 0.76, 1.04) + vec3(0.08, 0.01, 0.05), 0.55);
	rgb = mix(rgb, frenzy_tint, clamp(frenzy_amount, 0.0, 1.0));

	COLOR = vec4(rgb, col.a) * COLOR;
}
