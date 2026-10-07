shader_type spatial;
// Ball-saver net (DESIGN 7c) on one additive quad: cyan line + faint diamond
// lattice; charge pips as white diamonds (count is shape); 0 charges = dashed
// line, no lattice. A catch sends a ripple out from the contact point.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 cyan : source_color = vec3(0.180, 0.902, 1.0);
uniform float width_px = 1000.0;
uniform float height_px = 60.0;
uniform float line_y_px = 15.0;
uniform float line_energy = 4.0;
uniform float lattice_energy = 1.2;
// -1 = unlimited (no pips), else 0..3 pips shown
uniform float pips = -1.0;
// fading pip (the one just spent), 1 -> 0
uniform float pip_out = 0.0;
// Skjoldnett: the newest pip weaves in, 0 -> 1 over 0.4 s.
uniform float pip_in = 1.0;
uniform float ripple_x = 0.0;
uniform float ripple_t = 9.0;
uniform float less_motion = 0.0;
uniform float dim = 1.0;

float diamond(vec2 p, float s) {
	return abs(p.x) + abs(p.y) - s;
}

void fragment() {
	vec2 px = vec2(UV.x * width_px, UV.y * height_px);
	float aa = 1.2;
	// Ripple: a travelling bump on the line for 0.4 s.
	float ry = 0.0;
	if (ripple_t < 0.4 && less_motion < 0.5) {
		float k = ripple_t / 0.4;
		float front = abs(px.x - ripple_x) - k * 420.0;
		ry = 9.0 * (1.0 - k) * exp(-front * front / 900.0) * sin(front * 0.08 + 1.57);
	}
	float ly = line_y_px + ry;
	float dl = abs(px.y - ly);
	float line = 1.0 - smoothstep(2.5, 2.5 + aa, dl);
	bool empty = pips > -0.5 && pips < 0.5;
	if (empty) {
		line *= step(fract(px.x / 44.0), 0.55);
	}
	// Lattice of X diamonds below the line.
	float lat = 0.0;
	if (!empty) {
		float cw = 50.0;
		float lh = 26.0;
		float yy = px.y - ly;
		if (yy > 0.0 && yy < lh) {
			float u = fract(px.x / cw);
			float v = yy / lh;
			float d1 = abs(u - v * 0.5) * cw;
			float d2 = abs((1.0 - u) - v * 0.5) * cw;
			lat = 1.0 - smoothstep(1.0, 1.0 + aa, min(d1, d2));
		}
	}
	vec3 c = cyan * (line * line_energy + lat * lattice_energy);
	// Pips: centred diamonds on the line.
	if (pips > 0.5 || pip_out > 0.0) {
		float n = max(pips, 0.0);
		float total = n + (pip_out > 0.0 ? 1.0 : 0.0);
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			if (fi >= total) {
				break;
			}
			float cx = width_px * 0.5 + (fi - (total - 1.0) * 0.5) * 44.0;
			bool newest = fi > n - 1.5 && fi < n;
			float grow = newest ? pip_in : 1.0;
			float d = diamond(px - vec2(cx, ly - (1.0 - grow) * 30.0), 13.0 * max(grow, 0.05));
			float m = 1.0 - smoothstep(-aa, aa, d);
			float a = fi < n ? grow : pip_out;
			c = mix(c, vec3(3.0) * a, m * max(a, 0.0));
		}
	}
	ALBEDO = c * dim;
}
