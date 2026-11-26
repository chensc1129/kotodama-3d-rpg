shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform int stage_id = 0; // 0: sakura_shrine, 1: maple_temple, 2: onigashima_lava, 3: sky_tenshu, 4: arpg_ch1_landscape
uniform bool mobile_mode = false;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;

// Ultra-fast hash & value noise (mobile WebGL2 friendly)
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm2(vec2 p) {
	return vnoise(p) * 0.65 + vnoise(p * 2.13 + vec2(7.1, 3.4)) * 0.35;
}

// Staggered flagstone / paver tile pattern -> vec3(mortar_mask, tile_id_rand, bevel_h)
vec3 flagstone_pattern(vec2 p, vec2 scale, float mortar_w) {
	vec2 q = p * scale;
	float row = floor(q.y);
	q.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	vec2 d = min(f, 1.0 - f);
	float edge = min(d.x, d.y);
	float mortar = 1.0 - smoothstep(mortar_w * 0.5, mortar_w * 1.35, edge);
	float bevel = smoothstep(0.0, mortar_w * 2.2, edge);
	return vec3(mortar, hash21(cell), bevel);
}

// Fast 4-tap cellular cobble / basalt pattern (2.25x faster than 9-tap Voronoi!)
vec3 cobble_fast(vec2 p, float scale) {
	vec2 q = p * scale;
	vec2 i = floor(q);
	vec2 f = fract(q);
	vec2 o = step(vec2(0.5), f) * 2.0 - 1.0; // Search only the 4 nearest cells!
	float min_d = 10.0;
	float sec_d = 10.0;
	float cid = 0.0;
	for (int k = 0; k < 4; k++) {
		vec2 nb = vec2((k == 1 || k == 3) ? o.x : 0.0, (k >= 2) ? o.y : 0.0);
		vec2 cell = i + nb;
		vec2 rnd = vec2(hash21(cell), hash21(cell + vec2(19.7, 37.3)));
		vec2 pt = nb + 0.20 + 0.60 * rnd;
		float dist = length(pt - f);
		if (dist < min_d) {
			sec_d = min_d;
			min_d = dist;
			cid = rnd.x;
		} else if (dist < sec_d) {
			sec_d = dist;
		}
	}
	float crack = 1.0 - smoothstep(0.03, 0.12, sec_d - min_d);
	float dome = clamp(1.0 - min_d * 1.15, 0.0, 1.0);
	return vec3(crack, cid, dome);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 xz = v_world_pos.xz;
	vec4 w = max(COLOR, vec4(0.0));
	float w_sum = max(w.r + w.g + w.b + w.a, 0.0001);
	w /= w_sum;

	vec3 final_col = vec3(0.0);
	float final_rough = 0.0;
	float final_met = 0.0;
	vec3 final_emi = vec3(0.0);
	float bump_h = 0.0;

	float n_fine = vnoise(xz * 3.6);

	if (stage_id == 0) {
		// === STAGE 0: SAKURA SHRINE ===
		if (w.r > 0.01) {
			vec3 st_a = flagstone_pattern(xz, vec2(0.55, 0.72), 0.055);
			vec3 stone_base = mix(vec3(0.30, 0.25, 0.38), vec3(0.42, 0.35, 0.50), st_a.y * 0.7 + n_fine * 0.3);
			final_col += mix(stone_base, vec3(0.16, 0.13, 0.22), st_a.x * 0.85) * w.r;
			final_rough += mix(0.72, 0.92, st_a.x) * w.r;
			final_met += 0.08 * w.r;
			bump_h += st_a.z * w.r;
		}
		if (w.g > 0.01) {
			float radial_r = length(xz);
			float rake_wave = sin(radial_r * 5.8 + sin(atan(xz.y, xz.x) * 6.0) * 0.6) * 0.5 + 0.5;
			final_col += mix(vec3(0.27, 0.23, 0.34), vec3(0.39, 0.34, 0.46), rake_wave * 0.58 + n_fine * 0.42) * w.g;
			final_rough += 0.93 * w.g;
			bump_h += rake_wave * 0.55 * w.g;
		}
		if (w.b > 0.01) {
			vec2 rot_xz = vec2(xz.x + xz.y, xz.x - xz.y) * 0.7071;
			vec3 st_c = flagstone_pattern(rot_xz, vec2(0.68, 0.68), 0.045);
			vec3 slate_col = mix(vec3(0.20, 0.16, 0.28), vec3(0.30, 0.23, 0.39), st_c.y * 0.7 + n_fine * 0.3);
			final_col += mix(slate_col, vec3(0.62, 0.40, 0.54), st_c.x * 0.65) * w.b;
			final_rough += mix(0.34, 0.60, st_c.x) * w.b;
			final_met += mix(0.22, 0.40, st_c.x) * w.b;
			bump_h += st_c.z * w.b;
		}
		if (w.a > 0.01) {
			vec3 cob = cobble_fast(xz, 0.95);
			vec3 peb_col = mix(vec3(0.08, 0.19, 0.28), vec3(0.16, 0.30, 0.38), cob.y);
			final_col += mix(peb_col, vec3(0.07, 0.22, 0.18), cob.x * 0.85) * w.a;
			final_rough += 0.18 * w.a;
			final_met += 0.12 * w.a;
			bump_h += cob.z * w.a;
		}

	} else if (stage_id == 1) {
		// === STAGE 1: MAPLE TEMPLE ===
		if (w.r > 0.01) {
			vec3 st_a = flagstone_pattern(xz, vec2(0.62, 0.62), 0.075);
			vec3 stone = mix(vec3(0.32, 0.28, 0.24), vec3(0.45, 0.39, 0.33), st_a.y * 0.7 + n_fine * 0.3);
			final_col += mix(stone, vec3(0.14, 0.32, 0.15), st_a.x * 0.90) * w.r;
			final_rough += mix(0.74, 0.94, st_a.x) * w.r;
			final_met += 0.04 * w.r;
			bump_h += st_a.z * w.r;
		}
		if (w.g > 0.01) {
			float moss_patch = smoothstep(0.30, 0.72, vnoise(xz * 0.42));
			vec3 earth = mix(vec3(0.22, 0.17, 0.12), vec3(0.30, 0.24, 0.16), n_fine);
			vec3 moss = mix(vec3(0.13, 0.29, 0.16), vec3(0.24, 0.42, 0.20), n_fine);
			final_col += mix(earth, moss, moss_patch) * w.g;
			final_rough += 0.94 * w.g;
		}
		if (w.b > 0.01) {
			vec3 leaf_cells = cobble_fast(xz, 1.30);
			float is_leaf = smoothstep(0.42, 0.72, leaf_cells.z) * step(0.38, leaf_cells.y);
			vec3 dirt = mix(vec3(0.30, 0.20, 0.14), vec3(0.40, 0.26, 0.17), n_fine);
			vec3 maple_col = mix(vec3(0.78, 0.26, 0.10), vec3(0.92, 0.56, 0.14), fract(leaf_cells.y * 7.3));
			final_col += mix(dirt, maple_col, is_leaf * 0.88) * w.b;
			final_rough += mix(0.88, 0.66, is_leaf) * w.b;
			final_met += 0.02 * w.b;
		}
		if (w.a > 0.01) {
			vec3 cob = cobble_fast(xz, 0.85);
			vec3 rcol = mix(vec3(0.08, 0.19, 0.22), vec3(0.16, 0.29, 0.31), cob.y * 0.75 + cob.z * 0.25);
			final_col += mix(rcol, vec3(0.05, 0.12, 0.14), cob.x * 0.8) * w.a;
			final_rough += 0.16 * w.a;
			final_met += 0.15 * w.a;
		}

	} else if (stage_id == 2) {
		// === STAGE 2: ONIGASHIMA LAVA ===
		if (w.r > 0.01) {
			vec3 bas = cobble_fast(xz, 0.65);
			vec3 rock = mix(vec3(0.14, 0.12, 0.14), vec3(0.23, 0.20, 0.22), bas.y * 0.7 + n_fine * 0.3);
			float ember_pulse = 0.55 + 0.45 * sin(TIME * 2.4 + bas.y * 6.28);
			final_col += mix(rock, vec3(0.55, 0.18, 0.05), bas.x * 0.75) * w.r;
			final_emi += vec3(0.95, 0.30, 0.04) * bas.x * 0.42 * ember_pulse * w.r;
			final_rough += mix(0.50, 0.85, bas.x) * w.r;
			final_met += 0.26 * w.r;
			bump_h += bas.z * w.r;
		}
		if (w.g > 0.01) {
			vec2 diag_xz = vec2(xz.x + xz.y, xz.x - xz.y) * 0.7071;
			vec3 obs = flagstone_pattern(diag_xz, vec2(0.58, 0.82), 0.055);
			vec3 obs_col = mix(vec3(0.16, 0.15, 0.19), vec3(0.26, 0.23, 0.29), obs.y * 0.6 + n_fine * 0.4);
			final_col += mix(obs_col, vec3(0.72, 0.36, 0.14), obs.x * 0.70) * w.g;
			final_emi += vec3(0.75, 0.26, 0.05) * obs.x * 0.22 * w.g;
			final_rough += mix(0.38, 0.62, obs.x) * w.g;
			final_met += mix(0.36, 0.55, obs.x) * w.g;
			bump_h += obs.z * w.g;
		}
		if (w.b > 0.01) {
			float strata = sin(v_world_pos.y * 7.5 + n_fine * 3.0) * 0.5 + 0.5;
			final_col += mix(vec3(0.16, 0.09, 0.08), vec3(0.30, 0.15, 0.11), strata * 0.55 + n_fine * 0.45) * w.b;
			final_rough += 0.92 * w.b;
			final_met += 0.05 * w.b;
		}
		if (w.a > 0.01) {
			vec2 flow_uv = xz * 0.32 + vec2(TIME * 0.10, -TIME * 0.07);
			float mag_n = fbm2(flow_uv);
			float crust = smoothstep(0.54, 0.74, mag_n);
			vec3 hot_lava = mix(vec3(0.95, 0.28, 0.02), vec3(1.0, 0.78, 0.16), smoothstep(0.22, 0.55, 1.0 - mag_n));
			final_col += mix(hot_lava, vec3(0.15, 0.07, 0.06), crust) * w.a;
			final_emi += hot_lava * (1.0 - crust) * 1.45 * w.a;
			final_rough += mix(0.25, 0.85, crust) * w.a;
			final_met += 0.08 * w.a;
		}

	} else if (stage_id == 3) {
		// === STAGE 3: SKY TENSHU ===
		if (w.r > 0.01) {
			vec3 mar = flagstone_pattern(xz, vec2(0.42, 0.42), 0.035);
			float vein = smoothstep(0.42, 0.58, sin(xz.x * 1.1 + xz.y * 0.9 + n_fine * 3.2) * 0.5 + 0.5);
			vec3 marble_col = mix(vec3(0.13, 0.22, 0.39), vec3(0.24, 0.37, 0.59), mar.y * 0.5 + vein * 0.5);
			final_col += mix(marble_col, vec3(0.82, 0.68, 0.32), mar.x * 0.82) * w.r;
			final_rough += mix(0.24, 0.42, mar.x) * w.r;
			final_met += mix(0.24, 0.58, mar.x) * w.r;
			bump_h += mar.z * w.r;
		}
		if (w.g > 0.01) {
			vec2 rot45 = vec2(xz.x + xz.y, xz.x - xz.y) * 0.7071;
			vec3 tile = flagstone_pattern(rot45, vec2(0.65, 0.65), 0.048);
			vec3 court_col = mix(vec3(0.18, 0.27, 0.45), vec3(0.28, 0.39, 0.58), tile.y * 0.65 + n_fine * 0.35);
			final_col += mix(court_col, vec3(0.48, 0.58, 0.74), tile.x * 0.72) * w.g;
			final_rough += mix(0.48, 0.70, tile.x) * w.g;
			final_met += 0.16 * w.g;
			bump_h += tile.z * w.g;
		}
		if (w.b > 0.01) {
			float axis_coord = (abs(xz.x) > abs(xz.y)) ? abs(xz.x) : abs(xz.y);
			float cross_coord = (abs(xz.x) > abs(xz.y)) ? abs(xz.y) : abs(xz.x);
			float step_line = 1.0 - smoothstep(0.06, 0.14, abs(fract(axis_coord * 1.45) - 0.5));
			float gold_trim = smoothstep(1.55, 1.95, cross_coord);
			vec3 ramp_stone = mix(vec3(0.32, 0.38, 0.52), vec3(0.86, 0.70, 0.26), gold_trim * 0.85);
			final_col += mix(ramp_stone, vec3(0.98, 0.88, 0.45), step_line * 0.75) * w.b;
			final_emi += vec3(0.96, 0.80, 0.30) * (step_line * 0.24 + gold_trim * 0.18) * w.b;
			final_rough += mix(0.30, 0.20, max(step_line, gold_trim)) * w.b;
			final_met += mix(0.35, 0.72, max(step_line, gold_trim)) * w.b;
		}
		if (w.a > 0.01) {
			vec3 wall = flagstone_pattern(xz, vec2(0.75, 0.50), 0.065);
			vec3 wcol = mix(vec3(0.22, 0.30, 0.46), vec3(0.34, 0.43, 0.59), wall.y * 0.75 + n_fine * 0.25);
			final_col += mix(wcol, vec3(0.11, 0.16, 0.26), wall.x * 0.85) * w.a;
			final_rough += 0.68 * w.a;
			final_met += 0.10 * w.a;
			bump_h += wall.z * w.a;
		}

	} else {
		// === STAGE 4: ARPG CHAPTER 1 NATURAL JAPANESE LANDSCAPE ===
		if (w.r > 0.01) {
			// Warm weathered Japanese granite flagstones with mossy dark crevices & bevel highlights
			vec3 st_g = flagstone_pattern(xz, vec2(0.56, 0.70), 0.062);
			vec3 granite = mix(vec3(0.45, 0.41, 0.35), vec3(0.61, 0.56, 0.48), st_g.y * 0.65 + n_fine * 0.35);
			float bevel_hi = st_g.z * (1.0 - st_g.x);
			granite += vec3(0.055, 0.048, 0.038) * bevel_hi;
			float moss_cr = smoothstep(0.34, 0.74, vnoise(xz * 0.85 + vec2(2.3, -1.7)));
			vec3 crevice = mix(vec3(0.15, 0.14, 0.12), vec3(0.14, 0.31, 0.13), moss_cr);
			final_col += mix(granite, crevice, st_g.x * 0.90) * w.r;
			final_rough += mix(0.70, 0.94, st_g.x) * w.r;
			final_met += 0.05 * w.r;
			bump_h += st_g.z * w.r;
		}
		if (w.g > 0.01) {
			// Lush emerald meadow grass & organic mossy woodland soil with soft wildflower moss variation
			float macro_n = mobile_mode ? vnoise(xz * 0.24) : fbm2(xz * 0.22);
			vec3 turf = mix(vec3(0.14, 0.34, 0.14), vec3(0.26, 0.48, 0.18), clamp(macro_n * 0.62 + n_fine * 0.38, 0.0, 1.0));
			float soil_n = mobile_mode ? vnoise(xz * 0.38 + vec2(4.3, -2.7)) : fbm2(xz * 0.36 + vec2(4.3, -2.7));
			float soil_mask = smoothstep(0.62, 0.84, soil_n);
			vec3 wood_soil = mix(vec3(0.22, 0.17, 0.11), vec3(0.31, 0.24, 0.15), n_fine);
			vec3 meadow = mix(turf, wood_soil, soil_mask * 0.72);
			float wf_moss = smoothstep(0.62, 0.88, vnoise(xz * 1.45 + vec2(-3.1, 5.2)));
			meadow = mix(meadow, vec3(0.34, 0.52, 0.20), wf_moss * (1.0 - soil_mask) * 0.36);
			final_col += meadow * w.g;
			final_rough += 0.90 * w.g;
			final_met += 0.01 * w.g;
			bump_h += (n_fine * 0.40 + macro_n * 0.25) * w.g;
		}
		if (w.b > 0.01) {
			// Golden-ivory sandy beach with wind-rippled micro-waves, mineral sparkle & automatic wet-sand darkening
			float sand_warp = mobile_mode ? vnoise(xz * 0.6) : fbm2(xz * 0.6);
			float ripple = sin(xz.x * 4.5 + sand_warp * 3.5) * 0.5 + 0.5;
			vec3 sand_col = mix(vec3(0.76, 0.67, 0.48), vec3(0.88, 0.79, 0.58), ripple * 0.55 + n_fine * 0.45);
			// Safe WebGL2 smoothstep (edge0 < edge1) matching smoothstep(0.05, -0.45, y)
			float wet = 1.0 - smoothstep(-0.45, 0.05, v_world_pos.y);
			float sparkle = mobile_mode ? 0.0 : smoothstep(0.88, 0.99, hash21(floor(xz * 18.0))) * (1.0 - wet * 0.65);
			sand_col += vec3(0.18, 0.16, 0.11) * sparkle;
			sand_col *= mix(1.0, 0.58, wet);
			final_col += sand_col * w.b;
			final_rough += mix(0.90, 0.26, wet) * w.b;
			final_met += mix(0.02, 0.12, wet) * w.b;
			bump_h += ripple * 0.42 * (1.0 - wet * 0.5) * w.b;
		}
		if (w.a > 0.01) {
			if (v_world_pos.y < 1.2) {
				// Smooth underwater river / lakebed pebbles with wet teal-slate sheen
				vec3 cob = cobble_fast(xz, 0.92);
				vec3 peb = mix(vec3(0.09, 0.21, 0.25), vec3(0.19, 0.33, 0.37), cob.y * 0.72 + cob.z * 0.28);
				final_col += mix(peb, vec3(0.06, 0.14, 0.16), cob.x * 0.84) * w.a;
				final_rough += 0.20 * w.a;
				final_met += 0.14 * w.a;
				bump_h += cob.z * 0.65 * w.a;
			} else {
				// Elevated North Grand Altar: polished dark twilight shrine slate with faint sakura-gold mortar seams
				vec2 rot_xz = vec2(xz.x + xz.y, xz.x - xz.y) * 0.7071;
				vec3 altar = flagstone_pattern(rot_xz, vec2(0.62, 0.62), 0.042);
				vec3 slate = mix(vec3(0.14, 0.13, 0.22), vec3(0.24, 0.21, 0.33), altar.y * 0.68 + n_fine * 0.32);
				vec3 seam = mix(vec3(0.78, 0.54, 0.48), vec3(0.92, 0.74, 0.42), 0.5 + 0.5 * sin(xz.x * 0.45 + xz.y * 0.45));
				final_col += mix(slate, seam, altar.x * 0.74) * w.a;
				final_emi += vec3(0.74, 0.48, 0.36) * altar.x * 0.14 * w.a;
				final_rough += mix(0.28, 0.48, altar.x) * w.a;
				final_met += mix(0.22, 0.48, altar.x) * w.a;
				bump_h += altar.z * w.a;
			}
		}
	}

	// Steep cliff faces & outer cliff skirt automatically show layered stone rock strata
	float steepness = smoothstep(0.32, 0.68, 1.0 - clamp(v_world_nrm.y, 0.0, 1.0));
	if (steepness > 0.01) {
		float band = sin(v_world_pos.y * 6.5 + n_fine * 2.5) * 0.5 + 0.5;
		vec3 cliff_col = mix(final_col * 0.52, final_col * 0.80, band * 0.65 + n_fine * 0.35);
		final_col = mix(final_col, cliff_col, steepness * 0.82);
		final_rough = mix(final_rough, 0.90, steepness * 0.7);
		final_met *= (1.0 - steepness * 0.7);
	}

	ALBEDO = final_col;
	ROUGHNESS = clamp(final_rough, 0.12, 0.96);
	METALLIC = clamp(final_met, 0.0, 0.85);
	EMISSION = final_emi;

	// Zero-extra-sample screen-space micro-bump on desktop; pure smooth normals on mobile!
	if (!mobile_mode && steepness < 0.8) {
		float bx = clamp(dFdx(bump_h), -0.35, 0.35);
		float by = clamp(dFdy(bump_h), -0.35, 0.35);
		NORMAL = normalize(NORMAL + vec3(-bx, -by, 0.0) * 0.45 * (1.0 - steepness));
	}
}
