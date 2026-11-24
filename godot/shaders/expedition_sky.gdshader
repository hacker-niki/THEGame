shader_type sky;

uniform int climate;
uniform vec4 zenith : source_color;
uniform vec4 middle : source_color;
uniform vec4 horizon : source_color;
uniform vec4 sun_top : source_color;
uniform vec4 sun_base : source_color;
uniform vec4 far_ridge : source_color;
uniform vec4 near_ridge : source_color;

float hash(float p) { return fract(sin(p * 27.53 + 7.12) * 13542.01); }
float crest(float x, float seed) {
	float i = floor(x);
	return mix(hash(i + seed), hash(i + 1.0 + seed), fract(x));
}
float circle(vec2 p, float radius) { return 1.0 - smoothstep(radius - 0.0008, radius + 0.0008, length(p)); }
float ring(vec2 p, float radius, float width) {
	return 1.0 - smoothstep(width, width + 0.0012, abs(length(p) - radius));
}
void sky() {
	vec2 p = vec2(atan(EYEDIR.x, -EYEDIR.z), asin(clamp(EYEDIR.y, -1.0, 1.0)));
	float h = max(p.y, 0.0);
	vec3 color = mix(horizon.rgb, middle.rgb, smoothstep(-0.055, 0.29, h));
	color = mix(color, zenith.rgb, smoothstep(0.08, 0.78, h));
	vec2 star;
	float radius;
	if (climate == 0) { star = vec2(0.30, 0.25); radius = 0.054; }
	else if (climate == 1) { star = vec2(-0.30, 0.13); radius = 0.094; }
	else if (climate == 2) { star = vec2(0.23, 0.25); radius = 0.061; }
	else if (climate == 3) { star = vec2(0.34, 0.21); radius = 0.073; }
	else { star = vec2(0.12, 0.16); radius = 0.145; }
	vec2 to_star = p - star;
	float disc = circle(to_star, radius);
	if (climate == 3) {
		// Curtains run east to west, with rayed folds in both green and violet.
		float arc = 0.105 + 0.10 * sin(4.5 * p.x + 0.5) + 0.055 * sin(9.5 * p.x + 1.0);
		float height = p.y - arc;
		float curtain = smoothstep(-0.012, 0.03, height) * exp(-max(0.0, height) * 8.6);
		float ray = 0.67 + 0.33 * crest(p.x * 97.0 + sin(p.x * 8.0) * 2.0, 71.0);
		vec3 aurora = mix(vec3(0.15, 0.85, 0.71), vec3(0.58, 0.36, 0.89), smoothstep(0.0, 0.17, height));
		color = mix(color, aurora, curtain * ray * 0.74);
		vec2 grid = p * 233.0;
		float id = floor(grid.x) + floor(grid.y) * 471.0;
		float point = length(fract(grid) - vec2(hash(id), hash(id + 374.0)));
		float stars = step(0.979, hash(id + 17.0)) * (1.0 - smoothstep(0.085, 0.26, point));
		color = mix(color, vec3(0.91, 0.93, 1.0), stars * 0.83);
		disc *= 1.0 - circle(to_star - vec2(-0.034, 0.022), radius * 0.99);
	} else if (climate == 0 || climate == 2) {
		color = mix(color, sun_top.rgb, ring(to_star, radius * 1.64, 0.0014) * 0.34);
		float cloudline = 0.12 + 0.033 * sin(p.x * 4.0) + 0.014 * p.x;
		float cloud = exp(-abs(p.y - cloudline) * 180.0) + 0.35 * exp(-abs(p.y - cloudline - 0.03) * 210.0);
		color = mix(color, vec3(0.97, 0.97, 0.99), min(0.44, cloud * crest(p.x * 3.0, 6.0)));
	} else if (climate == 1) {
		float dust = crest(p.x * 3.0 + floor(p.y * 83.0) * 11.1, 8.0);
		color = mix(color, horizon.rgb, 0.17 * dust * smoothstep(0.04, 0.12, h) * (1.0 - smoothstep(0.20, 0.34, h)));
	} else {
		color = mix(color, sun_top.rgb, ring(to_star, radius * 1.21, 0.0018) * 0.80);
		color = mix(color, sun_base.rgb, ring(to_star, radius * 1.40, 0.0011) * 0.54);
	}
	float glow = exp(-length(to_star) / radius * 1.17);
	color = mix(color, sun_base.rgb, glow * (climate == 3 ? 0.055 : 0.25));
	color = mix(color, mix(sun_base.rgb, sun_top.rgb, smoothstep(-radius, radius, to_star.y)), disc);
	for (int layer = 0; layer < 3; layer++) {
		float l = float(layer);
		float u = p.x * (6.0 + l * 1.43) + float(climate * 3);
		float jag = crest(u, 8.0 + l * 29.0) + 0.26 * crest(u * 2.6, l * 9.0);
		float relief = 0.11;
		if (climate == 0) relief = 0.035;
		if (climate == 1) jag = mix(jag, smoothstep(0.31, 0.47, jag) * 0.72, 0.65);
		if (climate == 2 || climate == 3) relief = 0.165;
		float outline = relief * (1.0 - l * 0.27) * jag - 0.009 * l;
		vec3 rock = mix(far_ridge.rgb, near_ridge.rgb, l * 0.4);
		float facet = smoothstep(-0.004, 0.005, crest(u, 8.0 + l * 29.0) - crest(u + 0.01, 8.0 + l * 29.0));
		if (climate == 2) {
			float snow = smoothstep(outline * 0.44, outline * 0.94, p.y) * mix(0.23, 0.9, facet);
			rock = mix(rock, sun_top.rgb, snow);
		} else {
			rock = mix(rock, horizon.rgb, facet * 0.13);
		}
		color = mix(color, rock, 1.0 - smoothstep(outline - 0.0005, outline + 0.0005, p.y));
	}
	COLOR = color;
}
