shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform float track_width;
uniform float beat_strength = 0.0;
uniform vec4 edge_color : source_color;
uniform vec4 surface_color : source_color = vec4(0.125, 0.101, 0.155, 1.0);
uniform vec4 side_color : source_color = vec4(0.087, 0.073, 0.13, 1.0);
uniform vec4 shoulder_color : source_color = vec4(0.24, 0.19, 0.255, 1.0);
uniform vec4 lane_paint : source_color = vec4(0.48, 0.39, 0.42, 1.0);
uniform vec4 warm_paint : source_color = vec4(0.98, 0.53, 0.43, 1.0);
varying vec3 local_pos;
varying vec3 local_normal;

float stripe(float d, float width, float aa) {
	return 1.0 - smoothstep(width - aa, width + aa, abs(d));
}
void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}
void fragment() {
	float x = abs(local_pos.x);
	float z = -(MODEL_MATRIX * vec4(local_pos, 1.0)).z;
	float edge = track_width * 0.5 - x;
	float pixel = clamp(fwidth(local_pos.x) * 0.66, 0.002, 0.13);
	vec3 col = side_color.rgb;
	if (local_normal.y > 0.5) {
		col = surface_color.rgb;
		float seam = stripe(mod(z + 3.0, 12.0) - 6.0, 0.022, clamp(fwidth(z), 0.003, 0.07));
		col = mix(col, side_color.rgb * 0.63, seam * 0.82);
		col = mix(col, shoulder_color.rgb, 1.0 - smoothstep(0.86, 0.90, edge));
		float dash = smoothstep(0.06, 0.13, mod(z + 2.0, 7.6)) * (1.0 - smoothstep(3.2, 3.29, mod(z + 2.0, 7.6)));
		col = mix(col, lane_paint.rgb, stripe(x - track_width / 6.0, 0.032, pixel) * dash * 0.67);
		float ticks = step(mod(z + 40000.0, 2.0), 0.075) * (1.0 - smoothstep(0.13, 0.44, abs(edge - 0.83)));
		col = mix(col, lane_paint.rgb, ticks * 0.66);
		float diagonals = step(0.56, fract((z + edge * 1.9) * 0.47));
		float kerb = smoothstep(0.13, 0.17, edge) * (1.0 - smoothstep(0.42, 0.46, edge));
		col = mix(col, warm_paint.rgb, kerb * diagonals * 0.82);
		col = mix(col, edge_color.rgb, stripe(edge - 0.68, 0.045, pixel) * 0.87);
		col = mix(col, edge_color.rgb, stripe(edge - 0.075, 0.038, pixel));
	} else {
		col = mix(col, shoulder_color.rgb, step(0.24, local_pos.y));
	}
	float rim = stripe(edge - 0.7, 0.11, pixel);
	EMISSION = edge_color.rgb * rim * beat_strength * 0.67 * step(0.5, local_normal.y);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
