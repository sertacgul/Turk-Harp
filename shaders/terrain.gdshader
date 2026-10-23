shader_type spatial;
render_mode cull_back;
// Prosedürel arazi: köşe rengi (biyom) üzerine büyük ölçekli renk lekeleri, toprak/çimen benekleri,
// eğime göre katmanlı kaya, su kenarında ıslak kum ve gürültüden türetilmiş mikro kabartma.

uniform vec3 rock_color : source_color = vec3(0.47, 0.43, 0.37);
uniform vec3 dirt_color : source_color = vec3(0.45, 0.36, 0.26);
uniform float detail_strength = 1.0;
uniform int octaves = 5;
// İsteğe bağlı fotogerçekçi PBR katmanları (assets/textures, AssetLib.apply_terrain_textures).
uniform bool textured = false;
uniform float texture_mix = 0.7;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile = 0.25;

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

// Yakında ayrıntılı, uzakta daha seyrek iki ölçekli örnekleme: tekrar deseni kırılır.
vec4 layer(sampler2D t, vec2 uv, float near) {
	vec4 a = texture(t, uv);
	vec4 b = texture(t, uv * 0.23 + vec2(0.37, 0.71));
	return mix(b, mix(b, a, 0.65), near);
}

// Kaya için üç eksenli (triplanar) izdüşüm: dik yamaçlarda doku esnemez.
vec4 tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy) * w.x + texture(t, p.xz) * w.y + texture(t, p.xy) * w.z;
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
	float rough = mix(mix(0.95, 0.78, rock), 0.35, wet * (1.0 - rock));
	if (textured) {
		vec2 uv = wpos.xz * tile;
		vec3 tw = pow(abs(wnorm), vec3(4.0));
		tw /= (tw.x + tw.y + tw.z);
		vec3 tp = wpos * tile * 0.6;
		// Katman ağırlıkları: kumsal, eğimde kaya, gürültüyle toprak lekeleri, kalan yer çimen.
		float sand = (1.0 - smoothstep(1.2, 3.2, wpos.y + (fbm(wpos * 0.06, 2) - 0.5) * 1.5)) * (1.0 - rock);
		float dirt = clamp(patch * 0.8 + (1.0 - near) * 0.1, 0.0, 1.0) * (1.0 - rock) * (1.0 - sand);
		float grass = (1.0 - rock) * (1.0 - sand) * (1.0 - dirt);
		vec4 ga = layer(grass_albedo, uv, near);
		vec4 da = layer(dirt_albedo, uv * 1.3, near);
		vec4 sa = layer(sand_albedo, uv * 1.1, near);
		vec4 ra = tri(rock_albedo, tp, tw);
		vec3 tex = ga.rgb * grass + da.rgb * dirt + sa.rgb * sand + ra.rgb * rock;
		// Dokunun ortalama rengi (en küçük mip) ile biyom rengine göre tonlanır: harita renkleri korunur.
		vec3 avg = textureLod(grass_albedo, vec2(0.5), 12.0).rgb * grass + textureLod(dirt_albedo, vec2(0.5), 12.0).rgb * dirt
			+ textureLod(sand_albedo, vec2(0.5), 12.0).rgb * sand + textureLod(rock_albedo, vec2(0.5), 12.0).rgb * rock;
		vec3 tinted = tex / max(avg, vec3(0.02)) * base;
		base = mix(tinted, tex * (0.75 + macro * 0.5), texture_mix * 0.5);
		base *= 1.0 - wet * 0.25;
		vec3 tn = (layer(grass_normal, uv, near).xyz * grass + layer(dirt_normal, uv * 1.3, near).xyz * dirt
			+ layer(sand_normal, uv * 1.1, near).xyz * sand + tri(rock_normal, tp, tw).xyz * rock) * 2.0 - 1.0;
		// Teğet uzayı yaklaşık olarak dünya XZ düzlemi (çimen/toprak/kum düzlemsel izdüşüm).
		n = normalize(n + vec3(tn.x, 0.0, -tn.y) * 0.9 * (0.4 + 0.6 * near));
		// Pürüzlülük: koyu, gölgeli doku bölgeleri daha mat (doku birimi sınırı için ayrı harita yok).
		float lum = dot(tex, vec3(0.3, 0.59, 0.11));
		float tr = mix(0.97, 0.82, rock) - lum * 0.15;
		rough = mix(tr, 0.35, wet * (1.0 - rock));
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = base;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
