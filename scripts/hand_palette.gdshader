shader_type canvas_item;
render_mode unshaded;

uniform vec4 palette[16] : source_color;

void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	vec3 color = palette[0].rgb;
	float best = 4.0;
	for (int i = 0; i < 16; i++) {
		vec3 difference = sample_color.rgb - palette[i].rgb;
		float distance_squared = dot(difference, difference);
		if (distance_squared < best) {
			best = distance_squared;
			color = palette[i].rgb;
		}
	}
	COLOR = vec4(color, step(0.5, sample_color.a));
}
