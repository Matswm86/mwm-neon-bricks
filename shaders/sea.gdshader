shader_type spatial;
// Grid sea (DESIGN 7d): unshaded, anti-aliased fract() lines that fade with
// distance, kept under the glow threshold so the grid never blooms; a soft
// orange streak stands in for the sun's reflection (no SSR).
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 base : source_color = vec3(0.027, 0.016, 0.102);
uniform vec3 line_col : source_color = vec3(0.839, 0.227, 0.976);
uniform vec3 streak_col : source_color = vec3(1.0, 0.478, 0.239);
uniform vec3 haze_col : source_color = vec3(0.62, 0.12, 0.30);
uniform float period = 3.0;
uniform float width = 0.035;
uniform float fade_far = 260.0;
uniform float gain = 0.85;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 g = vec2(wp.x, wp.z) / period;
	vec2 fw = max(fwidth(g), vec2(0.0001));
	vec2 dist = abs(fract(g + 0.5) - 0.5);
	vec2 l = 1.0 - smoothstep(vec2(width) - fw, vec2(width) + fw, dist);
	// Fade lines whose pixels are smaller than the line (moire) and with distance.
	vec2 lod = 1.0 - smoothstep(vec2(0.15), vec2(0.5), fw);
	float lines = max(l.x * lod.x, l.y * lod.y);
	float far = clamp(1.0 + wp.z / fade_far, 0.0, 1.0);
	float streak = exp(-wp.x * wp.x / (2.0 * 9.0)) * smoothstep(-20.0, -380.0, wp.z) * 0.22;
	vec3 c = base + line_col * lines * far * gain + streak_col * streak;
	// Haze toward the horizon so the far sea meets the sky without a dark band.
	float haze = smoothstep(-60.0, -400.0, wp.z);
	c = mix(c, haze_col, haze * 0.8);
	ALBEDO = min(c, vec3(0.98));
}
