shader_type canvas_item;
render_mode blend_add, unshaded;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 flame_color_core : source_color = vec4(0.85, 0.98, 0.95, 1.0);
uniform vec4 flame_color_edge : source_color = vec4(0.18, 0.72, 0.68, 0.85);
uniform vec4 flame_color_smoke : source_color = vec4(0.08, 0.28, 0.32, 0.0);
uniform float speed_y : hint_range(0.1, 3.0) = 0.8;
uniform float distortion_intensity : hint_range(0.0, 0.5) = 0.15;
uniform float intensity_multiplier : hint_range(0.5, 3.0) = 1.4;

void fragment() {
	vec2 uv = UV;
	
	// Scrolling noise coordinates for rising spectral smoke
	vec2 noise_uv1 = uv * 1.5 + vec2(sin(TIME * 1.2) * 0.05, -TIME * speed_y * 0.6);
	vec2 noise_uv2 = uv * 2.2 + vec2(cos(TIME * 1.5) * 0.08, -TIME * speed_y * 0.9);
	
	float n1 = texture(noise_tex, noise_uv1).r;
	float n2 = texture(noise_tex, noise_uv2).r;
	float combined_noise = (n1 + n2) * 0.5;
	
	// Distort texture UV
	vec2 distorted_uv = uv + vec2((combined_noise - 0.5) * distortion_intensity, (n1 - 0.5) * distortion_intensity * 0.5);
	vec4 base_tex = texture(TEXTURE, distorted_uv);
	
	// Radial/teardrop gradient mask from texture alpha and center distance
	float dist_from_center = length(uv - vec2(0.5, 0.65)) * 2.0;
	float flame_mask = clamp(1.0 - dist_from_center, 0.0, 1.0) * base_tex.a;
	flame_mask = pow(flame_mask, 1.4) * combined_noise;
	
	// Color ramp: Core -> Edge -> Dissipated Smoke
	vec4 col;
	if (flame_mask > 0.6) {
		float t = (flame_mask - 0.6) / 0.4;
		col = mix(flame_color_edge, flame_color_core, t);
	} else if (flame_mask > 0.15) {
		float t = (flame_mask - 0.15) / 0.45;
		col = mix(flame_color_smoke, flame_color_edge, t);
	} else {
		col = vec4(0.0);
	}
	
	COLOR = col * intensity_multiplier;
}
