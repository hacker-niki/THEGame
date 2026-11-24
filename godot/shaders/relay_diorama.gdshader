shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D palette : source_color, filter_nearest, repeat_disable;
void fragment() {
	vec3 original = texture(palette, UV).rgb;
	float lightness = dot(original, vec3(0.30, 0.58, 0.12));
	ALBEDO = mix(vec3(lightness), original, 0.60) * vec3(0.91, 0.74, 0.78);
	ROUGHNESS = 1.0;
}
