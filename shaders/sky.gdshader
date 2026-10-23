shader_type sky;
// Gerçekçi gökyüzü: ufuk-zenit geçişi, güneş diski ve halesi, hareketli fbm bulutlar, gece yıldızları.

uniform vec3 zenith_color : source_color = vec3(0.18, 0.38, 0.7);
uniform vec3 horizon_color : source_color = vec3(0.68, 0.78, 0.88);
uniform vec3 ground_color : source_color = vec3(0.3, 0.32, 0.33);
uniform vec3 cloud_color : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_shade : source_color = vec3(0.55, 0.6, 0.68);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_speed = 0.004;
uniform float sun_size = 0.03;
uniform float star_amount : hint_range(0.0, 1.0) = 0.0;
uniform float exposure = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 6; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon_color, zenith_color, pow(clamp(h, 0.0, 1.0), 0.5));
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-h * 5.0, 0.0, 1.0));
	}
	vec3 sun_dir = LIGHT0_DIRECTION;
	float sa = max(dot(d, sun_dir), 0.0);
	vec3 sun_col = LIGHT0_COLOR * LIGHT0_ENERGY;
	// Güneşe doğru ufuk ısınır (Mie saçılması yaklaşımı)
	col += sun_col * (pow(sa, 6.0) * 0.18 + pow(sa, 40.0) * 0.35) * (1.0 - clamp(h, 0.0, 1.0) * 0.6);
	float disk = smoothstep(cos(sun_size), cos(sun_size * 0.7), sa);
	col += sun_col * disk * 12.0;

	if (h > 0.0) {
		float t = TIME * cloud_speed;
		vec2 uv = d.xz / (h + 0.12) * 0.9;
		float n = fbm(uv + vec2(t, t * 0.3));
		float n2 = fbm(uv * 2.7 - vec2(t * 1.7, 0.0));
		float density = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.32, n * 0.8 + n2 * 0.25);
		// Bulutun güneş tarafı parlak, gövdesi gölgeli
		float lit = clamp(fbm(uv + sun_dir.xz * 0.06 + vec2(t, t * 0.3)) - n + 0.55, 0.0, 1.0);
		vec3 cc = mix(cloud_shade, cloud_color, lit) * (0.35 + 0.65 * LIGHT0_ENERGY);
		cc += sun_col * pow(sa, 8.0) * 0.4 * (1.0 - density);
		col = mix(col, cc, density * smoothstep(0.0, 0.12, h) * 0.95);
		if (star_amount > 0.0) {
			vec2 sp = d.xz / (h + 0.3) * 160.0;
			float s = step(0.9965, hash(floor(sp))) * (1.0 - density);
			col += vec3(s) * star_amount * smoothstep(0.0, 0.2, h);
		}
	}
	COLOR = col * exposure;
}
