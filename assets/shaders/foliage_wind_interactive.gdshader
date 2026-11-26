shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Photorealistic botanical & real-physics interactive foliage shader for double-sided
// meadow grass blades, reeds, wildflowers, and ground-cover tufts (MultiMeshInstance3D).
// Strict Godot 4.3 GL Compatibility / WebGL2 safe.

uniform float wind_strength : hint_range(0.0, 3.0) = 1.0;
uniform vec2 wind_dir = vec2(0.85, 0.52);
uniform vec3 player_pos = vec3(9999.0, 0.0, 9999.0);
uniform vec3 player_vel = vec3(0.0, 0.0, 0.0);
uniform vec3 gust_pos = vec3(9999.0, 0.0, 9999.0);
uniform float gust_time = 99.0;
uniform float sway_scale : hint_range(0.0, 2.0) = 0.28;
uniform float bend_radius : hint_range(0.4, 4.0) = 1.65;
uniform bool mobile_mode = false;

// Real-physics CPU spring-damper foliage field & live gust modulation
uniform sampler2D phys_field : filter_linear, repeat_disable;
uniform vec2 phys_origin = vec2(-24.0, -24.0);
uniform float phys_size = 48.0;
uniform bool has_phys_field = false;
uniform float gust_strength : hint_range(0.0, 3.0) = 1.0;
uniform float wind_gust : hint_range(0.0, 2.0) = 0.0;

varying float v_h;
varying vec2 v_uv;
varying vec3 v_world_nrm;
varying float v_trample;
varying float v_wind_wave;
varying vec3 v_world_pos;
varying vec3 v_vcol;

void vertex() {
	float h = clamp(UV.y, 0.0, 1.0);
	float h2 = h * h;
	float h_cant = mix(h2, h2 * h, 0.35); // Quadratic/cubic cantilever curvature profile
	v_h = h;
	v_uv = UV;
	v_vcol = COLOR.rgb;

	vec3 world_base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 world_v = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	vec2 wdir = normalize(wind_dir + vec2(0.0001, 0.0));
	vec2 wperp = vec2(-wdir.y, wdir.x);

	// 1. Sample CPU Hooke's-law spring-damper physics field (bend, persistent trample, oscillation)
	vec2 phys_bend = vec2(0.0);
	float phys_trample = 0.0;
	float phys_osc = 0.0;
	if (has_phys_field) {
		vec2 p_uv = (world_base.xz - phys_origin) / max(phys_size, 1.0);
		vec2 edge_m = smoothstep(vec2(0.0), vec2(0.08), p_uv) * (vec2(1.0) - smoothstep(vec2(0.92), vec2(1.0), p_uv));
		float pf_mask = edge_m.x * edge_m.y;
		if (pf_mask > 0.001) {
			vec4 pf = textureLod(phys_field, clamp(p_uv, vec2(0.0), vec2(1.0)), 0.0);
			phys_bend = (pf.rg * 2.0 - 1.0) * 1.45 * pf_mask;
			phys_trample = clamp(pf.b, 0.0, 1.0) * pf_mask;
			phys_osc = clamp(pf.a, 0.0, 1.0) * pf_mask;
		}
	}

	// 2. Multi-scale aerodynamic wind waves (macro gust fronts + cross-eddy + blade-tip flutter)
	float eff_wind = wind_strength + wind_gust * 0.85;
	float front_speed = 1.65 + wind_strength * 0.72 + wind_gust * 0.55;
	float front_phase = dot(world_v.xz, wdir) * 0.14 - TIME * front_speed;
	float macro_front = sin(front_phase) * 0.5 + 0.5;
	float gust_crest = macro_front * macro_front * (0.65 + 0.35 * sin(dot(world_v.xz, wperp) * 0.09 + TIME * 0.45));

	float primary_speed = 2.05 + wind_strength * 0.95;
	float primary_phase = dot(world_v.xz, wdir) * 0.44 - TIME * primary_speed;
	float primary_wave = sin(primary_phase);

	float flutter_drive = eff_wind + phys_osc * 1.2;
	float cross_eddy = sin(dot(world_v.xz, wperp) * 0.38 + dot(world_v.xz, wdir) * 0.21 - TIME * (1.7 + wind_strength * 0.5));
	float tip_flutter = mobile_mode
		? (sin(primary_phase * 2.2 + world_base.x * 1.7 + world_base.z * 1.3) * 0.24)
		: (sin(TIME * 4.8 + world_base.x * 2.9 + world_base.z * 3.3 + VERTEX.x * 6.0) * 0.26
			+ cos(TIME * 3.4 - world_v.x * 2.3 + world_v.z * 1.9) * 0.16);
	float rebound_ring = phys_osc * sin(TIME * 11.5 + world_base.x * 3.1 + world_base.z * 2.7) * 0.24;

	float wind_push = ((primary_wave * 0.52 + 0.48) * 0.58 + gust_crest * 0.78) * eff_wind * sway_scale;
	vec2 wind_xz = wdir * (wind_push + rebound_ring * sway_scale)
		+ wperp * ((cross_eddy * 0.34 + tip_flutter * 0.48) * flutter_drive * sway_scale * (0.55 + 0.45 * h));
	v_wind_wave = clamp(gust_crest * 0.65 + (primary_wave * 0.5 + 0.5) * 0.35 * clamp(eff_wind * 0.65, 0.2, 1.3), 0.0, 1.0);

	// 3. Sub-texel immediate player parting + velocity wake layered atop spring field
	vec2 react_xz = vec2(0.0);
	float local_trample = 0.0;
	vec2 p_diff = world_v.xz - player_pos.xz;
	float p_dist = length(p_diff);
	float p_dy = abs(world_base.y - player_pos.y);
	if (p_dist < bend_radius && p_dy < 2.2) {
		vec2 push_dir = (p_dist > 0.001) ? (p_diff / p_dist) : wdir;
		float rad_f = 1.0 - smoothstep(0.0, max(bend_radius, 0.05), p_dist);
		float y_f = 1.0 - smoothstep(1.1, 2.2, p_dy);
		float p_strength = rad_f * rad_f * y_f;
		vec2 vel_wake = clamp(player_vel.xz, vec2(-9.0), vec2(9.0)) * 0.075;
		react_xz += (push_dir * 1.05 + vel_wake) * p_strength;
		local_trample = p_strength * 0.65;
	}

	// 4. Expanding dash / slash shockwave with damped harmonic recoil
	if (gust_time >= 0.0 && gust_time < 1.8) {
		vec2 g_diff = world_v.xz - gust_pos.xz;
		float g_dist = length(g_diff);
		vec2 g_dir = (g_dist > 0.001) ? (g_diff / g_dist) : wdir;
		float wave_age = gust_time - g_dist / 11.0;
		if (wave_age > -0.18) {
			float arrival = smoothstep(-0.18, 0.06, wave_age);
			float decay = exp(-3.2 * max(0.0, wave_age));
			float dist_atten = 1.0 / (1.0 + g_dist * 0.14);
			float recoil = cos(13.5 * max(0.0, wave_age));
			float impulse = arrival * decay * dist_atten * (0.45 + 0.55 * recoil) * gust_strength;
			react_xz += g_dir * (impulse * 1.15);
		}
	}

	// 5. True Cantilever Arc-Length Conservation (circular arc folding up to ~79 deg flat)
	vec2 total_bend_xz = wind_xz + phys_bend + react_xz;
	float bend_len = length(total_bend_xz);
	vec2 bend_dir = (bend_len > 0.0005) ? (total_bend_xz / bend_len) : wdir;

	float eff_trample = clamp(max(phys_trample, local_trample), 0.0, 1.0);
	float theta = clamp(bend_len * 1.15 + eff_trample * 1.05, 0.0, 1.38);
	float theta_h = theta * mix(0.62, 1.0, h);

	float world_scale_y = max(length(MODEL_MATRIX[1].xyz), 0.01);
	float blade_y = max(VERTEX.y, 0.0) * world_scale_y;
	float seg_len = max(blade_y, 0.45 * h * world_scale_y);

	float horiz_arc = sin(theta_h) * seg_len * mix(0.68, 1.0, h_cant);
	float vert_arc = -(1.0 - cos(theta_h)) * seg_len * (0.85 + 0.15 * eff_trample);
	vert_arc -= eff_trample * blade_y * 0.18 * h2;
	vert_arc = max(vert_arc, -blade_y * 0.92);

	vec3 world_disp = vec3(bend_dir.x * horiz_arc, vert_arc, bend_dir.y * horiz_arc);

	// Convert world-space displacement back into local space for rotated/scaled MultiMesh instances
	VERTEX += inverse(mat3(MODEL_MATRIX)) * world_disp;

	v_world_pos = world_v + world_disp;
	v_trample = eff_trample;

	// Tilt world normal along cantilever bend so sheen & sky lighting follow folded blades
	vec3 base_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz + vec3(0.0, 0.0001, 0.0));
	vec3 bent_nrm = normalize(vec3(bend_dir.x * sin(theta), cos(theta), bend_dir.y * sin(theta)));
	v_world_nrm = normalize(mix(base_nrm, bent_nrm, 0.45 * h));
}

void fragment() {
	// Clean double-sided lighting normal
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;

	// Detect vibrant wildflower petals so grass-blade striations never muddy blossoms
	float non_green = max(v_vcol.r - v_vcol.g * 0.85, v_vcol.b - v_vcol.g * 0.85);
	float bright_petal = smoothstep(0.76, 1.0, max(v_vcol.r, max(v_vcol.g, v_vcol.b)));
	float flower_hint = clamp(non_green * 2.2 + bright_petal * 0.5, 0.0, 1.0);
	float grass_mask = 1.0 - flower_hint;

	// 1. Botanical blade midrib crease, glossy curved ridges & micro fibrous vein striation
	float cross_x = abs(v_uv.x - 0.5) * 2.0;
	float midrib_crease = 1.0 - smoothstep(0.0, 0.22, cross_x);
	float ridge_hi = smoothstep(0.18, 0.55, cross_x) * (1.0 - smoothstep(0.72, 1.0, cross_x));
	float micro_vein = mobile_mode ? 0.5 : (sin(v_uv.x * 28.0) * 0.5 + 0.5);
	float blade_profile = (1.0 - midrib_crease * 0.14 * grass_mask)
		* (1.0 + ridge_hi * 0.11 * grass_mask)
		* mix(0.95, 1.05, micro_vein * grass_mask + (1.0 - grass_mask) * 0.5);

	// 2. Soft root ambient occlusion melting blade bases organically into terrain soil/moss
	float root_ao = mix(0.46, 1.0, smoothstep(0.0, 0.35, v_h));
	float tip_lift = mix(0.84, 1.18, v_h);

	// 3. Rolling wind-wave specular sheen & subtle disturbed darkening on trampled trails
	float sheen = v_wind_wave * v_h * v_h * (0.18 + 0.10 * ridge_hi * grass_mask) * (1.0 - v_trample * 0.45);
	vec3 col = v_vcol * root_ao * tip_lift * blade_profile;
	col *= mix(1.0, 0.78, v_trample * (1.0 - flower_hint * 0.55));
	col += mix(vec3(0.09, 0.12, 0.04), vec3(0.08, 0.07, 0.06), flower_hint) * sheen;

	// 4. View-dependent backlit subsurface scattering (chlorophyll glow & luminous petals)
	vec3 sun_world = normalize(vec3(0.48, 0.72, 0.50));
	vec3 sun_view = normalize((VIEW_MATRIX * vec4(sun_world, 0.0)).xyz);
	float back_dot = clamp(dot(normalize(-VIEW), sun_view), 0.0, 1.0);
	float sss = pow(back_dot, 2.8) * smoothstep(0.25, 1.0, v_h);
	vec3 sss_col = mix(vec3(0.55, 0.86, 0.18) * max(v_vcol.g, 0.25) * 1.35, v_vcol * 1.15, flower_hint);

	float tip_mask = smoothstep(0.35, 0.95, v_h);
	ALBEDO = clamp(col, vec3(0.0), vec3(1.45));
	ROUGHNESS = clamp(mix(0.72, 0.48, ridge_hi * grass_mask + sheen * 0.65) - flower_hint * 0.08, 0.38, 0.84);
	SPECULAR = mix(0.35, 0.62, ridge_hi * grass_mask);
	METALLIC = 0.02;
	EMISSION = col * (0.022 + 0.065 * flower_hint) * tip_mask + sss_col * sss * (0.42 + 0.18 * v_wind_wave);
}

