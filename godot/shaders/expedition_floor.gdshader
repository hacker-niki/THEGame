shader_type spatial;
render_mode unshaded;
uniform int climate;
uniform vec4 base_color : source_color;
uniform vec4 line_color : source_color;
varying vec2 ground;
void vertex() { ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 13541.4); }
float cell_border(vec2 p) {
	vec2 tile = floor(p);
	vec2 xy = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 id = vec2(float(i), float(j));
			vec2 seed = tile + id;
			vec2 center = id + 0.23 + 0.54 * vec2(hash(seed), hash(seed + 74.1));
			float d = dot(center - xy, center - xy);
			second = min(second, max(first,d));
			first = min(first, d);
		}
	}
	return second - first;
}
void fragment() {
	vec2 p = ground;
	float fade = 1.0 - smoothstep(90.0, 320.0, distance(ground, CAMERA_POSITION_WORLD.xz));
	vec3 col = base_color.rgb;
	if (climate == 0 || climate == 2) {
		float boundary = cell_border(p * (climate == 0 ? 0.12 : 0.069));
		float crack = 1.0 - smoothstep(0.013, 0.035, boundary);
		col = mix(col, line_color.rgb, crack * fade * 0.70);
		if (climate == 0) {
			float pools = sin(p.y * 0.064) * 0.49 + sin(p.x * 0.081 + sin(p.y * 0.055)) * 0.68;
			col = mix(col, line_color.rgb, smoothstep(0.82, 1.00, pools) * 0.48);
		}
	} else if (climate == 1) {
		float river = abs(sin(p.x * 0.037 + sin(p.y * 0.052) * 0.49 + sin(p.y * 0.022)) - 0.18);
		col = mix(line_color.rgb, col, smoothstep(0.12, 0.19, river));
	} else if (climate == 3) {
		float seam = cell_border(p * 0.066);
		col = mix(col, line_color.rgb, (1.0 - smoothstep(0.007, 0.023, seam)) * 0.74 * fade);
	} else {
		float ripple = fract(p.y * 0.37 + sin(p.x * 0.23 + p.y * 0.072) * 0.43);
		col = mix(col, line_color.rgb, (1.0 - smoothstep(0.04, 0.16, ripple)) * 0.36 * fade);
	}
	ALBEDO = col;
}
