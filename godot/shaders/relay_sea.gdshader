shader_type spatial;
render_mode unshaded;
uniform vec4 deep_color : source_color;
uniform vec4 ripple_color : source_color;
uniform vec4 reflection : source_color;
varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(135.3, 61.7))) * 13758.545);
}
void fragment() {
	vec2 p = world_pos.xz;
	float row = floor(p.y * 1.7);
	vec2 cell = vec2(floor(p.x / 5.0 + row), row);
	float n = hash21(cell);
	float line = abs(fract(p.y * 1.7) - 0.5);
	float aa = clamp(fwidth(p.y) * 0.65, 0.012, 0.2);
	float ripple = (1.0 - smoothstep(0.045, 0.045 + aa, line)) * smoothstep(0.40, 0.91, n);
	float x = fract(p.x / 5.0 + row);
	ripple *= smoothstep(0.22, 0.48, x) * (1.0 - smoothstep(0.70, 0.97, x));
	ripple *= 0.76 + 0.24 * sin(n * 15.0 + TIME * 1.3);
	vec3 eye = normalize(world_pos - CAMERA_POSITION_WORLD);
	float shine = exp(-abs(eye.x - 0.2) * 8.0);
	ALBEDO = mix(deep_color.rgb, mix(ripple_color.rgb, reflection.rgb, shine), ripple * 0.75);
}
