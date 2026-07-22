shader_type canvas_item;

uniform float edge_strength : hint_range(0.0, 1.0) = 0.72;
uniform float base_darkness : hint_range(0.0, 1.0) = 0.16;

void fragment() {
	vec2 centered_uv = (UV - vec2(0.5)) * vec2(1.0, 1.35);
	float edge = smoothstep(0.24, 0.78, length(centered_uv));
	float lower_fade = smoothstep(0.65, 1.0, UV.y) * 0.2;
	float alpha = clamp(base_darkness + edge * edge_strength + lower_fade, 0.0, 0.9);
	COLOR = vec4(0.008, 0.014, 0.022, alpha);
}
