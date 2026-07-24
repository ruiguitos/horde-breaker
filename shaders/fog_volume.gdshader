shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 fog_color : source_color = vec4(0.55, 0.42, 0.3, 0.2);
uniform float density : hint_range(0.0, 1.0) = 0.2;

void fragment() {
	ALBEDO = fog_color.rgb;
	ALPHA = fog_color.a * density;
}
