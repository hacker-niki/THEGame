shader_type sky;

uniform vec4 zenith : source_color;
uniform vec4 middle : source_color;
uniform vec4 horizon : source_color;
uniform vec4 sun_top : source_color;
uniform vec4 sun_base : source_color;
uniform vec4 far_ridge : source_color;
uniform vec4 near_ridge : source_color;
uniform float sector = 0.0;

float rand(float n) {
	return fract(sin(n * 41.713 + 43.21) * 13758.545);
}

// Straight segments give successive ridgelines the same cut-paper silhouette as the terrain.
float ridge(float x, float seed) {
	float i = floor(x);
	return mix(rand(i + seed), rand(i + 1.0 + seed), fract(x));
}

void sky() {
	float azimuth = atan(EYEDIR.x, -EYEDIR.z);
	vec2 p = vec2(azimuth, asin(clamp(EYEDIR.y, -1.0, 1.0)));
	vec2 sun = vec2(0.32 + sector * 0.023, 0.132 + sector * 0.008);
	float h = clamp(p.y, 0.0, 1.0);
	vec3 c = mix(horizon.rgb, middle.rgb, smoothstep(-0.035, 0.28, h));
	c = mix(c, zenith.rgb, smoothstep(0.12, 0.65, h));

	float dist = distance(p, sun);
	c = mix(c, sun_base.rgb, 0.2 * exp(-dist * 4.8));
	float star_row = floor(p.y * 260.0);
	float star_id = floor(p.x * 260.0) + star_row * 641.0;
	vec2 star_xy = fract(p * 260.0) - vec2(rand(star_id + 1.0), rand(star_id + 54.1));
	float stars = (1.0 - smoothstep(0.06, 0.20, length(star_xy))) * step(0.988, rand(star_id));
	c = mix(c, vec3(0.90, 0.82, 0.83), stars * smoothstep(0.11, 0.42, h) * 0.55);

	float radius = 0.135;
	float disk = 1.0 - smoothstep(radius - 0.0006, radius + 0.0006, dist);
	float disk_height = (p.y - sun.y) / radius;
	float gap = (1.0 - smoothstep(-0.93, 0.12, disk_height)) * 0.67;
	float raster = fract(disk_height * 6.6 + 0.4);
	float stripes = mix(1.0, smoothstep(gap - 0.026, gap + 0.026, raster), smoothstep(0.00, 0.07, gap));
	vec3 disk_color = mix(sun_base.rgb, sun_top.rgb, smoothstep(-0.85, 0.73, disk_height));
	c = mix(c, disk_color, disk * stripes);

	// Narrow bands of wind-blown cloud pick up the last light.
	float row = floor((p.y + 1.0) * 110.0);
	float cloud_detail = ridge(p.x * 7.5 + row * 19.0, 2.4);
	float cloud = smoothstep(0.77, 0.91, cloud_detail) * (1.0 - smoothstep(0.06, 0.17, fract((p.y + 1.0) * 110.0)));
	c = mix(c, horizon.rgb, cloud * 0.32 * smoothstep(0.05, 0.14, h) * (1.0 - smoothstep(0.29, 0.4, h)));

	for (int i = 0; i < 3; i++) {
		float layer = float(i);
		float x = azimuth * (7.5 + layer * 2.0) + sector * 1.47;
		float valley = mix(0.62, 1.0, smoothstep(0.03, 0.55, abs(azimuth)));
		float outline = (0.105 - layer * 0.024) * (ridge(x, layer * 23.0 + 3.0) + ridge(x * 2.7, layer * 6.0 + 7.0) * 0.28) * valley - 0.006;
		float facet = smoothstep(-0.012, 0.004, ridge(x, layer * 23.0 + 3.0) - ridge(x + 0.008, layer * 23.0 + 3.0));
		vec3 rock = mix(far_ridge.rgb, near_ridge.rgb, layer * 0.41);
		rock = mix(rock, horizon.rgb, facet * (0.10 - layer * 0.019));
		c = mix(c, rock, 1.0 - smoothstep(outline - 0.00035, outline + 0.00035, p.y));
	}
	COLOR = c;
}
