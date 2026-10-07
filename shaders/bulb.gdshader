shader_type spatial;
// World 3 truss bulbs (DESIGN 11.6): unshaded gold, alternate bulbs breathe
// at 0.5 Hz between 75% and 100% (a sine, never on/off); static under
// "Mindre bevegelse". Outside the field glass (sky band).
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

uniform vec3 col : source_color = vec3(1.0, 0.882, 0.302);
uniform float gain = 3.0;
uniform float less_motion = 0.0;

varying flat float phase;

void vertex() {
	phase = float(INSTANCE_ID % 2) * PI;
}

void fragment() {
	float k = 0.875 + 0.125 * sin(TIME * PI + phase);
	ALBEDO = col * gain * mix(k, 1.0, less_motion);
}
