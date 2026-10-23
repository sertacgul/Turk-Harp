shader_type spatial;
render_mode cull_back;
// Prosedürel arazi: köşe rengi (biyom) üzerine büyük ölçekli renk lekeleri, toprak/çimen benekleri,
// eğime göre katmanlı kaya, su kenarında ıslak kum ve gürültüden türetilmiş mikro kabartma.

uniform vec3 rock_color : source_color = vec3(0.47, 0.43, 0.37);
uniform vec3 dirt_color : source_color = vec3(0.45, 0.36, 0.26);
uniform float detail_strength = 1.0;
uniform int octaves = 5;

varying vec3 wpos;
varying vec3 wnorm;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p, int n) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 8; i++) {
		if (i >= n) break;
		v += a * vnoise(p);
		p = p * 2.02 + vec3(3.1, 1.7, 5.3);
		a *= 0.5;
	}
	return v;
}

float bump(vec3 p, float rock) {
	return fbm(p * 0.35, octaves) * (1.0 + rock * 1.5) + vnoise(p * 4.0) * 0.12;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float dist = length(CAMERA_POSITION_WORLD - wpos);
	float near = 1.0 - smoothstep(60.0, 400.0, dist);
	float slope = 1.0 - clamp(wnorm.y, 0.0, 1.0);
	float rock = smoothstep(0.32, 0.55, slope + (fbm(wpos * 0.05, 3) - 0.5) * 0.3);

	// Köşe renkleri sRGB olarak yazıldı; ışık hesabı doğrusal renkle yapılır.
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	float macro = fbm(wpos * 0.012, 4);
	base *= 0.78 + macro * 0.45;
	// Çimen/toprak benekleri
	float patch = smoothstep(0.42, 0.62, fbm(wpos * 0.09, 4));
	base = mix(base, base * vec3(1.05, 0.95, 0.82) * 0.9 + dirt_color * 0.15, patch * 0.5);
	float speck = vnoise(wpos * 2.5);
	base *= mix(1.0, 0.85 + speck * 0.3, near);
	// Katmanlı kaya
	float strata = 0.82 + 0.18 * sin(wpos.y * 0.9 + fbm(wpos * 0.08, 3) * 6.0);
	vec3 rc = rock_color * strata * (0.85 + vnoise(wpos * 0.7) * 0.3);
	base = mix(base, rc, rock);
	// Su kenarında ıslak kum
	float wet = 1.0 - smoothstep(0.3, 1.6, wpos.y);
	base *= 1.0 - wet * 0.35;

	// Mikro kabartma: gürültünün eğiminden normal sapması
	float e = 0.25;
	float h0 = bump(wpos, rock);
	float hx = bump(wpos + vec3(e, 0, 0), rock);
	float hz = bump(wpos + vec3(0, 0, e), rock);
	vec3 g = vec3(hx - h0, 0.0, hz - h0) / e;
	vec3 n = normalize(wnorm - g * detail_strength * (0.6 + rock) * (0.3 + 0.7 * near));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = base;
	ROUGHNESS = mix(mix(0.95, 0.78, rock), 0.35, wet * (1.0 - rock));
	SPECULAR = 0.35;
}
