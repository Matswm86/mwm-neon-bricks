shader_type spatial;
// Floor v2 (DESIGN 11.4): unshaded, anti-aliased fract() lines that fade
// with distance, kept under the glow threshold so the floor never blooms.
// mode 0 grid (sea), 1 checker, 2 road (lane dashes + edge lines, dashes
// scroll toward the camera), 3 lattice (diagonal diamonds). A soft streak
// stands in for a reflection (no SSR).
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

uniform int mode = 0;
uniform vec3 base : source_color = vec3(0.027, 0.016, 0.102);
uniform vec3 base2 : source_color = vec3(0.133, 0.063, 0.180);
uniform vec3 line_col : source_color = vec3(0.839, 0.227, 0.976);
uniform vec3 streak_col : source_color = vec3(1.0, 0.478, 0.239);
uniform vec3 haze_col : source_color = vec3(0.62, 0.12, 0.30);
uniform vec3 dash_col : source_color = vec3(1.0, 0.698, 0.239);
uniform vec3 edge_col : source_color = vec3(1.0, 0.231, 0.188);
uniform float period = 3.0;
uniform float width = 0.035;
uniform float fade_far = 260.0;
uniform float gain = 0.85;
uniform float less_motion = 0.0;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float aa_line(float dist, float w, float fw) {
	return 1.0 - smoothstep(w - fw, w + fw, dist);
}

void fragment() {
	vec2 g = vec2(wp.x, wp.z) / period;
	if (mode == 3) {
		g = vec2(wp.x + wp.z, wp.x - wp.z) / period;
	}
	vec2 fw = max(fwidth(g), vec2(0.0001));
	vec2 dist = abs(fract(g + 0.5) - 0.5);
	vec2 l = 1.0 - smoothstep(vec2(width) - fw, vec2(width) + fw, dist);
	// Fade lines whose pixels are smaller than the line (moire) and with distance.
	vec2 lod = 1.0 - smoothstep(vec2(0.15), vec2(0.5), fw);
	float lines = max(l.x * lod.x, l.y * lod.y);
	float far = clamp(1.0 + wp.z / fade_far, 0.0, 1.0);
	vec3 b = base;
	if (mode == 1) {
		b = mix(base, base2, mod(floor(g.x) + floor(g.y), 2.0));
	}
	float streak = exp(-wp.x * wp.x / (2.0 * 9.0)) * smoothstep(-20.0, -380.0, wp.z) * 0.22;
	vec3 c = b + line_col * lines * far * gain + streak_col * streak;
	if (mode == 2) {
		float ax = abs(wp.x);
		float road = step(ax, 7.0);
		float fx = fwidth(wp.x);
		float zz = wp.z + TIME * 6.0 * (1.0 - less_motion);
		float dash = aa_line(abs(ax - 3.5), 0.12, fx) * step(0.5, fract(zz / 6.0));
		float edge = aa_line(abs(ax - 7.0), 0.15, fx);
		vec3 rc = vec3(0.0024, 0.0012, 0.0030) + streak_col * streak;
		rc += (dash_col * 0.9 * dash + edge_col * 0.8 * edge) * far;
		c = mix(c, rc, max(road, edge));
	}
	// Haze toward the horizon so the far floor meets the sky without a dark band.
	float haze = smoothstep(-60.0, -400.0, wp.z);
	c = mix(c, haze_col, haze * 0.8);
	ALBEDO = min(c, vec3(0.98));
}
