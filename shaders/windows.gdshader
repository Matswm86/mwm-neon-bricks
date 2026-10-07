shader_type spatial;
// World 2 skyline (DESIGN 11.6): dark tower body with a static grid of lit
// windows from a hash (no texture, no flicker). Cells are 1.6 x 2.0 m in
// world space so scaled towers keep square windows. Unshaded.
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

uniform vec3 body : source_color = vec3(0.047, 0.086, 0.220);
uniform vec3 lit_col : source_color = vec3(0.753, 0.502, 0.157);
uniform float lit_gain = 1.5;
uniform float density = 0.3;
uniform float layer = 0.0;

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 g = vec2(wp.x / 1.6, wp.y / 2.0);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float win = step(0.25, f.x) * step(f.x, 0.75) * step(0.3, f.y) * step(f.y, 0.7);
	float on = step(hash(cell + vec2(layer * 17.0, layer * 31.0)), density);
	float front = step(0.5, wn.z) * step(1.0, wp.y);
	ALBEDO = mix(body, lit_col * lit_gain, win * on * front);
}
