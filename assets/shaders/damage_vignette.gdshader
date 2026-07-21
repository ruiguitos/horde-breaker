shader_type canvas_item;

// Red edge vignette; intensity is driven by GameHUD from the player's health.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float distance_from_center = distance(UV, vec2(0.5));
	float edge = smoothstep(0.28, 0.75, distance_from_center);
	COLOR = vec4(0.55, 0.04, 0.05, edge * intensity);
}
