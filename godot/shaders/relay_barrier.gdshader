shader_type spatial;
render_mode unshaded;

uniform vec4 top_color : source_color;
uniform vec4 front_color : source_color;
uniform vec4 dark_color : source_color;
uniform vec4 light_color : source_color;
varying vec3 face;
varying vec3 box_position;
void vertex() {
	face = NORMAL;
	box_position = VERTEX;
}
void fragment() {
	vec2 marking = vec2(box_position.x + 0.5, 0.5 - box_position.y);
	vec3 c = mix(dark_color.rgb, front_color.rgb, 0.37);
	if (abs(face.z) > 0.7) {
		c = front_color.rgb;
		// A dark inset with paired retroreflective slashes visibly faces approaching players.
		float panel = smoothstep(0.10, 0.12, marking.x) * (1.0 - smoothstep(0.88, 0.90, marking.x));
		panel *= smoothstep(0.23, 0.26, marking.y) * (1.0 - smoothstep(0.73, 0.76, marking.y));
		c = mix(c, dark_color.rgb, panel * 0.94);
		float slant = marking.x + (marking.y - 0.50) * 0.175;
		float stripes = max(step(0.18, slant) * step(slant, 0.255), step(0.31, slant) * step(slant, 0.385));
		c = mix(c, light_color.rgb, stripes * panel);
		float grille = step(0.59, marking.x) * step(marking.x, 0.84) * step(0.51, fract(marking.y * 13.0));
		c = mix(c, front_color.rgb, grille * panel * 0.53);
	} else if (face.y > 0.7) {
		marking.y = box_position.z + 0.5;
		c = top_color.rgb;
		float rail = step(0.045, marking.y) * step(marking.y, 0.13);
		c = mix(c, light_color.rgb, rail * 0.85);
		c = mix(c, front_color.rgb, step(0.75, marking.x) * step(marking.x, 0.783));
	}
	ALBEDO = c;
}
