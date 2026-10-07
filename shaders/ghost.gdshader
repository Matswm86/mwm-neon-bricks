shader_type spatial;
// Ghost bricks A / B (DESIGN 12.2) in their own MultiMesh, one material.
// INSTANCE_CUSTOM: x = set (0 A, 1 B), y = phase (0 solid -> 1 phased,
// cross-faded by NbWorld), z = carrier, w = fade 0..1 or 1 + glow 0..1
// (auto-flip warning, finale pulse). COLOR.rgb = row colour.
// Solid: candy body in the row colour, no rim tube, a dashed outline (12
// dashes) on a dark keyline, set A square corner brackets, set B round
// corner dots. Phased: an 8% haze body, outline and marks at 30% alpha, no
// keyline. Drawn after the field glass (render_priority 1), no depth write.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 line_col : source_color = vec3(1.0, 0.957, 0.839);
uniform vec3 key_col : source_color = vec3(0.102, 0.024, 0.078);
uniform vec3 star_col : source_color = vec3(1.0, 0.906, 0.627);
uniform float body_emit = 0.8; // brick 0.45: the transparent pass reads darker
uniform float line_energy = 3.0;
uniform float phased_alpha = 0.3;

varying vec3 lp;
varying vec3 ln;
varying flat vec4 cd;
varying flat vec3 col;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	cd = INSTANCE_CUSTOM;
	col = COLOR.rgb;
}

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float fill(float d, float aa) {
	return 1.0 - smoothstep(-aa, aa, d);
}

// Position along the outline perimeter, 0..1 (rectangle 0.80 x 0.32).
float perim(vec2 p) {
	vec2 h = vec2(0.40, 0.16);
	float L = 4.0 * (h.x + h.y);
	vec2 q = p / h;
	float s;
	if (abs(q.x) >= abs(q.y)) {
		s = q.x > 0.0 ? (2.0 * h.x + h.y + p.y) : (4.0 * h.x + 3.0 * h.y - p.y);
	} else {
		s = q.y > 0.0 ? (h.x - p.x) : (2.0 * h.x + 2.0 * h.y + p.x);
	}
	return fract(s / L);
}

void fragment() {
	vec2 p = lp.xy;
	float aa = max(fwidth(p.x), 0.002);
	float front = smoothstep(0.55, 0.85, ln.z);
	bool set_b = cd.x > 0.5;
	float ph = clamp(cd.y, 0.0, 1.0);
	bool carrier = cd.z > 0.5;
	float fade = clamp(cd.w, 0.0, 1.0);
	float glow = clamp(cd.w - 1.0, 0.0, 1.0);

	float od = abs(sd_round_box(p, vec2(0.40, 0.16), 0.05));
	float u = perim(p);
	float dash = step(fract(u * 12.0), 0.45);
	float dash_k = step(fract(u * 12.0 + 0.01), 0.47);
	float line = fill(od - 0.011, aa) * dash * front;
	float key = fill(od - 0.020, aa) * dash_k * front;
	// Corner marks.
	vec2 c = vec2(0.36, 0.13);
	vec2 q = abs(p);
	float mk;
	float mk_key;
	if (!set_b) {
		float lb = min(sd_segment(q, c, c - vec2(0.13, 0.0)), sd_segment(q, c, c - vec2(0.0, 0.11)));
		mk = fill(lb - 0.028 * 0.5, aa);
		mk_key = fill(lb - 0.040 * 0.5, aa);
	} else {
		float dd = length(q - c);
		mk = fill(dd - 0.05, aa);
		mk_key = fill(dd - 0.065, aa);
	}
	mk *= front;
	mk_key *= front;
	float marks = max(line, mk);
	float keys = max(key, mk_key);

	// Solid look.
	vec3 alb_s = col;
	vec3 emi_s = col * body_emit;
	alb_s = mix(alb_s, key_col, keys);
	emi_s = mix(emi_s, vec3(0.0), keys);
	alb_s = mix(alb_s, line_col, marks);
	emi_s = mix(emi_s, line_col * line_energy * (1.0 + glow), marks);
	if (carrier) {
		// Small 5-point-ish star: a circle stands in at this size.
		float st = fill(length(p) - 0.07, aa) * front;
		alb_s = mix(alb_s, star_col, st);
		emi_s = mix(emi_s, star_col * 4.0, st);
	}
	emi_s += col * glow * 1.2;
	// Phased look: haze body + faint outline and marks.
	vec3 alb_p = mix(col * 0.3, line_col, marks);
	vec3 emi_p = line_col * marks * (0.6 + glow * 2.0);
	float a_p = max(0.08, marks * phased_alpha * (1.0 + glow));

	ALBEDO = mix(alb_s, alb_p, ph) * fade;
	EMISSION = mix(emi_s, emi_p, ph) * fade;
	ALPHA = mix(1.0, a_p, ph) * fade;
	ROUGHNESS = 0.18;
	CLEARCOAT = 0.6 * (1.0 - ph);
	CLEARCOAT_ROUGHNESS = 0.1;
	SPECULAR = 0.5 * (1.0 - ph);
}
