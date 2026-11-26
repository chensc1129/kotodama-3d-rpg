shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// High-craft procedural material shader for Japanese trees, blossoms, clay tile roofs,
// carved granite lanterns/boulders, plaster walls, and bamboo groves.
// Uses vertex COLOR.rgb for per-part shading/AO/gradients + procedural surface grain.
uniform int surface_mode = 0; // 0: bark/wood, 1: sakura/maple foliage, 2: kawara roof tiles, 3: carved/mossy stone, 4: stucco/lacquer, 5: bamboo
uniform vec4 base_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float roughness_base : hint_range(0.10, 1.0) = 0.72;
uniform float metallic_base : hint_range(0.0, 1.0) = 0.04;
uniform float moss_amount : hint_range(0.0, 1.0) = 0.0;
uniform bool mobile_mode = false;

varying vec3 v_local_pos;
varying vec3 v_world_pos;
varying vec3 v_world_nrm;
varying vec3 v_vcol;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.53);
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

void vertex() {
	v_local_pos = VERTEX;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_vcol = COLOR.rgb;
}

void fragment() {
	vec3 col = v_vcol * base_tint.rgb;
	float rough = roughness_base;
	float met = metallic_base;
	vec3 emi = vec3(0.0);
	float up = clamp(v_world_nrm.y, -1.0, 1.0);

	if (surface_mode == 0) {
		// Organic tree bark & aged cedar timber vertical grain
		vec2 uv_b = vec2(atan(v_local_pos.z, v_local_pos.x) * 2.4 + v_world_pos.x * 1.4, v_world_pos.y * 1.9);
		float n1 = vnoise(uv_b * vec2(4.2, 1.3));
		float ridge = sin(uv_b.x * 9.5 + n1 * 4.5) * 0.5 + 0.5;
		float grain = mobile_mode ? ridge : (ridge * 0.65 + vnoise(uv_b * 9.0) * 0.35);
		col *= mix(0.76, 1.14, grain);
		// Subtle cool mossy shadow near ground base
		if (moss_amount > 0.01) {
			float m_mask = smoothstep(0.45, 0.85, up) * moss_amount;
			col = mix(col, vec3(0.24, 0.42, 0.22), m_mask * 0.55);
		}
		rough = mix(0.94, 0.72, grain);
	} else if (surface_mode == 1) {
		// Velvety dappled sakura / maple blossom foliage
		vec2 p1 = v_world_pos.xz * 2.6 + vec2(v_world_pos.y * 1.9, -v_world_pos.y * 1.3);
		float petal = vnoise(p1);
		if (!mobile_mode) {
			petal = petal * 0.65 + vnoise(p1 * 2.4 + 3.1) * 0.35;
		}
		// Dappled blossom sparkle + soft top-down moonlight bounce
		float crown_lift = smoothstep(-0.35, 0.85, up);
		col = mix(col * 0.76, col * 1.18 + vec3(0.06, 0.05, 0.06), crown_lift * 0.72 + petal * 0.28);
		emi = col * (0.08 + crown_lift * 0.10) * smoothstep(0.35, 0.85, petal);
		rough = mix(0.68, 0.46, petal);
	} else if (surface_mode == 2) {
		// Traditional Japanese Kawara clay roof tiles (ribbed flutes + overlapping courses)
		vec2 p = v_local_pos.xz;
		float rib_a = sin(p.x * 13.5) * 0.5 + 0.5;
		float rib_b = sin(p.y * 13.5) * 0.5 + 0.5;
		// Choose dominant slope axis using local normal so hipped & gabled roofs both align cleanly
		float slope_x = step(abs(v_world_nrm.x), abs(v_world_nrm.z));
		float rib = mix(rib_b, rib_a, slope_x);
		float course_coord = mix(p.x, p.y, slope_x) * 3.2;
		float course = smoothstep(0.0, 0.16, fract(course_coord));
		float tile_n = mobile_mode ? 0.5 : vnoise(p * 2.8);
		float shade = (0.76 + 0.28 * rib) * mix(0.74, 1.06, course);
		col *= shade * mix(0.92, 1.08, tile_n);
		rough = mix(0.64, 0.34, rib * course);
		met = mix(0.08, 0.24, rib);
	} else if (surface_mode == 3) {
		// Carved granite & mossy boulder texture
		vec2 p = v_world_pos.xz * 2.4 + vec2(v_world_pos.y * 1.7, 0.0);
		float speck = vnoise(p * 3.0);
		float strata = mobile_mode ? speck : (speck * 0.6 + vnoise(p * 7.5) * 0.4);
		col *= mix(0.78, 1.15, strata);
		if (moss_amount > 0.01) {
			float moss_n = vnoise(v_world_pos.xz * 1.8 + 4.7);
			float m = smoothstep(0.42, 0.82, up + (moss_n - 0.5) * 0.45) * moss_amount;
			col = mix(col, vec3(0.24, 0.44, 0.20) * (0.85 + 0.3 * strata), m);
			rough = mix(rough, 0.94, m);
		} else {
			rough = mix(0.88, 0.66, strata);
		}
	} else if (surface_mode == 4) {
		// Hand-troweled shikkui lime plaster & polished cedar lacquer
		float n = vnoise(v_world_pos.xz * 2.2 + v_world_pos.y * 1.8);
		col *= mix(0.91, 1.07, n);
		rough = mix(roughness_base + 0.08, max(0.18, roughness_base - 0.10), n);
	} else {
		// Glossy bamboo culm & delicate bamboo leaves
		float fiber = sin(atan(v_local_pos.z, v_local_pos.x) * 14.0 + v_world_pos.y * 0.6) * 0.5 + 0.5;
		float leaf_var = vnoise(v_world_pos.xz * 2.8 + v_world_pos.y * 1.5);
		col *= mix(0.84, 1.16, fiber * 0.55 + leaf_var * 0.45);
		rough = mix(0.56, 0.32, fiber);
	}

	ALBEDO = clamp(col, vec3(0.0), vec3(1.5));
	ROUGHNESS = rough;
	METALLIC = met;
	EMISSION = emi;
}
