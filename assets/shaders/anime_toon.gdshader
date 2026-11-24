shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;

uniform vec4 shadow_tint : source_color = vec4(0.32, 0.27, 0.48, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.94, 0.88, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.42;
uniform float rim_power : hint_range(1.0, 8.0) = 3.2;

uniform float roughness_val : hint_range(0.0, 1.0) = 0.48;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 6.0) = 0.0;

uniform vec4 status_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float status_mix : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 base = albedo_color;
	if (use_texture) {
		base *= texture(albedo_texture, UV);
	}
	vec3 final_col = mix(base.rgb, status_tint.rgb, status_mix);
	ALBEDO = final_col;
	ROUGHNESS = roughness_val;
	METALLIC = metallic_val;

	// Subtle Fresnel anime rim light
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	vec3 rim = rim_color.rgb * fresnel * rim_strength;
	EMISSION = emission_color.rgb * emission_energy + rim * (1.0 - status_mix * 0.5);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// Soft 2-band anime cel ramp
	float lit = smoothstep(-0.08, 0.14, ndl) * ATTENUATION;
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), lit);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * shade * 0.92;

	// Crisp anime specular highlight
	vec3 half_vec = normalize(LIGHT + VIEW);
	float ndh = max(dot(NORMAL, half_vec), 0.0);
	float spec_power = mix(48.0, 10.0, roughness_val);
	float spec_step = smoothstep(0.45, 0.62, pow(ndh, spec_power));
	float spec_amp = mix(0.45, 0.08, roughness_val) + metallic_val * 0.35;
	SPECULAR_LIGHT += LIGHT_COLOR * spec_step * spec_amp * lit;
}
