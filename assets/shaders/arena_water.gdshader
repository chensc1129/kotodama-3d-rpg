shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 deep_color : source_color = vec4(0.08, 0.22, 0.52, 0.72);
uniform vec4 shallow_color : source_color = vec4(0.24, 0.56, 0.85, 0.62);
uniform vec4 glint_color : source_color = vec4(0.86, 0.94, 1.0, 1.0);
uniform float wave_speed : hint_range(0.1, 4.0) = 1.1;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world_pos.xz;
	float t = TIME * wave_speed;
	float w1 = sin(p.x * 1.6 + t * 1.8) * cos(p.y * 1.4 - t * 1.3);
	float w2 = sin((p.x - p.y) * 2.3 - t * 2.2) * 0.5;
	float ripple = (w1 + w2) * 0.35 + 0.5;
	float caustic = smoothstep(0.76, 0.96, ripple);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);

	vec3 col = mix(deep_color.rgb, shallow_color.rgb, clamp(ripple * 0.65 + fresnel * 0.45, 0.0, 1.0));
	col = mix(col, glint_color.rgb, caustic * 0.45);

	ALBEDO = col;
	ALPHA = clamp(mix(deep_color.a, shallow_color.a + 0.18, fresnel + caustic * 0.3), 0.38, 0.88);
	ROUGHNESS = 0.14;
	METALLIC = 0.35;
	EMISSION = glint_color.rgb * caustic * 0.24;
}
