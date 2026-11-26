shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 deep_color : source_color = vec4(0.08, 0.22, 0.52, 0.72);
uniform vec4 shallow_color : source_color = vec4(0.24, 0.56, 0.85, 0.62);
uniform vec4 glint_color : source_color = vec4(0.86, 0.94, 1.0, 1.0);
uniform float wave_speed : hint_range(0.1, 4.0) = 1.1;

// Interactive water surface & splash wave uniforms (safe defaults for backwards compatibility)
uniform float wave_amp : hint_range(0.0, 0.25) = 0.045;
uniform float wind_strength : hint_range(0.0, 3.0) = 1.0;
uniform vec3 splash_pos = vec3(9999.0, 0.0, 9999.0);
uniform float splash_time = 99.0;
uniform float splash_strength : hint_range(0.0, 2.0) = 0.0;
uniform vec3 player_pos = vec3(9999.0, 0.0, 9999.0);
uniform bool mobile_mode = false;

varying vec3 v_world_pos;
varying float v_wave_crest;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float amp = wave_amp * (0.65 + 0.35 * wind_strength);

	// Smooth dual-directional Gerstner-like vertical wave displacement
	vec2 dir1 = vec2(0.82, 0.57);
	vec2 dir2 = vec2(-0.48, 0.88);
	float k1 = 0.72;
	float k2 = 1.15;
	float ph1 = dot(wp.xz, dir1) * k1 - t * 1.45;
	float ph2 = dot(wp.xz, dir2) * k2 - t * 1.95;

	float wave_raw = sin(ph1) * 0.62 + sin(ph2) * 0.38;
	VERTEX.y += wave_raw * amp;

	// Analytical wave slopes for gentle sunlight/moonlight normal perturbation
	float dh_dx = (cos(ph1) * 0.62 * dir1.x * k1 + cos(ph2) * 0.38 * dir2.x * k2) * amp;
	float dh_dz = (cos(ph1) * 0.62 * dir1.y * k1 + cos(ph2) * 0.38 * dir2.y * k2) * amp;
	NORMAL = normalize(NORMAL + vec3(-dh_dx, 0.0, -dh_dz) * 1.35);

	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wave_crest = wave_raw;
}

void fragment() {
	vec2 p = v_world_pos.xz;
	float t = TIME * wave_speed;

	// Layered rippling caustics
	float w1 = sin(p.x * 1.6 + t * 1.8) * cos(p.y * 1.4 - t * 1.3);
	float w2 = sin((p.x - p.y) * 2.3 - t * 2.2) * 0.5;
	float w3 = mobile_mode ? 0.0 : sin((p.x * 0.85 + p.y * 1.35) * 3.1 + t * 2.6) * 0.25;
	float ripple = (w1 + w2 + w3) * 0.35 + 0.5;
	float caustic = smoothstep(0.74, 0.96, ripple);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);

	// Base water + Fresnel sky reflection tint
	vec3 sky_refl = mix(shallow_color.rgb * 1.18, glint_color.rgb, 0.52);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, clamp(ripple * 0.62 + fresnel * 0.38, 0.0, 1.0));
	col = mix(col, sky_refl, fresnel * 0.42);
	col = mix(col, glint_color.rgb, caustic * 0.45);

	// Expanding concentric splash rings (decays cleanly over ~1.8s)
	float splash_foam = 0.0;
	if (splash_time >= 0.0 && splash_time < 2.0 && splash_strength > 0.01) {
		float d_sp = length(p - splash_pos.xz);
		float ring_front = splash_time * 3.6;
		float time_decay = 1.0 - smoothstep(0.85, 1.95, splash_time);
		float dist_decay = exp(-d_sp * 0.14);
		float front_band = exp(-abs(d_sp - ring_front) * 0.88);
		float trail_band = (1.0 - smoothstep(ring_front - 0.1, ring_front + 0.55, d_sp)) * exp(-max(0.0, ring_front - d_sp) * 0.55);
		float ring_wave = smoothstep(0.28, 0.92, sin((d_sp - ring_front) * 6.5) * 0.5 + 0.5);
		splash_foam = ring_wave * max(front_band, trail_band * 0.65) * time_decay * dist_decay * clamp(splash_strength, 0.0, 2.0);
	}

	// Subtle gentle wake glow when player is wading/standing in the water
	float player_wake = 0.0;
	float p_dy = abs(player_pos.y - v_world_pos.y);
	if (p_dy < 1.2) {
		float d_pl = length(p - player_pos.xz);
		if (d_pl < 3.2) {
			float y_mask = 1.0 - smoothstep(0.55, 1.2, p_dy);
			float r_mask = 1.0 - smoothstep(0.35, 3.1, d_pl);
			float wake_ring = smoothstep(0.36, 0.90, sin(d_pl * 7.2 - TIME * 4.5) * 0.5 + 0.5);
			float wake_core = 1.0 - smoothstep(0.22, 0.92, d_pl);
			player_wake = (wake_ring * 0.62 + wake_core * 0.45) * r_mask * y_mask;
		}
	}

	// Soft organic foam shimmer in shallow / wave crests
	float crest_mask = smoothstep(0.35, 0.95, v_wave_crest * 0.5 + 0.5);
	float shimmer_foam = smoothstep(0.66, 0.94, ripple + crest_mask * 0.18) * (0.16 + 0.14 * crest_mask);

	float total_foam = clamp(splash_foam * 1.15 + player_wake * 0.62 + shimmer_foam, 0.0, 1.0);
	vec3 foam_col = mix(glint_color.rgb, vec3(0.84, 0.98, 1.0), 0.55);
	col = mix(col, foam_col, total_foam * 0.88);

	ALBEDO = col;
	ALPHA = clamp(mix(deep_color.a, shallow_color.a + 0.18, fresnel + caustic * 0.3) + total_foam * 0.24, 0.38, 0.94);
	ROUGHNESS = mix(0.14, 0.34, total_foam);
	METALLIC = mix(0.35, 0.08, total_foam);
	EMISSION = glint_color.rgb * caustic * 0.24 + foam_col * (splash_foam * 0.58 + player_wake * 0.26);
}
