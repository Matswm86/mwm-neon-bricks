shader_type spatial;
// One shader for every slice brick in one MultiMesh (DESIGN 7a/7b).
// INSTANCE_CUSTOM: x = type (0 glass, 1 double, 2 chrome), y = hits left,
// z = carrier (1 = star inlay), w = fade 0..1, or 1 + glow 0..1 (assist hint).
// COLOR.rgb = brick colour. The rim tube, dots, star, crack, chrome stripes
// and bolts are painted here, so the mesh is the plain 300-tri bevelled body.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 chrome_col : source_color = vec3(0.788, 0.808, 0.847);
uniform vec3 stripe_col : source_color = vec3(0.604, 0.631, 0.690);
uniform vec3 bolt_col : source_color = vec3(0.369, 0.392, 0.447);
uniform vec3 dot_col : source_color = vec3(1.0, 0.957, 0.839);
uniform vec3 star_col : source_color = vec3(1.0, 0.906, 0.627);
uniform float rim_energy = 5.0;
uniform float body_emit = 0.45;
uniform float dot_energy = 3.0;
uniform float star_energy = 4.0;
uniform float dim = 1.0;

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

// Inigo Quilez 5-point star SDF.
float sd_star5(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994375, -0.587785252292);
	const vec2 k2 = vec2(-k1.x, k1.y);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
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

void fragment() {
	vec2 p = lp.xy;
	float aa = max(fwidth(p.x), 0.002);
	float front = smoothstep(0.55, 0.85, ln.z);
	int kind = int(cd.x + 0.5);
	int hits = int(cd.y + 0.5);
	bool carrier = cd.z > 0.5;
	float fade = clamp(cd.w, 0.0, 1.0);
	float glow = clamp(cd.w - 1.0, 0.0, 1.0);

	vec3 alb;
	vec3 emi = vec3(0.0);
	float metal = 0.0;
	float rough = 0.18;
	float coat = 0.6;

	if (kind == 2) {
		// Chrome: silver, static low-contrast stripes, 4 bolts, never glows.
		float s = step(0.5, fract((p.x + p.y) * 9.0));
		alb = mix(chrome_col, stripe_col, s * front);
		vec2 q = abs(p) - vec2(0.38, 0.14);
		float bolt = fill(length(q) - 0.035, aa) * front;
		alb = mix(alb, bolt_col, bolt);
		metal = 1.0;
		rough = mix(0.22, 0.4, bolt);
		coat = 0.0;
	} else {
		alb = col;
		emi = col * body_emit;
		// Rim tube painted on the front face, inset 0.06 m.
		float rd = abs(sd_round_box(p, vec2(0.40, 0.16), 0.05));
		float rim = fill(rd - 0.013, aa) * front;
		emi = mix(emi, mix(col, vec3(1.0), 0.35) * rim_energy, rim);
		alb = mix(alb, vec3(0.0), rim * 0.6);
		// Shape cues: dots (double), crack (double hit once), star (carrier).
		float mark = 0.0;
		vec3 mark_emi = vec3(0.0);
		if (kind == 1) {
			float dx = carrier ? 0.20 : 0.17;
			float rr = carrier ? 0.065 : 0.075;
			float d_left = fill(length(p - vec2(-dx, 0.0)) - rr, aa);
			float d_right = fill(length(p - vec2(dx, 0.0)) - rr, aa);
			float dots = hits >= 2 ? max(d_left, d_right) : d_left;
			mark = max(mark, dots * front);
			mark_emi = dot_col * dot_energy;
			if (hits < 2) {
				vec2 c = vec2(dx, 0.0);
				float cr = sd_segment(p, c + vec2(-0.02, 0.11), c + vec2(0.02, 0.04));
				cr = min(cr, sd_segment(p, c + vec2(0.02, 0.04), c + vec2(-0.03, -0.02)));
				cr = min(cr, sd_segment(p, c + vec2(-0.03, -0.02), c + vec2(0.02, -0.10)));
				float crack = fill(cr - 0.008, aa) * front;
				alb = mix(alb, vec3(0.05, 0.02, 0.06), crack);
				emi = mix(emi, vec3(0.0), crack);
			}
		}
		if (carrier) {
			float sr = kind == 1 ? 0.085 : 0.12;
			float st = fill(sd_star5(p, sr, 0.45), aa) * front;
			emi = mix(emi, star_col * star_energy, st);
			alb = mix(alb, star_col, st);
		}
		emi = mix(emi, mark_emi, mark);
		alb = mix(alb, dot_col, mark);
		emi += col * glow * 1.6;
	}
	ALBEDO = alb * fade * dim;
	EMISSION = emi * fade * dim;
	METALLIC = metal;
	ROUGHNESS = rough;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.1;
	SPECULAR = 0.5 * fade;
}
