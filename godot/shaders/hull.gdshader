shader_type spatial;
uniform vec4 paint : source_color = vec4(0.125,0.72,0.78,1.0);

void vertex() {
	vec3 core = clamp(VERTEX, vec3(-0.416), vec3(0.416));
	vec3 bevel_normal = normalize(VERTEX - core);
	VERTEX = core + bevel_normal * 0.084;
	NORMAL = bevel_normal;
}

void fragment() {
	ALBEDO = paint.rgb;
	ROUGHNESS = 0.36;
	METALLIC = 0.14;
	EMISSION = paint.rgb * 0.12;
}
