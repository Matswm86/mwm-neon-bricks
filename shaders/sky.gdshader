shader_type spatial;
// Sky v2 on one far quad (DESIGN 11.2 / 11.3, port of docs/mockups/src/
// nb_sky.py): gradient, one motif per world (sliced sun, moon with cloud
// bands, CRT screen, hex crystal, gate light), stars, ridges, a baked nebula
// and the horizon haze. Unshaded, 1 draw call. Only the motif is HDR (it is
// seen through the field-glass window, DESIGN 13.1); the rest stays < 1.
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 sky_top : source_color = vec3(0.043, 0.024, 0.188);
uniform vec3 sky_mid : source_color = vec3(0.227, 0.055, 0.361);
uniform vec3 sky_low : source_color = vec3(0.761, 0.094, 0.420);
uniform vec3 horizon : source_color = vec3(1.0, 0.478, 0.239);
uniform int motif = 1;
uniform vec2 motif_c = vec2(0.0, 0.012);
uniform float motif_r = 0.222;
uniform vec3 motif_top : source_color = vec3(0.824, 0.251, 0.180);
uniform vec3 motif_mid : source_color = vec3(0.831, 0.196, 0.424);
uniform vec3 motif_low : source_color = vec3(0.643, 0.173, 0.769);
uniform vec3 motif_rim : source_color = vec3(0.949, 0.439, 0.533);
uniform float motif_hdr = 2.222;
uniform vec3 star_col : source_color = vec3(1.0, 0.922, 0.949);
uniform float star_gain = 0.6;
uniform float star_density = 0.975;
uniform float star_square = 0.0;
uniform vec3 ridge_col : source_color = vec3(1.0, 0.180, 0.533);
uniform float ridge_gain = 1.0;
uniform float ridge_height = 1.0;
uniform vec3 ridge_solid : source_color = vec3(0.071, 0.024, 0.094);
uniform float wire_on = 1.0;
uniform sampler2D nebula_tex : hint_default_black, filter_linear, repeat_enable;
uniform vec3 neb_a : source_color = vec3(0.0);
uniform vec3 neb_b : source_color = vec3(0.0);
uniform float neb_gain = 0.0;
uniform float neb_floor = 0.0;
uniform vec3 haze_col : source_color = vec3(1.0, 0.180, 0.533);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rbox(vec2 p, vec2 h, float rc) {
	vec2 q = abs(p) - h + rc;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rc;
}

void fragment() {
	vec3 d = normalize(wp - CAMERA_POSITION_WORLD);
	float e = d.y;
	vec3 c = horizon;
	c = mix(c, sky_low, smoothstep(0.0, 0.06, e));
	c = mix(c, sky_mid, smoothstep(0.06, 0.22, e));
	c = mix(c, sky_top, smoothstep(0.22, 0.55, e));
	vec2 t = d.xy / max(-d.z, 0.05);
	float aa = max(fwidth(t.x), 0.0005);

	// Nebula / floor mist from the baked texture (one fetch).
	if (neb_gain > 0.0) {
		vec2 n = texture(nebula_tex, t * 0.6 + vec2(0.37, 0.11)).rg;
		float k = smoothstep(-0.02, 0.15, t.y) * neb_gain;
		k *= mix(1.0, 1.0 - smoothstep(0.05, 0.45, t.y), neb_floor);
		c += (neb_a * smoothstep(0.40, 0.80, n.r) + neb_b * smoothstep(0.50, 0.85, n.g)) * k;
	}

	// Stars: sparse hashed points (round, or square pixels in world 3).
	vec2 g = t * 90.0;
	vec2 cell = floor(g);
	float h = hash(cell);
	vec2 off = vec2(hash(cell + 7.0), hash(cell + 13.0)) * 0.6 + 0.2;
	vec2 dd = fract(g) - off;
	float sd = mix(length(dd), max(abs(dd.x), abs(dd.y)), star_square);
	float sh = 1.0 - mix(smoothstep(0.04, 0.09, sd), smoothstep(0.07, 0.09, sd), star_square);
	float star = step(star_density, h) * sh * smoothstep(0.10, 0.25, e);
	c += star_col * star * star_gain * (0.5 + 0.5 * hash(cell + 3.0));

	// Motif (DESIGN 11.3), colours as seen through the glass window.
	vec2 sp = (t - motif_c) / motif_r;
	float r = length(sp);
	float ar = aa / motif_r;
	vec3 mc = vec3(0.0);
	float cover = 0.0;
	if (motif == 1) {
		float disc = 1.0 - smoothstep(1.0 - ar * 1.5, 1.0, r);
		vec3 sc = mix(motif_low, motif_mid, smoothstep(-0.9, 0.0, sp.y));
		sc = mix(sc, motif_top, smoothstep(0.0, 0.8, sp.y));
		float gap = clamp((0.35 - sp.y) / 1.35, 0.0, 1.0) * 0.6;
		float slice = step(gap, fract(sp.y * 7.0));
		float rim = step(1.0 - 2.5 * ar, r) * step(0.05, sp.y) * disc;
		mc = mix(sc, motif_rim, rim);
		cover = disc * slice;
		c += motif_mid * 0.18 * exp(-max(r - 1.0, 0.0) * 6.0) * (1.0 - disc);
	} else if (motif == 2) {
		float disc = 1.0 - smoothstep(1.0 - ar * 1.5, 1.0, r);
		vec3 sc = mix(motif_low, motif_top, smoothstep(-0.9, 0.7, sp.y - 0.3 * sp.x));
		float rim = step(1.0 - 2.5 * ar, r) * step(sp.x, 0.2) * step(-0.2, sp.y);
		mc = mix(sc, motif_rim, rim * disc);
		cover = disc;
		vec4 bands[2] = { vec4(0.05, 0.07, -1.6, 0.7), vec4(-0.42, 0.05, -0.4, 1.7) };
		for (int i = 0; i < 2; i++) {
			vec4 b = bands[i];
			float band = smoothstep(b.y, b.y * 0.4, abs(sp.y - b.x));
			band *= smoothstep(b.z, b.z + 0.3, sp.x) * smoothstep(b.w, b.w - 0.3, sp.x);
			cover = max(cover * (1.0 - band * 0.8), band * 0.8);
			mc = mix(mc, sky_mid * 1.2, band);
		}
		c += motif_low * 0.25 * exp(-max(r - 1.0, 0.0) * 2.5) * (1.0 - disc);
	} else if (motif == 3) {
		float d_in = rbox(sp, vec2(1.75, 1.0), 0.28);
		float d_out = rbox(sp, vec2(1.95, 1.2), 0.36);
		float bez = step(d_out, 0.0) * step(0.0, d_in);
		float scr = step(d_in, 0.0);
		vec2 q = floor(sp / 0.1) * 0.1;
		float hill = -0.17 + 0.22 * sin(q.x * 2.3 + 0.6) + 0.12 * sin(q.x * 5.7);
		float hills = step(q.y, hill) * scr;
		float sun = step(length(q - vec2(0.55, 0.25)), 0.42) * scr * (1.0 - hills);
		float scan = 0.82 + 0.18 * step(0.5, fract(sp.y * 18.0));
		vec3 col = motif_low * scan;
		col = mix(col, motif_mid, hills);
		col = mix(col, motif_top, sun);
		float rim = step(abs(d_out), 2.0 * ar);
		col = mix(col, vec3(0.010, 0.004, 0.018), bez);
		col = mix(col, motif_rim, rim);
		mc = col;
		cover = max(max(scr, bez), rim);
		c += motif_mid * 0.08 * exp(-max(d_out, 0.0) * 4.0) * step(0.0, d_out);
	} else if (motif == 5) {
		float x = sp.x;
		float y = sp.y / 1.3;
		float ax = abs(x);
		float hd = max(ax, ax * 0.5 + abs(y) * 0.866) / 0.866;
		float hexm = 1.0 - smoothstep(1.0 - ar * 1.5, 1.0, hd);
		float ang = atan(y, x);
		float sector = floor((ang + PI) / (PI / 3.0));
		float shade = 1.0 - mod(sector, 2.0);
		vec3 col = mix(motif_mid, motif_top, shade * smoothstep(-1.0, 0.6, y));
		col = mix(col, motif_low, smoothstep(0.0, -1.0, y) * (1.0 - shade) * 0.7);
		col = mix(col, motif_top, step(hd, 0.45) * 0.8);
		float ea = (ang - PI * 0.5) / (PI / 3.0);
		float edge_ang = abs(fract(ea + 0.5) - 0.5) * (PI / 3.0) * max(r, 0.001);
		float edges = step(edge_ang, 1.6 * ar) * step(0.45, hd);
		edges = max(edges, step(abs(hd - 0.45), 1.6 * ar));
		edges = max(edges, step(1.0 - 2.2 * ar, hd));
		mc = mix(col, motif_rim, clamp(edges, 0.0, 1.0));
		cover = hexm;
		c += motif_top * 0.10 * exp(-max(hd - 1.0, 0.0) * 3.0) * (1.0 - hexm);
	} else if (motif == 6) {
		c += motif_mid * 0.10 * exp(-r * r * 1.6) + motif_top * 0.12 * exp(-r * r * 0.5);
	}

	// Ridges / mountains (wireframe only in world 1).
	if (ridge_gain > 0.0) {
		float ax = abs(t.x);
		float hill = max(ax - 0.12, 0.0) * (0.10 + 0.05 * sin(t.x * 47.0) + 0.03 * sin(t.x * 113.0));
		hill *= ridge_height;
		float edge = abs(t.y - hill);
		float line = 1.0 - smoothstep(0.0012, 0.0012 + aa * 1.5, edge);
		float under = step(t.y, hill) * step(0.0, t.y);
		vec2 wg = vec2(t.x * 60.0, (t.y / max(hill, 0.001)) * 3.0);
		vec2 wl = abs(fract(wg) - 0.5);
		float wire = under * (1.0 - smoothstep(0.03, 0.08, min(wl.x, wl.y))) * wire_on;
		c = mix(c, ridge_solid, under * 0.85);
		c += ridge_col * (line * 0.9 + wire * 0.35) * ridge_gain;
	}

	// Horizon haze band hides the floor's far edge.
	c += haze_col * 0.35 * exp(-abs(t.y) * 160.0);
	ALBEDO = mix(min(c, vec3(0.98)), mc * motif_hdr, cover);
}
