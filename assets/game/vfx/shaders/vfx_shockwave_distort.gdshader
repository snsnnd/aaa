shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float wave_width : hint_range(0.01, 0.5) = 0.12;
uniform float distortion_strength : hint_range(0.0, 0.15) = 0.045;
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.015;
uniform vec4 tint_color : source_color = vec4(1.0, 0.88, 0.65, 1.0);

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	vec2 uv_offset = UV - center;
	float dist = length(uv_offset);
	
	// Ring mask based on current progress
	float ring_center = progress * 0.75;
	float diff = abs(dist - ring_center);
	float wave_mask = smoothstep(wave_width, 0.0, diff);
	
	// Noise variation along ring
	vec2 noise_uv = UV + vec2(TIME * 0.2, TIME * 0.1);
	float noise_val = texture(noise_texture, noise_uv).r * 0.4;
	wave_mask *= (0.8 + noise_val);
	
	// Normalized outward direction
	vec2 dir = normalize(uv_offset + vec2(0.0001));
	vec2 screen_uv = SCREEN_UV;
	
	// Displace screen UV outwards
	vec2 disp = dir * wave_mask * distortion_strength * (1.0 - progress);
	
	// Chromatic aberration sampling
	float r = texture(screen_texture, screen_uv - disp * (1.0 + chromatic_aberration)).r;
	float g = texture(screen_texture, screen_uv - disp).g;
	float b = texture(screen_texture, screen_uv - disp * (1.0 - chromatic_aberration)).b;
	
	vec4 screen_col = vec4(r, g, b, 1.0);
	
	// Add luminous golden crest to the wave
	vec4 wave_glow = tint_color * wave_mask * (1.0 - progress) * 1.5;
	
	COLOR = mix(screen_col, screen_col + wave_glow, wave_mask);
}
