shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 foam_color : source_color = vec4(0.82, 0.94, 0.90, 0.76);
uniform float foam_speed : hint_range(0.0, 3.0) = 0.65;


void fragment() {
	float edge_fade = sin(UV.y * 3.14159265);
	float broken_wave = sin(UV.x * 190.0 - TIME * foam_speed * 5.0) * 0.16;
	broken_wave += sin(UV.x * 73.0 + TIME * foam_speed * 2.0) * 0.10;
	float alpha = clamp(edge_fade + broken_wave, 0.0, 1.0);
	ALBEDO = foam_color.rgb;
	ALPHA = foam_color.a * alpha;
}
