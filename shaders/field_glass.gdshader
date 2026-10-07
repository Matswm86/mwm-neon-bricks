shader_type spatial;
// Field glass (DESIGN 13.1): 72% black everywhere, 55% inside a soft window
// that follows the vista motif in view space, so the sun keeps its neon
// saturation instead of muddying. Same t-space as sky.gdshader.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float base_alpha = 0.72;
uniform float window_alpha = 0.55;
uniform vec2 window_c = vec2(0.0, 0.012);
uniform float window_r = 0.222;
uniform vec2 window_box = vec2(0.0, 0.0); // > 0: rounded box half-size in r units (world 3 screen)
uniform float window_on = 1.0;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 d = normalize(wp - CAMERA_POSITION_WORLD);
	vec2 t = d.xy / max(-d.z, 0.05);
	vec2 sp = (t - window_c) / window_r;
	float rr = window_box.x > 0.0 ? max(abs(sp.x) / window_box.x, abs(sp.y) / window_box.y) : length(sp);
	float win = (1.0 - smoothstep(1.03, 1.30, rr)) * smoothstep(0.0, 0.04, t.y) * window_on;
	ALBEDO = vec3(0.0);
	ALPHA = mix(base_alpha, window_alpha, win);
}
