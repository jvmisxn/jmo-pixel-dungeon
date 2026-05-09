shader_type canvas_item;

// Fog of War shader — runs entirely on GPU.
// The data texture stores fog state per cell:
//   R channel = 0.0 (unseen), 0.5 (visited/mapped), 1.0 (visible)
// Hero position and distance fade are computed per-pixel in the shader.

uniform sampler2D fog_data : filter_linear, repeat_disable;
uniform vec2 hero_cell = vec2(-1.0, -1.0);
uniform vec2 map_size = vec2(32.0, 32.0);
uniform float alpha_unseen : hint_range(0.0, 1.0) = 1.0;
uniform float alpha_visited : hint_range(0.0, 1.0) = 0.65;
uniform float alpha_dark_visible : hint_range(0.0, 1.0) = 0.35;
uniform float fade_start = 4.0;
uniform float fade_end = 7.0;
uniform float fade_max_alpha : hint_range(0.0, 1.0) = 0.55;
uniform bool is_dark = false;

void fragment() {
	// Sample the fog data texture (bilinear filtering gives smooth gradients)
	float state = texture(fog_data, UV).r;

	float alpha;
	if (state > 0.75) {
		// Visible cell — apply distance-based dimming
		alpha = 0.0;
		if (hero_cell.x >= 0.0) {
			// Convert UV to cell coordinates
			vec2 cell = UV * (map_size + 2.0) - 1.0;
			float dist = distance(cell, hero_cell);
			if (dist > fade_start) {
				float t = clamp((dist - fade_start) / (fade_end - fade_start), 0.0, 1.0);
				alpha = mix(0.0, fade_max_alpha, t);
			}
		}
		if (is_dark) {
			alpha = max(alpha, alpha_dark_visible);
		}
	} else if (state > 0.25) {
		// Visited/mapped cell
		alpha = alpha_visited;
	} else {
		// Unseen cell
		alpha = alpha_unseen;
	}

	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
