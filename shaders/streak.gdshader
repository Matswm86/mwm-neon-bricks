shader_type spatial;
// World 4 light streaks (DESIGN 11.6): thin unshaded quads along the road
// with a UV-scrolled dash mask (period 18 m, 70% duty, 20 m/s). COLOR.a = 1
// scrolls away from the camera (tail lights), 0 toward it (head lights).
// Static under "Mindre bevegelse". Additive.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform float less_motion = 0.0;

varying vec4 col;
varying vec3 wp;

void vertex() {
	col = COLOR;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dir = col.a > 0.5 ? 1.0 : -1.0;
	float z = wp.z + dir * TIME * 20.0 * (1.0 - less_motion);
	float dash = step(fract(z / 18.0), 0.7);
	float far = clamp(1.0 + wp.z / 260.0, 0.0, 1.0);
	ALBEDO = col.rgb * dash * far;
}
