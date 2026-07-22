shader_type canvas_item;

uniform float gradient_strength : hint_range(0.0, 0.2) = 0.07;
uniform float scanline_strength : hint_range(0.0, 0.1) = 0.018;
uniform float noise_strength : hint_range(0.0, 0.1) = 0.012;

float random_noise(vec2 position) {
	return fract(sin(dot(position, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float top_light = pow(1.0 - UV.y, 2.4);
	float scanline = 0.5 + 0.5 * sin(FRAGCOORD.y * 1.6);
	float noise = random_noise(floor(FRAGCOORD.xy * 0.5) + floor(TIME * 2.0));
	vec3 steel_tint = vec3(0.12, 0.17, 0.21);
	vec3 amber_tint = vec3(0.46, 0.24, 0.07);
	vec3 tint = mix(steel_tint, amber_tint, top_light * 0.18);
	float alpha = (
		0.015
		+ top_light * gradient_strength
		+ scanline * scanline_strength
		+ noise * noise_strength
	);
	COLOR = vec4(tint, alpha);
}
