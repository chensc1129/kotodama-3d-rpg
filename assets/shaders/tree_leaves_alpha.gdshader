shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Fast WebGL2 / GL Compatibility alpha-cutout botanical tree-leaf shader.
// Supports rotated/scaled MultiMeshInstance3D trees with synchronized world-space
// wind sway, high-frequency leaf-tip flutter, sunlit crown lift, and translucent backlighting.

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cutoff : hint_range(0.1, 0.9) = 0.42;
uniform float wind_strength : hint_range(0.0, 3.0) = 1.0;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float translucency : hint_range(0.0, 0.5) = 0.16;
uniform bool mobile_mode = false;

varying vec3 v_world_nrm;
varying float v_tip;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz + vec3(0.0, 0.0001, 0.0));

	// Height weight pins lower trunk/roots; tip weight pins branch stem (UV.y = 1) and frees tips (UV.y = 0)
	float height_raw = max(0.0, VERTEX.y - 1.5);
	float height_weight = clamp(height_raw * 0.24, 0.0, 1.45);
	float tip_weight = clamp(1.0 - UV.y, 0.0, 1.0);
	v_tip = tip_weight;

	// Synchronized world-space wind direction (aligned with meadow grass shader)
	vec2 wind_dir = normalize(vec2(0.85, 0.52));
	vec2 wind_perp = vec2(-wind_dir.y, wind_dir.x);

	// 1. Gentle natural rolling branch sway
	float gust_speed = 1.35 + wind_strength * 0.45;
	float gust_phase = dot(world_pos.xz, wind_dir) * 0.22 - TIME * gust_speed;
	float macro_sway = sin(gust_phase) * 0.65 + sin(gust_phase * 0.47 + world_base.x * 0.35 + world_base.z * 0.28) * 0.35;
	float branch_amp = 0.135 * wind_strength * height_weight * (0.35 + 0.65 * tip_weight);

	// 2. High-frequency leaf-tip flutter
	float flutter_weight = tip_weight * tip_weight * clamp(height_raw * 0.55, 0.0, 1.0);
	float flutter_lat = 0.0;
	float flutter_y = 0.0;
	if (mobile_mode) {
		flutter_lat = sin(TIME * 3.8 + world_pos.x * 1.9 + world_pos.z * 1.7) * 0.045;
		flutter_y = cos(TIME * 3.1 + world_pos.y * 2.1) * 0.022;
	} else {
		float f1 = sin(TIME * 4.4 + world_pos.x * 2.3 + world_pos.z * 2.1 + world_pos.y * 1.3);
		float f2 = cos(TIME * 6.2 - world_pos.x * 3.1 + world_pos.z * 2.7);
		flutter_lat = (f1 * 0.68 + f2 * 0.32) * 0.055;
		flutter_y = sin(TIME * 3.5 + world_pos.x * 1.8 - world_pos.z * 1.6) * 0.028;
	}
	float flutter_amp = wind_strength * flutter_weight;

	vec2 world_xz = wind_dir * (macro_sway * branch_amp) + wind_perp * (flutter_lat * flutter_amp);
	float world_y = flutter_y * flutter_amp - abs(macro_sway * branch_amp) * 0.18;

	// Transform world-space wind displacement back into local space for rotated MultiMeshInstance3D trees
	VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(world_xz.x, world_y, world_xz.y);
}

void fragment() {
	vec4 tex = texture(leaf_tex, UV);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;

	// Subtle sunlit crown lift toward sky-facing leaf tops & branch tips
	float sky_facing = clamp(v_world_nrm.y * 0.5 + 0.5, 0.0, 1.0);
	float crown_lift = mix(0.86, 1.15, sky_facing) * mix(0.94, 1.08, v_tip);

	vec3 col = tex.rgb * COLOR.rgb * tint_color.rgb * crown_lift;
	ALBEDO = col;
	EMISSION = col * translucency * (0.45 + 0.55 * clamp(v_world_nrm.y, 0.0, 1.0));
	ROUGHNESS = 0.62;
	METALLIC = 0.02;
}
