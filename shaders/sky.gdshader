shader_type spatial;
// World 1 backdrop on one far quad (DESIGN 7d): sunset gradient, sliced sun,
// stars, wireframe ridges and the horizon haze. Unshaded, 1 draw call.
// Colours are kept under the glow threshold so the sky never blooms.
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 sky_top : source_color = vec3(0.043, 0.024, 0.188);
uniform vec3 sky_mid : source_color = vec3(0.227, 0.055, 0.361);
uniform vec3 sky_low : source_color = vec3(0.761, 0.094, 0.420);
uniform vec3 horizon : source_color = vec3(1.0, 0.478, 0.239);
uniform vec3 sun_top : source_color = vec3(1.0, 0.788, 0.235);
uniform vec3 sun_mid : source_color = vec3(1.0, 0.541, 0.239);
uniform vec3 sun_low : source_color = vec3(1.0, 0.180, 0.533);
uniform vec3 ridge_col : source_color = vec3(1.0, 0.180, 0.533);
uniform float sun_v = 0.012;
uniform float sun_r = 0.222;
uniform float sun_gain = 0.9;
uniform float star_gain = 0.6;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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

	// Stars: sparse hashed points above the haze.
	vec2 g = t * 90.0;
	vec2 cell = floor(g);
	float h = hash(cell);
	vec2 off = vec2(hash(cell + 7.0), hash(cell + 13.0)) * 0.6 + 0.2;
	float sd = length(fract(g) - off);
	float star = step(0.975, h) * (1.0 - smoothstep(0.04, 0.09, sd)) * smoothstep(0.10, 0.25, e);
	c += vec3(1.0, 0.92, 0.95) * star * star_gain * (0.5 + 0.5 * hash(cell + 3.0));

	// Sun: gradient disc with horizontal slices on its lower half.
	vec2 sp = (t - vec2(0.0, sun_v)) / sun_r;
	float r = length(sp);
	float disc = 1.0 - smoothstep(1.0 - aa / sun_r * 1.5, 1.0, r);
	vec3 sc = mix(sun_low, sun_mid, smoothstep(-0.9, 0.0, sp.y));
	sc = mix(sc, sun_top, smoothstep(0.0, 0.8, sp.y));
	float gap = clamp((0.35 - sp.y) / 1.35, 0.0, 1.0) * 0.6;
	float slice = step(gap, fract(sp.y * 7.0));
	float sun = disc * slice;
	c = mix(c, sc * sun_gain, sun);
	// soft glow ring around the sun (baked, not post)
	c += sun_mid * 0.18 * exp(-max(r - 1.0, 0.0) * 6.0) * (1.0 - disc);

	// Ridges: low wireframe hills toward the sides, hotpink edge line.
	float ax = abs(t.x);
	float hill = max(ax - 0.12, 0.0) * (0.10 + 0.05 * sin(t.x * 47.0) + 0.03 * sin(t.x * 113.0));
	float edge = abs(t.y - hill);
	float line = 1.0 - smoothstep(0.0012, 0.0012 + aa * 1.5, edge);
	float under = step(t.y, hill) * step(0.0, t.y);
	vec2 wg = vec2(t.x * 60.0, (t.y / max(hill, 0.001)) * 3.0);
	vec2 wl = abs(fract(wg) - 0.5);
	float wire = under * (1.0 - smoothstep(0.03, 0.08, min(wl.x, wl.y)));
	c = mix(c, vec3(0.07, 0.024, 0.12), under * 0.85);
	c += ridge_col * (line * 0.9 + wire * 0.35);

	// Horizon haze band hides the sea's far edge.
	c += sun_low * 0.35 * exp(-abs(t.y) * 160.0);
	ALBEDO = min(c, vec3(0.98));
}
