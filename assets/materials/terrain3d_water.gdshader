shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.035, 0.16, 0.22, 0.90);
uniform vec4 shallow_color : source_color = vec4(0.08, 0.38, 0.42, 0.82);
uniform float wave_scale : hint_range(10.0, 240.0) = 120.0;
uniform float wave_speed : hint_range(0.0, 3.0) = 0.55;


void fragment() {
	float first_wave = sin(UV.x * wave_scale + TIME * wave_speed);
	float second_wave = cos(UV.y * wave_scale * 0.73 - TIME * wave_speed * 0.82);
	float crossing_wave = sin((UV.x + UV.y) * wave_scale * 0.41 + TIME * 0.31);
	float wave = first_wave * second_wave * 0.15 + crossing_wave * 0.08;
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, clamp(0.5 + wave, 0.0, 1.0));
	ROUGHNESS = 0.18;
	METALLIC = 0.06;
	ALPHA = mix(deep_color.a, shallow_color.a, clamp(0.5 + wave, 0.0, 1.0));
}
