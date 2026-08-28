shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 tint_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float brightness_boost : hint_range(1.0, 5.0) = 1.6;
uniform float pulse_speed : hint_range(0.0, 20.0) = 0.0;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_intensity;
	COLOR = tex_color * tint_color * brightness_boost * pulse;
}
