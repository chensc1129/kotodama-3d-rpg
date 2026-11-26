shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Interactive botanical foliage shader for double-sided meadow grass blades,
// reeds, wildflowers, and ground-cover tufts with MultiMeshInstance3D support.
uniform float wind_strength : hint_range(0.0, 3.0) = 1.0;
uniform vec2 wind_dir = vec2(0.85, 0.52);
uniform vec3 player_pos = vec3(9999.0, 0.0, 9999.0);
uniform vec3 player_vel = vec3(0.0, 0.0, 0.0);
uniform vec3 gust_pos = vec3(9999.0, 0.0, 9999.0);
uniform float gust_time = 99.0;
uniform float sway_scale : hint_range(0.0, 2.0) = 0.28;
uniform float bend_radius : hint_range(0.4, 4.0) = 1.65;
uniform bool mobile_mode = false;

varying float v_h;
varying float v_wind_wave;
varying vec3 v_vcol;

void vertex() {
	float h = clamp(UV.y, 0.0, 1.0);
	float h2 = h * h;
	v_h = h;
	v_vcol = COLOR.rgb;

	vec3 world_base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 world_v = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	vec2 wdir = normalize(wind_dir + vec2(0.0001, 0.0));
	vec2 wperp = vec2(-wdir.y, wdir.x);

	// 1. Rolling wind gust waves + secondary tip rustle
	float w_speed = 1.8 + wind_strength * 0.9;
	float w_phase = dot(world_v.xz, wdir) * 0.45 - TIME * w_speed;
	float primary_wave = sin(w_phase);
	float macro_gust = sin(dot(world_v.xz, wdir) * 0.16 - TIME * (0.95 + wind_strength * 0.45)) * 0.5 + 0.5;
	float flutter = mobile_mode
		? (sin(w_phase * 2.15 + world_base.x * 1.7) * 0.22)
		: (sin(TIME * 4.2 + world_base.x * 2.7 + world_base.z * 3.1) * 0.28 + cos(TIME * 2.8 - world_v.x * 1.9) * 0.14);

	float wind_push = (primary_wave * 0.65 + 0.35 + macro_gust * 0.45) * wind_strength * sway_scale;
	vec2 disp_xz = wdir * wind_push + wperp * (flutter * wind_strength * sway_scale * 0.45);
	v_wind_wave = clamp((primary_wave * 0.5 + 0.5) * (0.55 + 0.45 * macro_gust), 0.0, 1.0);

	// 2. Real-time physical player parting + subtle velocity wake
	float bend_amt = 0.0;
	vec2 diff = world_v.xz - player_pos.xz;
	float dist = length(diff);
	float dy = abs(world_base.y - player_pos.y);
	if (dist < bend_radius && dy < 2.2) {
		vec2 push_dir = (dist > 0.001) ? (diff / dist) : wdir;
		float rad_f = 1.0 - smoothstep(0.0, bend_radius, dist);
		float y_f = 1.0 - smoothstep(1.1, 2.2, dy);
		float p_strength = rad_f * rad_f * y_f;
		vec2 vel_wake = clamp(player_vel.xz, vec2(-8.0), vec2(8.0)) * 0.065;
		disp_xz += (push_dir * 0.95 + vel_wake) * p_strength;
		bend_amt += p_strength;
	}

	// 3. Expanding dash / slash shockwave gust ring
	if (gust_time >= 0.0 && gust_time < 1.2) {
		vec2 g_diff = world_v.xz - gust_pos.xz;
		float g_dist = length(g_diff);
		vec2 g_dir = (g_dist > 0.001) ? (g_diff / g_dist) : wdir;
		float ring_r = gust_time * 9.5;
		float ring_band = exp(-abs(g_dist - ring_r) * 1.15);
		float time_fade = 1.0 - smoothstep(0.55, 1.2, gust_time);
		float shock = ring_band * time_fade * (0.65 + 0.35 * sin((g_dist - ring_r) * 5.0));
		disp_xz += g_dir * (shock * 0.88);
		bend_amt += shock * 0.72;
	}

	// Pin roots at UV.y = 0, bend tips quadratically with arc-length Y depression
	vec2 total_xz = disp_xz * h2;
	float horiz_len = length(total_xz);
	float disp_y = -min(horiz_len * 0.42 + bend_amt * 0.22 * h2, 0.55 * h);

	// Convert world-space displacement back into local space for rotated/scaled MultiMesh instances
	VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(total_xz.x, disp_y, total_xz.y);
}

void fragment() {
	// Soft sunlit tip lift + subtle rolling wind-wave sheen
	float tip_lift = mix(0.68, 1.22, v_h);
	float sheen = v_wind_wave * v_h * v_h * 0.16;
	vec3 col = v_vcol * tip_lift + vec3(0.08, 0.10, 0.05) * sheen;

	// Highlight vibrant flower petals gently so blossoms pop at twilight
	float non_green = max(v_vcol.r - v_vcol.g * 0.85, v_vcol.b - v_vcol.g * 0.85);
	float bright_petal = smoothstep(0.76, 1.0, max(v_vcol.r, max(v_vcol.g, v_vcol.b)));
	float flower_hint = clamp(non_green * 2.2 + bright_petal * 0.5, 0.0, 1.0);
	float tip_mask = smoothstep(0.35, 0.95, v_h);

	ALBEDO = clamp(col, vec3(0.0), vec3(1.45));
	ROUGHNESS = 0.68;
	METALLIC = 0.02;
	EMISSION = col * (0.025 + 0.06 * flower_hint) * tip_mask;
}
