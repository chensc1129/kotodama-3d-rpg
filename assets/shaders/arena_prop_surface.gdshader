shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform int surface_type = 0; // 0: wood planks, 1: radial carved stone, 2: obsidian plate, 3: celestial marble, 4: molten lava
uniform vec4 albedo_a : source_color = vec4(0.45, 0.22, 0.14, 1.0);
uniform vec4 albedo_b : source_color = vec4(0.32, 0.14, 0.10, 1.0);
uniform vec4 accent_color : source_color = vec4(0.95, 0.78, 0.35, 1.0);
uniform float roughness_val : hint_range(0.08, 1.0) = 0.55;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.15;
uniform float emission_strength : hint_range(0.0, 4.0) = 0.0;
uniform float tile_scale : hint_range(0.2, 12.0) = 2.0;

varying vec3 v_local_pos;
varying vec3 v_world_pos;
varying vec3 v_world_nrm;

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
}

void fragment() {
	vec3 col = albedo_a.rgb;
	float rough = roughness_val;
	float met = metallic_val;
	vec3 emi = vec3(0.0);

	if (surface_type == 0) {
		// Wooden bridge planks with transverse slat gaps + subtle wood grain
		float plank_coord = v_local_pos.z * tile_scale * 2.2;
		float plank_id = floor(plank_coord);
		float plank_f = fract(plank_coord);
		float gap = 1.0 - smoothstep(0.04, 0.11, min(plank_f, 1.0 - plank_f));
		float grain = sin(v_local_pos.x * 16.0 + vnoise(v_local_pos.xz * 4.5 + plank_id * 3.7) * 5.0) * 0.5 + 0.5;
		float plank_var = hash21(vec2(plank_id, 1.7));
		col = mix(albedo_b.rgb, albedo_a.rgb, plank_var * 0.55 + grain * 0.45);
		col = mix(col, albedo_b.rgb * 0.35, gap * 0.90);
		// Side accent trim strips along bridge edges
		float side_trim = smoothstep(0.86, 0.96, abs(v_local_pos.x) / max(1.0, tile_scale * 0.9));
		col = mix(col, accent_color.rgb, side_trim * 0.35);
		rough = mix(roughness_val, 0.92, gap);
		met = metallic_val * (1.0 - gap);
	} else if (surface_type == 1) {
		// Carved radial shrine / temple stone tile deck
		vec2 p = v_local_pos.xz;
		float r = length(p);
		float ang = atan(p.y, p.x);
		float ring_f = fract(r * 0.85);
		float ring_gap = 1.0 - smoothstep(0.03, 0.09, min(ring_f, 1.0 - ring_f));
		float spoke_n = (r > 1.8) ? 12.0 : 6.0;
		float spoke_f = fract((ang / 6.283185) * spoke_n);
		float spoke_gap = 1.0 - smoothstep(0.02, 0.06, min(spoke_f, 1.0 - spoke_f));
		float seam = max(ring_gap, spoke_gap);
		float grain = vnoise(p * 3.5);
		float tile_id = hash21(vec2(floor(r * 0.85), floor((ang / 6.283185) * spoke_n)));
		col = mix(albedo_b.rgb, albedo_a.rgb, tile_id * 0.65 + grain * 0.35);
		col = mix(col, accent_color.rgb * 0.72, seam * 0.68);
		rough = mix(roughness_val, 0.85, seam);
		met = mix(metallic_val, 0.32, seam);
	} else if (surface_type == 2) {
		// Forged obsidian & iron-plate fortress deck w/ subtle glowing seams
		vec2 p = v_local_pos.xz * 0.9;
		vec2 d = vec2(p.x + p.y, p.x - p.y) * 0.7071;
		vec2 f = fract(d);
		float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
		float seam = 1.0 - smoothstep(0.03, 0.09, edge);
		float cell_r = hash21(floor(d));
		float n = vnoise(p * 4.0);
		col = mix(albedo_b.rgb, albedo_a.rgb, cell_r * 0.55 + n * 0.45);
		col = mix(col, accent_color.rgb, seam * 0.85);
		emi = accent_color.rgb * seam * emission_strength;
		rough = mix(roughness_val, 0.30, seam);
		met = mix(metallic_val, 0.65, seam);
	} else if (surface_type == 3) {
		// Celestial marble & gold compass inlay deck
		vec2 p = v_local_pos.xz;
		float r = length(p);
		float ang = atan(p.y, p.x);
		float vein = sin(p.x * 1.4 + p.y * 1.1 + vnoise(p * 1.2) * 4.5) * 0.5 + 0.5;
		float gold_ring = 1.0 - smoothstep(0.05, 0.14, abs(fract(r * 0.55) - 0.5));
		float star_line = 1.0 - smoothstep(0.02, 0.06, abs(sin(ang * 4.0)));
		float inlay = max(gold_ring * 0.85, star_line * step(0.6, r) * 0.75);
		col = mix(albedo_b.rgb, albedo_a.rgb, vein * 0.75 + 0.25);
		col = mix(col, accent_color.rgb, inlay * 0.88);
		emi = accent_color.rgb * inlay * emission_strength;
		rough = mix(0.20, 0.16, inlay);
		met = mix(0.28, 0.78, inlay);
	} else {
		// Animated molten lava surface
		vec2 uv1 = v_world_pos.xz * 0.26 + vec2(TIME * 0.12, -TIME * 0.08);
		vec2 uv2 = v_world_pos.xz * 0.42 + vec2(-TIME * 0.09, TIME * 0.11);
		float f1 = vnoise(uv1 + vec2(vnoise(uv2) * 1.4, 0.0));
		float f2 = vnoise(uv2 * 1.5 - vec2(f1 * 1.1, 0.0));
		float heat = clamp(f1 * 0.55 + f2 * 0.45, 0.0, 1.0);
		float crust = smoothstep(0.56, 0.76, heat);
		vec3 molten = mix(albedo_a.rgb, accent_color.rgb, smoothstep(0.18, 0.58, 1.0 - heat));
		col = mix(molten, albedo_b.rgb, crust);
		emi = molten * (1.0 - crust * 0.88) * (1.35 + sin(TIME * 2.8 + heat * 6.0) * 0.25);
		rough = mix(0.22, 0.88, crust);
		met = 0.05;
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = met;
	EMISSION = emi;
}
