shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Photorealistic WebGL2 / GL Compatibility alpha-cutout botanical tree-leaf shader.
// 3-tier coupled aerodynamic physics (nonlinear wind drag sway, damped harmonic shockwave
// & low-branch player parting, torsional leaf-blade vortex flutter) with per-tree organic
// variation, micro-vein relief, waxy cuticle specular, and backlit subsurface scattering.

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cutoff : hint_range(0.1, 0.9) = 0.42;
uniform float wind_strength : hint_range(0.0, 3.0) = 1.0;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float translucency : hint_range(0.0, 0.5) = 0.16;
uniform bool mobile_mode = false;

// Live synchronized wind, player wake & shockwave impulse uniforms
uniform vec2 wind_dir = vec2(0.85, 0.52);
uniform float wind_gust : hint_range(0.0, 2.0) = 0.0;
uniform vec3 player_pos = vec3(9999.0, 0.0, 9999.0);
uniform vec3 player_vel = vec3(0.0, 0.0, 0.0);
uniform vec3 gust_pos = vec3(9999.0, 0.0, 9999.0);
uniform float gust_time = 99.0;
uniform float gust_strength : hint_range(0.0, 3.0) = 1.0;

varying vec3 v_world_nrm;
varying float v_tip;
varying float v_tree_hash;
varying float v_canopy_h;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz + vec3(0.0, 0.0001, 0.0));

	// Deterministic per-tree hash so MultiMesh forests sway & tint organically
	float th = fract(sin(dot(world_base.xz, vec2(127.1, 311.7))) * 43758.5453);
	v_tree_hash = th;

	// Height weight pins lower trunk; tip weight pins branch stem (UV.y = 1) and frees tips (UV.y = 0)
	float height_raw = max(0.0, VERTEX.y - 1.2);
	float height_weight = clamp(height_raw * 0.25, 0.0, 1.50);
	float tip_weight = clamp(1.0 - UV.y, 0.0, 1.0);
	float edge_twist = (UV.x - 0.5) * 2.0; // -1..+1 across sprig width for torsional stem flutter
	v_tip = tip_weight;
	v_canopy_h = clamp((VERTEX.y - 1.0) * 0.18, 0.0, 1.0);

	vec2 wdir = normalize(wind_dir + vec2(0.0001, 0.0));
	vec2 wperp = vec2(-wdir.y, wdir.x);

	// Tier 1: Nonlinear Wind Drag Cantilever Sway with true arc-length vertical droop
	float drag_wind = pow(max(wind_strength, 0.05), 1.35) + wind_gust * 0.65;
	float tree_phase = th * 6.28318;
	float gust_speed = 1.25 + wind_strength * 0.48 + wind_gust * 0.35;
	float gust_phase = dot(world_pos.xz, wdir) * 0.19 - TIME * gust_speed;
	float macro_sway = sin(gust_phase + tree_phase * 0.35) * 0.60
		+ sin(gust_phase * 0.46 + tree_phase) * 0.32
		+ 0.28 * clamp(wind_gust, 0.0, 2.0);
	float branch_amp = 0.14 * drag_wind * height_weight * (0.35 + 0.65 * tip_weight);

	vec2 sway_xz = wdir * (macro_sway * branch_amp)
		+ wperp * (cos(gust_phase * 0.63 + tree_phase * 1.3) * 0.24 * branch_amp);
	float sway_mag = length(sway_xz);
	float sway_droop_y = -0.22 * sway_mag;

	// Tier 2: Expanding 3D Shockwave Impulse (damped harmonic spring) + Low-Branch Player Parting
	vec3 react_disp = vec3(0.0);
	float shock_energy = 0.0;
	if (gust_time >= 0.0 && gust_time < 2.2) {
		vec3 g_diff = world_pos - gust_pos;
		float g_dist = length(g_diff);
		if (g_dist < 28.0) {
			float wave_age = gust_time - g_dist / 12.5;
			if (wave_age > -0.16) {
				float arrival = smoothstep(-0.16, 0.05, wave_age);
				float env = exp(-2.6 * max(0.0, wave_age));
				float damped_spring = env * cos(10.5 * max(0.0, wave_age));
				float dist_atten = 1.0 / (1.0 + g_dist * 0.11);
				vec3 radial_dir = (g_dist > 0.01) ? (g_diff / g_dist) : vec3(wdir.x, 0.2, wdir.y);
				vec3 shove_dir = normalize(vec3(radial_dir.x, radial_dir.y * 0.45 + 0.22, radial_dir.z));
				float crown_flex = max(height_weight, 0.35) * (0.35 + 0.65 * tip_weight);
				react_disp += shove_dir * (arrival * damped_spring * dist_atten * gust_strength * 0.68 * crown_flex);
				shock_energy = arrival * env * dist_atten * gust_strength;
			}
		}
	}

	vec3 p_diff = world_pos - player_pos;
	float dist_3d = length(p_diff);
	if (dist_3d < 3.4) {
		float falloff = 1.0 - smoothstep(0.0, 3.4, dist_3d);
		float push_f = falloff * falloff * (0.25 + 0.75 * tip_weight);
		vec3 push_dir = (dist_3d > 0.01) ? (p_diff / dist_3d) : vec3(wdir.x, 0.15, wdir.y);
		vec3 vel_wake = clamp(player_vel, vec3(-9.0), vec3(9.0)) * 0.085;
		react_disp += (push_dir * 0.95 + vel_wake) * push_f;
		shock_energy = max(shock_energy, push_f * 0.8);
	}

	// Tier 3: Individual Leaf-Blade Aerodynamic Vortex Flutter & Torsional Stem Twist
	float flutter_drive = drag_wind + shock_energy * 2.2;
	float flutter_w = tip_weight * (0.25 + 0.75 * tip_weight) * clamp(max(VERTEX.y, 0.6) * 0.42, 0.25, 1.0);
	float flutter_lat = 0.0;
	float flutter_y = 0.0;
	float twist_val = 0.0;
	if (mobile_mode) {
		flutter_lat = sin(TIME * 4.0 + world_pos.x * 1.9 + world_pos.z * 1.7 + tree_phase) * 0.048;
		flutter_y = cos(TIME * 3.3 + world_pos.y * 2.1 + tree_phase) * 0.024;
		twist_val = sin(TIME * 5.6 + world_pos.x * 2.7 + world_pos.z * 2.3) * 0.055;
	} else {
		float f1 = sin(TIME * 4.6 + world_pos.x * 2.3 + world_pos.z * 2.1 + world_pos.y * 1.4);
		float f2 = cos(TIME * 6.8 - world_pos.x * 3.2 + world_pos.z * 2.8 + tree_phase);
		flutter_lat = (f1 * 0.65 + f2 * 0.35) * 0.058;
		flutter_y = sin(TIME * 3.8 + world_pos.x * 1.9 - world_pos.z * 1.7) * 0.030;
		twist_val = (sin(TIME * 7.2 + world_pos.x * 3.5 + world_pos.z * 3.1) * 0.65
			+ cos(TIME * 10.4 - world_pos.y * 4.2 + tree_phase) * 0.35) * 0.072;
	}
	float f_amp = flutter_drive * flutter_w;
	vec3 twist_disp = v_world_nrm * (edge_twist * twist_val * f_amp);

	vec3 total_world_disp = vec3(sway_xz.x, sway_droop_y, sway_xz.y)
		+ react_disp
		+ vec3(wperp.x * flutter_lat * f_amp, flutter_y * f_amp, wperp.y * flutter_lat * f_amp)
		+ twist_disp;

	// Transform world-space displacement back into local space for rotated MultiMeshInstance3D trees
	VERTEX += inverse(mat3(MODEL_MATRIX)) * total_world_disp;
}

void fragment() {
	vec4 tex = texture(leaf_tex, UV);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;

	// Clean double-sided lighting normal
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;

	float luma_c = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float relief = 0.0;
	float waxy_spec = 0.5;

	// Crisp leaf vein & edge micro-bump relief (2 tiny UV taps on desktop; analytical on mobile)
	if (!mobile_mode) {
		vec4 tx_u = texture(leaf_tex, clamp(UV + vec2(0.004, 0.0), vec2(0.0), vec2(1.0)));
		vec4 tx_v = texture(leaf_tex, clamp(UV + vec2(0.0, 0.004), vec2(0.0), vec2(1.0)));
		float lc = luma_c * tex.a;
		float lu = dot(tx_u.rgb, vec3(0.299, 0.587, 0.114)) * tx_u.a;
		float lv = dot(tx_v.rgb, vec3(0.299, 0.587, 0.114)) * tx_v.a;
		float gx = clamp((lu - lc) * 3.8, -0.45, 0.45);
		float gy = clamp((lv - lc) * 3.8, -0.45, 0.45);
		NORMAL = normalize(NORMAL + vec3(-gx, -gy, 0.0) * 0.32);
		relief = clamp((abs(gx) + abs(gy)) * 1.4, 0.0, 1.0);
		waxy_spec = clamp(luma_c * 0.65 + (1.0 - relief) * 0.35, 0.0, 1.0);
	} else {
		float vein_an = abs(sin((UV.x - 0.5) * 18.0 + UV.y * 8.0));
		relief = vein_an * 0.35;
		waxy_spec = clamp(luma_c * 0.70 + (1.0 - vein_an) * 0.30, 0.0, 1.0);
	}

	// Per-tree organic color variation (±7% warm/cool hue & value shift)
	float h_shift = (v_tree_hash - 0.5) * 2.0;
	float h_shift2 = (fract(v_tree_hash * 7.31) - 0.5) * 2.0;
	vec3 tree_var = vec3(1.0 + h_shift * 0.065, 1.0 + h_shift2 * 0.055, 1.0 - h_shift * 0.065)
		* (1.0 + h_shift2 * 0.045);

	// Dappled crown depth & sunlit outer branch tip lift
	float sky_facing = clamp(v_world_nrm.y * 0.5 + 0.5, 0.0, 1.0);
	float crown_depth = mix(0.76, 1.18, sky_facing * 0.65 + v_canopy_h * 0.35);
	float tip_lift = mix(0.92, 1.10, v_tip);

	vec3 col = tex.rgb * COLOR.rgb * tint_color.rgb * tree_var * crown_depth * tip_lift;
	col *= (1.0 - relief * 0.09);

	// View-dependent backlit subsurface scattering (SSS) through thin petals & leaf edges
	vec3 sun_world = normalize(vec3(0.48, 0.72, 0.50));
	vec3 sun_view = normalize((VIEW_MATRIX * vec4(sun_world, 0.0)).xyz);
	float sss_back = pow(clamp(dot(normalize(-VIEW), sun_view), 0.0, 1.0), 2.6);
	float thinness = clamp(0.35 + 0.45 * v_tip + 0.35 * luma_c, 0.0, 1.25);
	float trans_ambient = translucency * (0.38 + 0.62 * sky_facing);
	float trans_sss = translucency * 1.95 * sss_back * thinness;

	ALBEDO = col;
	EMISSION = col * (trans_ambient + trans_sss) + col * vec3(0.14, 0.10, 0.03) * sss_back * translucency * thinness;
	ROUGHNESS = clamp(mix(0.42, 0.72, 1.0 - waxy_spec * 0.75 + relief * 0.25), 0.42, 0.74);
	SPECULAR = mix(0.32, 0.62, waxy_spec);
	METALLIC = 0.02;
}

