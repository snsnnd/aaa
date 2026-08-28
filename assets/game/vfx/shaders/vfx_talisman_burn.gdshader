shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D dissolve_noise : filter_linear_mipmap, repeat_enable;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float burn_width : hint_range(0.0, 0.2) = 0.08;
uniform vec4 burn_color_hot : source_color = vec4(1.0, 0.95, 0.4, 1.0);
uniform vec4 burn_color_edge : source_color = vec4(0.9, 0.22, 0.12, 1.0);
uniform vec4 ash_color : source_color = vec4(0.12, 0.08, 0.06, 1.0);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	if (tex_color.a < 0.01) {
		discard;
	}

	float noise = texture(dissolve_noise, UV).r;
	
	// Threshold for dissolution
	float threshold = dissolve_amount * 1.1 - 0.05;
	
	if (noise < threshold) {
		discard; // Burned away completely
	}
	
	float edge_dist = noise - threshold;
	
	if (edge_dist < burn_width * 0.35) {
		// Hot white/yellow inner burn line
		COLOR = vec4(burn_color_hot.rgb, tex_color.a);
	} else if (edge_dist < burn_width) {
		// Fiery cinnabar red outer burning border
		float t = (edge_dist - burn_width * 0.35) / (burn_width * 0.65);
		vec3 fire_col = mix(burn_color_hot.rgb, burn_color_edge.rgb, t);
		COLOR = vec4(fire_col, tex_color.a);
	} else if (edge_dist < burn_width * 1.6) {
		// Scorched ash transition
		float t = (edge_dist - burn_width) / (burn_width * 0.6);
		vec3 charred = mix(ash_color.rgb, tex_color.rgb, t);
		COLOR = vec4(charred, tex_color.a);
	} else {
		// Normal paper texture
		COLOR = tex_color;
	}
}
