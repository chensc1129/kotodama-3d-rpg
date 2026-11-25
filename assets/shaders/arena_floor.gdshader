shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform int stage_id = 0; // 0: sakura_shrine, 1: maple_temple, 2: onigashima_lava, 3: sky_tenshu

varying vec3 v_world_pos;
varying vec3 v_world_nrm;

// Lightweight hash & value noise (mobile WebGL2 friendly)
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
	float v = vnoise(p) * 0.65;
	v += vnoise(p * 2.13 + vec2(7.1, 3.4)) * 0.35;
	return v;
}

// Staggered flagstone / paver tile pattern -> returns vec3(mortar_mask, tile_id_rand, bevel_h)
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
	float cid = hash21(cell);
	return vec3(mortar, cid, bevel);
}

// Rounded river cobble / basalt cell pattern -> returns vec3(crack_mask, cell_rand, dome_h)
vec3 cobble_pattern(vec2 p, float scale) {
	vec2 q = p * scale;
	vec2 i = floor(q);
	vec2 f = fract(q);
	float min_d = 10.0;
	float sec_d = 10.0;
	float cid = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 nb = vec2(float(x), float(y));
			vec2 cell = i + nb;
			vec2 rnd = vec2(hash21(cell), hash21(cell + vec2(19.7, 37.3)));
			vec2 pt = nb + 0.18 + 0.64 * rnd;
			float dist = length(pt - f);
			if (dist < min_d) {
				sec_d = min_d;
				min_d = dist;
				cid = rnd.x;
			} else if (dist < sec_d) {
				sec_d = dist;
			}
		}
	}
	float edge = sec_d - min_d;
	float crack = 1.0 - smoothstep(0.03, 0.11, edge);
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

	vec3 col_a = vec3(0.3);
	vec3 col_b = vec3(0.3);
	vec3 col_c = vec3(0.3);
	vec3 col_d = vec3(0.3);

	float rough_a = 0.8; float rough_b = 0.8; float rough_c = 0.8; float rough_d = 0.8;
	float met_a = 0.0; float met_b = 0.0; float met_c = 0.0; float met_d = 0.0;
	vec3 emi_a = vec3(0.0); vec3 emi_b = vec3(0.0); vec3 emi_c = vec3(0.0); vec3 emi_d = vec3(0.0);
	float bump_h = 0.0;
	float bump_h_x = 0.0;
	float bump_h_z = 0.0;
	float eps = 0.06;

	float n_mid = fbm2(xz * 0.45);
	float n_fine = vnoise(xz * 3.8);

	if (stage_id == 0) {
		// === STAGE 0: SAKURA SHRINE ===
		// A (R): Carved Granite Shrine Flagstones (石畳)
		vec3 st_a = flagstone_pattern(xz, vec2(0.55, 0.72), 0.055);
		vec3 stone_base = mix(vec3(0.30, 0.25, 0.38), vec3(0.42, 0.35, 0.50), st_a.y * 0.7 + n_fine * 0.3);
		col_a = mix(stone_base, vec3(0.16, 0.13, 0.22), st_a.x * 0.85);
		rough_a = mix(0.72, 0.92, st_a.x);
		met_a = 0.08;

		// B (G): Raked Zen Lavender-White Gravel (枯山水・砂利)
		float radial_r = length(xz);
		float rake_wave = sin(radial_r * 5.8 + sin(atan(xz.y, xz.x) * 6.0) * 0.6) * 0.5 + 0.5;
		float gravel_grain = vnoise(xz * 9.5);
		col_b = mix(vec3(0.27, 0.23, 0.34), vec3(0.39, 0.34, 0.46), rake_wave * 0.55 + gravel_grain * 0.45);
		rough_b = 0.93;
		met_b = 0.0;

		// C (B): Polished Dark Slate Pavilion Tiles w/ Sakura-Gold Seam (黒御影石・漆縁)
		vec2 rot_xz = vec2(xz.x + xz.y, xz.x - xz.y) * 0.7071;
		vec3 st_c = flagstone_pattern(rot_xz, vec2(0.68, 0.68), 0.045);
		vec3 slate_col = mix(vec3(0.20, 0.16, 0.28), vec3(0.30, 0.23, 0.39), st_c.y * 0.65 + n_mid * 0.35);
		col_c = mix(slate_col, vec3(0.62, 0.40, 0.54), st_c.x * 0.65);
		rough_c = mix(0.34, 0.60, st_c.x);
		met_c = mix(0.22, 0.40, st_c.x);

		// D (A): Wet Koi Pond River Cobblestones & Moss (川石・苔)
		vec3 cob = cobble_pattern(xz, 0.95);
		vec3 peb_col = mix(vec3(0.08, 0.19, 0.28), vec3(0.16, 0.30, 0.38), cob.y);
		col_d = mix(peb_col, vec3(0.07, 0.22, 0.18), cob.x * 0.85);
		rough_d = 0.18;
		met_d = 0.12;

		bump_h = w.r * st_a.z + w.g * (rake_wave * 0.55 + gravel_grain * 0.25) + w.b * st_c.z + w.a * cob.z;
		bump_h_x = w.r * flagstone_pattern(xz + vec2(eps, 0.0), vec2(0.55, 0.72), 0.055).z
			+ w.g * (sin(length(xz + vec2(eps, 0.0)) * 5.8) * 0.28)
			+ w.b * flagstone_pattern(rot_xz + vec2(eps, eps) * 0.7071, vec2(0.68, 0.68), 0.045).z;
		bump_h_z = w.r * flagstone_pattern(xz + vec2(0.0, eps), vec2(0.55, 0.72), 0.055).z
			+ w.g * (sin(length(xz + vec2(0.0, eps)) * 5.8) * 0.28)
			+ w.b * flagstone_pattern(rot_xz + vec2(eps, -eps) * 0.7071, vec2(0.68, 0.68), 0.045).z;

	} else if (stage_id == 1) {
		// === STAGE 1: MAPLE TEMPLE ===
		// A (R): Aged Mossy Temple Flagstones (古寺の苔敷石)
		vec3 st_a = flagstone_pattern(xz, vec2(0.62, 0.62), 0.075);
		vec3 stone = mix(vec3(0.32, 0.28, 0.24), vec3(0.45, 0.39, 0.33), st_a.y * 0.7 + n_fine * 0.3);
		vec3 moss_grout = vec3(0.14, 0.32, 0.15);
		col_a = mix(stone, moss_grout, st_a.x * 0.90);
		rough_a = mix(0.74, 0.94, st_a.x);
		met_a = 0.04;

		// B (G): Lush Forest Moss & Bamboo Valley Soil (苔生す林地)
		float moss_patch = smoothstep(0.32, 0.72, fbm2(xz * 0.38));
		vec3 earth = mix(vec3(0.22, 0.17, 0.12), vec3(0.30, 0.24, 0.16), n_fine);
		vec3 moss = mix(vec3(0.13, 0.29, 0.16), vec3(0.24, 0.42, 0.20), n_fine);
		col_b = mix(earth, moss, moss_patch);
		rough_b = 0.94;
		met_b = 0.0;

		// C (B): Autumn Fallen Maple Leaf Carpet & Terracotta Soil (紅葉落ち葉)
		vec3 leaf_cells = cobble_pattern(xz, 1.35);
		float is_leaf = smoothstep(0.42, 0.72, leaf_cells.z) * step(0.38, leaf_cells.y);
		vec3 dirt = mix(vec3(0.30, 0.20, 0.14), vec3(0.40, 0.26, 0.17), n_mid);
		vec3 maple_col = mix(vec3(0.78, 0.26, 0.10), vec3(0.92, 0.56, 0.14), fract(leaf_cells.y * 7.3));
		col_c = mix(dirt, maple_col, is_leaf * 0.88);
		rough_c = mix(0.88, 0.66, is_leaf);
		met_c = 0.02;

		// D (A): Wet Dark Gorge Riverbed Slate (渓流の濡れ岩)
		vec3 cob = cobble_pattern(xz, 0.85);
		col_d = mix(vec3(0.08, 0.19, 0.22), vec3(0.16, 0.29, 0.31), cob.y * 0.75 + cob.z * 0.25);
		col_d = mix(col_d, vec3(0.05, 0.12, 0.14), cob.x * 0.8);
		rough_d = 0.16;
		met_d = 0.15;

		bump_h = w.r * st_a.z + w.g * (n_fine * 0.45) + w.b * (leaf_cells.z * 0.4) + w.a * cob.z;
		bump_h_x = w.r * flagstone_pattern(xz + vec2(eps, 0.0), vec2(0.62, 0.62), 0.075).z + w.g * vnoise((xz + vec2(eps, 0.0)) * 3.8) * 0.45;
		bump_h_z = w.r * flagstone_pattern(xz + vec2(0.0, eps), vec2(0.62, 0.62), 0.075).z + w.g * vnoise((xz + vec2(0.0, eps)) * 3.8) * 0.45;

	} else if (stage_id == 2) {
		// === STAGE 2: ONIGASHIMA LAVA ===
		// A (R): Fractured Basalt Columns w/ Faint Ember Veins (玄武岩)
		vec3 bas = cobble_pattern(xz, 0.68);
		vec3 rock = mix(vec3(0.14, 0.12, 0.14), vec3(0.23, 0.20, 0.22), bas.y * 0.7 + n_fine * 0.3);
		float ember_pulse = 0.55 + 0.45 * sin(TIME * 2.4 + bas.y * 6.28);
		col_a = mix(rock, vec3(0.55, 0.18, 0.05), bas.x * 0.75);
		emi_a = vec3(0.95, 0.30, 0.04) * bas.x * 0.42 * ember_pulse;
		rough_a = mix(0.50, 0.85, bas.x);
		met_a = 0.26;

		// B (G): Forged Obsidian Causeway Slabs w/ Bronze Seams (黒曜石参道)
		vec2 diag_xz = vec2(xz.x + xz.y, xz.x - xz.y) * 0.7071;
		vec3 obs = flagstone_pattern(diag_xz, vec2(0.58, 0.82), 0.055);
		vec3 obs_col = mix(vec3(0.16, 0.15, 0.19), vec3(0.26, 0.23, 0.29), obs.y * 0.6 + n_fine * 0.4);
		col_b = mix(obs_col, vec3(0.72, 0.36, 0.14), obs.x * 0.70);
		emi_b = vec3(0.75, 0.26, 0.05) * obs.x * 0.22;
		rough_b = mix(0.38, 0.62, obs.x);
		met_b = mix(0.36, 0.55, obs.x);

		// C (B): Scorched Volcanic Cinder & Ash Crags (火山灰・焦土)
		float strata = sin(v_world_pos.y * 7.5 + n_mid * 4.0) * 0.5 + 0.5;
		col_c = mix(vec3(0.16, 0.09, 0.08), vec3(0.30, 0.15, 0.11), strata * 0.55 + n_fine * 0.45);
		rough_c = 0.92;
		met_c = 0.05;

		// D (A): Flowing Molten Magma Crust (溶岩流)
		vec2 flow_uv = xz * 0.32 + vec2(TIME * 0.10, -TIME * 0.07);
		float mag_n = fbm2(flow_uv + vec2(fbm2(flow_uv * 1.4), 0.0));
		float crust = smoothstep(0.54, 0.74, mag_n);
		vec3 hot_lava = mix(vec3(0.95, 0.28, 0.02), vec3(1.0, 0.78, 0.16), smoothstep(0.22, 0.55, 1.0 - mag_n));
		col_d = mix(hot_lava, vec3(0.15, 0.07, 0.06), crust);
		emi_d = hot_lava * (1.0 - crust) * 1.45;
		rough_d = mix(0.25, 0.85, crust);
		met_d = 0.08;

		bump_h = w.r * bas.z + w.g * obs.z + w.b * (strata * 0.45 + n_fine * 0.35);
		bump_h_x = w.r * cobble_pattern(xz + vec2(eps, 0.0), 0.68).z + w.g * flagstone_pattern(diag_xz + vec2(eps, eps) * 0.7071, vec2(0.58, 0.82), 0.055).z;
		bump_h_z = w.r * cobble_pattern(xz + vec2(0.0, eps), 0.68).z + w.g * flagstone_pattern(diag_xz + vec2(eps, -eps) * 0.7071, vec2(0.58, 0.82), 0.055).z;

	} else {
		// === STAGE 3: SKY TENSHU ===
		// A (R): Polished Indigo Celestial Marble Tiles (瑠璃大理石)
		vec3 mar = flagstone_pattern(xz, vec2(0.42, 0.42), 0.035);
		float vein = smoothstep(0.45, 0.55, sin(xz.x * 1.1 + xz.y * 0.9 + fbm2(xz * 0.6) * 4.5) * 0.5 + 0.5);
		vec3 marble_col = mix(vec3(0.11, 0.19, 0.34), vec3(0.21, 0.33, 0.54), mar.y * 0.5 + vein * 0.5);
		col_a = mix(marble_col, vec3(0.75, 0.62, 0.30), mar.x * 0.78);
		rough_a = mix(0.22, 0.40, mar.x);
		met_a = mix(0.24, 0.58, mar.x);

		// B (G): Imperial Courtyard Geometric Stone Paving (天守中庭石敷)
		vec2 rot45 = vec2(xz.x + xz.y, xz.x - xz.y) * 0.7071;
		vec3 tile = flagstone_pattern(rot45, vec2(0.65, 0.65), 0.048);
		vec3 court_col = mix(vec3(0.16, 0.24, 0.40), vec3(0.25, 0.35, 0.54), tile.y * 0.65 + n_fine * 0.35);
		col_b = mix(court_col, vec3(0.42, 0.50, 0.66), tile.x * 0.72);
		rough_b = mix(0.48, 0.70, tile.x);
		met_b = 0.16;

		// C (B): Gilded Gold-Inlaid Spirit Ramp Stairs (黄金の霊道)
		float axis_coord = (abs(xz.x) > abs(xz.y)) ? abs(xz.x) : abs(xz.y);
		float cross_coord = (abs(xz.x) > abs(xz.y)) ? abs(xz.y) : abs(xz.x);
		float step_line = 1.0 - smoothstep(0.06, 0.14, abs(fract(axis_coord * 1.45) - 0.5));
		float gold_trim = smoothstep(1.55, 1.95, cross_coord);
		vec3 ramp_stone = mix(vec3(0.32, 0.38, 0.52), vec3(0.86, 0.70, 0.26), gold_trim * 0.85);
		col_c = mix(ramp_stone, vec3(0.98, 0.88, 0.45), step_line * 0.75);
		emi_c = vec3(0.96, 0.80, 0.30) * (step_line * 0.28 + gold_trim * 0.22);
		rough_c = mix(0.30, 0.20, max(step_line, gold_trim));
		met_c = mix(0.35, 0.72, max(step_line, gold_trim));

		// D (A): Weathered Castle Ishigaki Masonry Rim (城壁石垣)
		vec3 wall = flagstone_pattern(xz, vec2(0.75, 0.50), 0.065);
		col_d = mix(vec3(0.22, 0.30, 0.46), vec3(0.34, 0.43, 0.59), wall.y * 0.75 + n_fine * 0.25);
		col_d = mix(col_d, vec3(0.11, 0.16, 0.26), wall.x * 0.85);
		rough_d = 0.68;
		met_d = 0.10;

		bump_h = w.r * mar.z + w.g * tile.z + w.b * (1.0 - step_line * 0.6) + w.a * wall.z;
		bump_h_x = w.r * flagstone_pattern(xz + vec2(eps, 0.0), vec2(0.42, 0.42), 0.035).z + w.g * flagstone_pattern(rot45 + vec2(eps, eps) * 0.7071, vec2(0.65, 0.65), 0.048).z + w.a * flagstone_pattern(xz + vec2(eps, 0.0), vec2(0.75, 0.50), 0.065).z;
		bump_h_z = w.r * flagstone_pattern(xz + vec2(0.0, eps), vec2(0.42, 0.42), 0.035).z + w.g * flagstone_pattern(rot45 + vec2(eps, -eps) * 0.7071, vec2(0.65, 0.65), 0.048).z + w.a * flagstone_pattern(xz + vec2(0.0, eps), vec2(0.75, 0.50), 0.065).z;
	}

	vec3 final_col = col_a * w.r + col_b * w.g + col_c * w.b + col_d * w.a;
	float final_rough = rough_a * w.r + rough_b * w.g + rough_c * w.b + rough_d * w.a;
	float final_met = met_a * w.r + met_b * w.g + met_c * w.b + met_d * w.a;
	vec3 final_emi = emi_a * w.r + emi_b * w.g + emi_c * w.b + emi_d * w.a;

	// Steep cliff faces & outer cliff skirt automatically show layered stone rock strata
	float steepness = smoothstep(0.32, 0.68, 1.0 - clamp(v_world_nrm.y, 0.0, 1.0));
	if (steepness > 0.01) {
		float band = sin(v_world_pos.y * 6.5 + n_mid * 3.0) * 0.5 + 0.5;
		vec3 cliff_col = mix(final_col * 0.52, final_col * 0.80, band * 0.65 + n_fine * 0.35);
		final_col = mix(final_col, cliff_col, steepness * 0.82);
		final_rough = mix(final_rough, 0.90, steepness * 0.7);
		final_met *= (1.0 - steepness * 0.7);
	}

	ALBEDO = final_col;
	ROUGHNESS = clamp(final_rough, 0.12, 0.96);
	METALLIC = clamp(final_met, 0.0, 0.85);
	EMISSION = final_emi;

	// World-space analytical micro-bump converted to view space (zero UV seams!)
	float dh_dx = (bump_h_x - bump_h) / eps;
	float dh_dz = (bump_h_z - bump_h) / eps;
	vec3 bumped_world_n = normalize(v_world_nrm + vec3(-dh_dx, 0.0, -dh_dz) * 0.055 * (1.0 - steepness));
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped_world_n, 0.0)).xyz);
}
