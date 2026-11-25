shader_type sky;

uniform int stage_id = 0; // 0: sakura_shrine, 1: maple_temple, 2: onigashima_lava, 3: sky_tenshu
uniform bool mobile_mode = false;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm2(vec2 p) {
	return vnoise(p) * 0.66 + vnoise(p * 2.15 + vec2(5.3, 1.7)) * 0.34;
}

float star_layer(vec2 uv, float density, float t) {
	vec2 gv = fract(uv) - 0.5;
	vec2 id = floor(uv);
	float rnd = hash21(id);
	if (rnd < density) {
		return 0.0;
	}
	vec2 off = vec2(hash21(id + 7.1) - 0.5, hash21(id + 13.7) - 0.5) * 0.62;
	float d = length(gv - off);
	float size = mix(0.04, 0.12, fract(rnd * 37.3));
	float twinkle = 0.62 + 0.38 * sin(t * (1.8 + fract(rnd * 19.1) * 3.5) + rnd * 62.8);
	return smoothstep(size, 0.0, d) * twinkle;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float y = dir.y;
	float az = atan(dir.x, -dir.z);
	float up_t = clamp(y, 0.0, 1.0);
	float horizon_glow = exp(-abs(y) * 5.2);

	vec2 sky_uv = dir.xz / max(abs(y) + 0.22, 0.22);
	vec3 col = vec3(0.05, 0.07, 0.14);

	if (stage_id == 0) {
		// === STAGE 0: SAKURA SHRINE ===
		vec3 zenith = vec3(0.035, 0.05, 0.16);
		vec3 mid_sky = vec3(0.16, 0.09, 0.28);
		vec3 hor_col = vec3(0.56, 0.22, 0.42);
		vec3 lower = vec3(0.06, 0.05, 0.13);

		col = mix(hor_col, mid_sky, smoothstep(0.0, 0.34, up_t));
		col = mix(col, zenith, smoothstep(0.24, 0.85, up_t));
		if (y < 0.0) {
			col = mix(hor_col * 0.72, lower, smoothstep(0.0, 0.35, -y));
		}

		float star_mask = smoothstep(0.05, 0.32, y);
		if (star_mask > 0.01) {
			float stars = star_layer(vec2(az * 9.0, y * 14.0), 0.90, TIME);
			if (!mobile_mode) {
				stars += star_layer(vec2(az * 18.0 + 4.2, y * 26.0), 0.94, TIME * 1.3) * 0.75;
			}
			float milky_band = exp(-pow((y - 0.42 - sin(az * 1.4 + 0.5) * 0.22) * 5.2, 2.0));
			float milky_dust = vnoise(vec2(az * 3.5, y * 8.0) + vec2(TIME * 0.015, 0.0));
			col += vec3(0.98, 0.88, 0.96) * stars * star_mask * 1.15;
			col += vec3(0.76, 0.42, 0.74) * milky_band * milky_dust * star_mask * 0.42;
		}

		if (y > 0.01 && y < 0.88) {
			float c_n = fbm2(sky_uv * 0.65 + vec2(TIME * 0.018, -TIME * 0.008));
			float cloud = smoothstep(0.47, 0.75, c_n) * smoothstep(0.01, 0.16, y) * smoothstep(0.88, 0.22, y);
			vec3 c_col = mix(vec3(0.32, 0.19, 0.44), vec3(0.95, 0.66, 0.82), smoothstep(0.48, 0.78, c_n));
			col = mix(col, c_col, cloud * 0.52);
		}

		vec3 moon_dir = normalize(vec3(-0.34, 0.36, -0.87));
		float md = dot(dir, moon_dir);
		float moon_disc = smoothstep(0.9945, 0.9965, md);
		float moon_halo = pow(max(md, 0.0), 18.0) * 0.45 + pow(max(md, 0.0), 120.0) * 0.75;
		col += vec3(0.98, 0.82, 0.90) * moon_halo;
		col = mix(col, vec3(1.0, 0.96, 0.94), moon_disc);

		if (y > -0.04 && y < 0.25) {
			float fuji = exp(-pow((az - 0.18) * 3.8, 2.0)) * 0.13;
			float mtn_h = 0.03 + 0.045 * sin(az * 3.0 + 0.6) + 0.025 * cos(az * 7.0) + fuji;
			float mtn_mask = 1.0 - smoothstep(mtn_h - 0.008, mtn_h + 0.006, y);
			vec3 mtn_col = mix(vec3(0.11, 0.07, 0.20), vec3(0.28, 0.14, 0.30), smoothstep(0.0, 0.14, y));
			col = mix(col, mtn_col, mtn_mask * 0.85);
		}

	} else if (stage_id == 1) {
		// === STAGE 1: MAPLE TEMPLE ===
		vec3 zenith = vec3(0.11, 0.08, 0.24);
		vec3 mid_sky = vec3(0.72, 0.24, 0.16);
		vec3 hor_col = vec3(1.0, 0.68, 0.32);
		vec3 lower = vec3(0.18, 0.09, 0.07);

		col = mix(hor_col, mid_sky, smoothstep(0.0, 0.32, up_t));
		col = mix(col, zenith, smoothstep(0.26, 0.85, up_t));
		if (y < 0.0) {
			col = mix(hor_col * 0.68, lower, smoothstep(0.0, 0.35, -y));
		}

		vec3 sun_dir = normalize(vec3(0.18, 0.16, -0.97));
		float sd = dot(dir, sun_dir);
		float sun_disc = smoothstep(0.9925, 0.9955, sd);
		float sun_halo = pow(max(sd, 0.0), 8.0) * 0.48 + pow(max(sd, 0.0), 64.0) * 0.72;
		col += vec3(1.0, 0.74, 0.36) * sun_halo;
		col = mix(col, vec3(1.0, 0.96, 0.80), sun_disc);

		if (y > 0.01 && y < 0.84) {
			float c1 = fbm2(vec2(sky_uv.x * 0.45 + TIME * 0.022, sky_uv.y * 0.85 - TIME * 0.008));
			float c_band = smoothstep(0.44, 0.74, c1) * smoothstep(0.02, 0.16, y) * smoothstep(0.84, 0.25, y);
			vec3 cloud_lit = mix(vec3(0.45, 0.16, 0.20), vec3(1.0, 0.76, 0.40), smoothstep(0.44, 0.72, c1) * (0.6 + 0.4 * max(sd, 0.0)));
			col = mix(col, cloud_lit, c_band * 0.72);
		}

		if (y > 0.32) {
			float dusk_stars = star_layer(vec2(az * 10.0, y * 14.0), 0.93, TIME) * smoothstep(0.32, 0.68, y);
			col += vec3(1.0, 0.93, 0.80) * dusk_stars * 0.85;
		}

		if (y > -0.06 && y < 0.16) {
			float far_mtn = 0.075 + 0.04 * sin(az * 4.0 + 1.2) + 0.02 * cos(az * 9.0);
			float near_mtn = 0.035 + 0.03 * sin(az * 5.0 - 0.7) + 0.018 * sin(az * 11.0);
			float far_m = 1.0 - smoothstep(far_mtn - 0.008, far_mtn + 0.008, y);
			float near_m = 1.0 - smoothstep(near_mtn - 0.006, near_mtn + 0.006, y);
			col = mix(col, vec3(0.36, 0.14, 0.14), far_m * 0.68);
			col = mix(col, vec3(0.18, 0.08, 0.09), near_m * 0.88);
		}

	} else if (stage_id == 2) {
		// === STAGE 2: ONIGASHIMA LAVA ===
		vec3 zenith = vec3(0.05, 0.02, 0.04);
		vec3 mid_sky = vec3(0.28, 0.06, 0.07);
		vec3 hor_col = vec3(0.92, 0.28, 0.06);
		vec3 lower = vec3(0.22, 0.05, 0.02);

		col = mix(hor_col, mid_sky, smoothstep(0.0, 0.30, up_t));
		col = mix(col, zenith, smoothstep(0.22, 0.80, up_t));
		if (y < 0.0) {
			col = mix(hor_col * 0.75, lower, smoothstep(0.0, 0.35, -y));
		}

		if (y > 0.01 && y < 0.92) {
			float storm = fbm2(sky_uv * 0.75 + vec2(TIME * 0.032, TIME * 0.015));
			float c_mask = smoothstep(0.38, 0.72, storm) * smoothstep(0.01, 0.14, y) * smoothstep(0.92, 0.20, y);
			float lightning = pow(max(sin(TIME * 2.1 + az * 3.0) * sin(TIME * 5.7), 0.0), 14.0);
			vec3 cloud_c = mix(vec3(0.12, 0.04, 0.05), vec3(0.85, 0.24, 0.06), smoothstep(0.35, 0.65, 1.0 - y) * storm);
			cloud_c += vec3(1.0, 0.68, 0.30) * lightning * 0.55;
			col = mix(col, cloud_c, c_mask * 0.78);
		}

		vec3 ecl_dir = normalize(vec3(0.0, 0.34, -0.94));
		float ed = dot(dir, ecl_dir);
		float corona = pow(max(ed, 0.0), 14.0) * 0.55 + smoothstep(0.986, 0.9945, ed) * 1.15;
		float core = smoothstep(0.9938, 0.9952, ed);
		col += vec3(1.0, 0.34, 0.06) * corona;
		col = mix(col, vec3(0.04, 0.01, 0.02), core);

		if (y > -0.05 && y < 0.16) {
			float jag = 0.045 + abs(sin(az * 4.5 + 0.4)) * 0.065 + abs(cos(az * 9.0)) * 0.03;
			float peak_m = 1.0 - smoothstep(jag - 0.005, jag + 0.005, y);
			col = mix(col, vec3(0.09, 0.03, 0.03), peak_m * 0.92);
		}

	} else {
		// === STAGE 3: SKY TENSHU ===
		vec3 zenith = vec3(0.02, 0.05, 0.16);
		vec3 mid_sky = vec3(0.07, 0.18, 0.38);
		vec3 hor_col = vec3(0.32, 0.52, 0.78);
		vec3 cloud_sea_col = vec3(0.22, 0.34, 0.56);

		col = mix(hor_col, mid_sky, smoothstep(0.0, 0.34, up_t));
		col = mix(col, zenith, smoothstep(0.24, 0.86, up_t));

		if (y > 0.06) {
			float wave = sin(az * 3.0 + TIME * 0.35 + sin(az * 6.0 - TIME * 0.25) * 0.8);
			float curtain = exp(-pow((y - 0.36 - wave * 0.10) * 6.5, 2.0));
			float shimmer = vnoise(vec2(az * 5.0 + TIME * 0.08, y * 9.0 - TIME * 0.06));
			vec3 aur_col = mix(vec3(0.16, 0.88, 0.82), vec3(0.98, 0.82, 0.32), smoothstep(0.28, 0.62, shimmer));
			col += aur_col * curtain * shimmer * smoothstep(0.06, 0.22, y) * 0.62;

			float s_mask = smoothstep(0.06, 0.28, y);
			float stars = star_layer(vec2(az * 10.0, y * 15.0), 0.88, TIME);
			if (!mobile_mode) {
				stars += star_layer(vec2(az * 20.0 + 3.1, y * 28.0), 0.93, TIME * 1.4) * 0.8;
			}
			col += vec3(0.95, 0.97, 1.0) * stars * s_mask * 1.25;
		}

		vec3 moon_dir = normalize(vec3(0.0, 0.41, -0.91));
		float md = dot(dir, moon_dir);
		col += vec3(1.0, 0.92, 0.62) * (pow(max(md, 0.0), 10.0) * 0.42 + pow(max(md, 0.0), 65.0) * 0.55);

		float sea_t = smoothstep(0.08, -0.14, y);
		if (sea_t > 0.001) {
			vec2 sea_uv = dir.xz / max(abs(y) + 0.18, 0.18);
			float sea_n = fbm2(sea_uv * 0.55 + vec2(TIME * 0.016, -TIME * 0.012));
			vec3 sea_lit = mix(cloud_sea_col * 0.65, vec3(0.76, 0.86, 0.98), smoothstep(0.32, 0.76, sea_n));
			sea_lit += vec3(0.98, 0.86, 0.52) * pow(max(md, 0.0), 4.0) * 0.25;
			col = mix(col, sea_lit, sea_t * 0.92);
		}
	}

	col += vec3(0.08, 0.06, 0.08) * horizon_glow;
	COLOR = col;
}
