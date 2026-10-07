shader_type spatial;
// Portal pairs (DESIGN 12.3) on one quad each, in one MultiMesh: dark hole,
// ring r 0.40 m (the 40 px trigger radius), pair 1 = one spiral arm (mint),
// pair 2 = two arms + a 5-point star (gold). Arms turn 0.25 rev/s, static
// under "Mindre bevegelse". INSTANCE_CUSTOM.x = pair (1 or 2).
// Drawn after the field glass (render_priority 1), no depth write.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 hole : source_color = vec3(0.020, 0.008, 0.047);
uniform vec3 mint : source_color = vec3(0.612, 1.0, 0.784);
uniform vec3 gold : source_color = vec3(1.0, 0.824, 0.478);
uniform float less_motion = 0.0;

varying flat float pair;

void vertex() {
	pair = INSTANCE_CUSTOM.x;
}

float fill(float d, float aa) {
	return 1.0 - smoothstep(-aa, aa, d);
}

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

// Distance to an Archimedean spiral arm from r0 to r1 with `turns` turns.
float spiral(vec2 p, float r0, float r1, float turns, float phase) {
	float r = length(p);
	float a = atan(p.y, p.x) + phase;
	float pitch = (r1 - r0) / turns;
	float k = (r - r0) / pitch - a / 6.2831853;
	float d = abs(fract(k + 0.5) - 0.5) * pitch;
	return r < r0 || r > r1 ? 1.0 : d;
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(0.86, -0.86);
	float r = length(p);
	float aa = max(fwidth(p.x), 0.002);
	bool two = pair > 1.5;
	vec3 c = two ? gold : mint;
	float spin = TIME * 1.5708 * (1.0 - less_motion);
	float disc = fill(r - 0.40, aa);
	float ring = fill(abs(r - 0.40) - 0.03, aa);
	float arm;
	if (two) {
		arm = fill(spiral(p, 0.15, 0.35, 1.3, spin) - 0.012, aa);
		arm = max(arm, fill(spiral(p, 0.15, 0.35, 1.3, spin + 3.14159) - 0.012, aa));
		float star = fill(sd_star5(p, 0.14, 0.45), aa);
		arm = max(arm, star * 1.6);
	} else {
		arm = fill(spiral(p, 0.05, 0.35, 2.6, spin) - 0.014, aa);
	}
	vec3 col = hole;
	col = mix(col, c * 2.5, clamp(arm, 0.0, 1.0));
	col = mix(col, c * 4.0, ring);
	ALBEDO = col;
	ALPHA = max(disc, ring);
}
