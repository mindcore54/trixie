shader_type canvas_item;

uniform vec4 bottom_tint : source_color = vec4(0.46, 0.40, 0.36, 1.0);
uniform float grad_start_y = 18.0;
uniform float grad_end_y = 44.0;

varying float v_local_y;

void vertex() {
	v_local_y = VERTEX.y;
}

void fragment() {
	float t = clamp((v_local_y - grad_start_y) / max(1.0, grad_end_y - grad_start_y), 0.0, 1.0);
	vec3 mult = mix(vec3(1.0), bottom_tint.rgb, smoothstep(0.0, 1.0, t));
	COLOR.rgb *= mult;
}
