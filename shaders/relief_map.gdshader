shader_type spatial;
render_mode cull_back;
// Kurmay haritası görünümlü kabartma: yükseklik renk kademeleri, eş yükselti eğrileri, kıyı mürekkep çizgisi,
// denizde kıyıya paralel çizgiler, kâğıt dokusu ve altıgen ızgara (vurgular veri dokusundan okunur).

// R: yükseklik (metre), G: kıyıya uzaklık (metre; karada 0)
uniform sampler2D height_tex : filter_linear;
// Altıgen başına RGBA8: R vurgu (1 hareket, 2 saldırı, 3 seçili, 4 yol), G kontrol (1 Osmanlı, 2 İtilaf),
// B görüş (255 görünür), A hedef
uniform sampler2D hex_tex : filter_nearest;
uniform vec2 map_size_m = vec2(10000.0, 10000.0);
uniform vec2 world_size = vec2(120.0, 120.0);
uniform float hex_radius = 200.0;
uniform vec2 hex_origin = vec2(173.0, 200.0);
uniform vec2 hex_count = vec2(30.0, 30.0);
uniform float grid_alpha = 0.2;
uniform float contour_step = 20.0;
uniform float time_scale = 1.0;

varying vec2 local_m;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// Değerin "step" katlarına yakınlığı: 1 çizgi üstünde, 0 uzakta (ekran uzayında sabit kalınlık).
float iso_line(float v, float step, float width) {
	float f = v / step;
	float d = abs(fract(f - 0.5) - 0.5) / max(fwidth(f), 1e-3);
	return 1.0 - smoothstep(width * 0.5, width * 0.5 + 1.0, d);
}

vec2 axial_round(vec2 qr) {
	vec3 c = vec3(qr.x, qr.y, -qr.x - qr.y);
	vec3 r = round(c);
	vec3 d = abs(r - c);
	if (d.x > d.y && d.x > d.z) {
		r.x = -r.y - r.z;
	} else if (d.y > d.z) {
		r.y = -r.x - r.z;
	}
	return r.xy;
}

void vertex() {
	local_m = (VERTEX.xz / world_size + 0.5) * map_size_m;
}

void fragment() {
	vec2 uv = local_m / map_size_m;
	vec2 hd = texture(height_tex, uv).rg;
	float h = hd.r;
	float shore = hd.g;
	float paper = fbm(local_m * 0.004) * 0.6 + fbm(local_m * 0.05) * 0.4;
	vec3 col;
	float line_ink = 0.0;
	if (h > 0.4) {
		// Kara: kademeli renk (ova yeşilimsi, tepeler toprak rengi)
		vec3 c0 = vec3(0.84, 0.85, 0.74);
		vec3 c1 = vec3(0.86, 0.82, 0.70);
		vec3 c2 = vec3(0.80, 0.71, 0.58);
		vec3 c3 = vec3(0.70, 0.60, 0.50);
		col = mix(c0, c1, smoothstep(0.0, 90.0, h));
		col = mix(col, c2, smoothstep(90.0, 220.0, h));
		col = mix(col, c3, smoothstep(220.0, 420.0, h));
		// Maki ve çalılık lekeleri (haritacının yeşil tarama alanları)
		float scrub = smoothstep(0.52, 0.66, fbm(local_m * 0.0016 + 7.0));
		col = mix(col, vec3(0.70, 0.76, 0.58), scrub * 0.45);
		col *= 0.92 + paper * 0.16;
		// Eş yükselti eğrileri: ince her contour_step, kalın her 5 katında
		float minor = iso_line(h, contour_step, 0.8);
		float major = iso_line(h, contour_step * 5.0, 1.1);
		col = mix(col, vec3(0.52, 0.36, 0.22), minor * 0.35);
		col = mix(col, vec3(0.45, 0.28, 0.16), major * 0.45);
	} else {
		// Deniz: kıyıdan açığa koyulaşan mavi ve kıyıya paralel çizgiler (eski harita üslubu)
		float t = clamp(shore / 1800.0, 0.0, 1.0);
		col = mix(vec3(0.66, 0.78, 0.82), vec3(0.42, 0.58, 0.69), sqrt(t));
		col *= 0.95 + paper * 0.1;
		float ripples = iso_line(shore, 90.0, 0.7) * (1.0 - smoothstep(0.0, 500.0, shore));
		col = mix(col, vec3(0.3, 0.45, 0.58), ripples * 0.5);
	}
	// Kıyı mürekkep çizgisi
	float coast = 1.0 - smoothstep(1.0, 2.2, abs(h - 0.4) / max(fwidth(h), 0.05));
	col = mix(col, vec3(0.18, 0.24, 0.3), coast * 0.85);

	// Altıgen ızgara
	vec2 lp = local_m - hex_origin;
	vec2 qr = vec2((sqrt(3.0) / 3.0 * lp.x - lp.y / 3.0) / hex_radius, (2.0 / 3.0 * lp.y) / hex_radius);
	vec2 a = axial_round(qr);
	vec2 cen = vec2(hex_radius * sqrt(3.0) * (a.x + a.y * 0.5), hex_radius * 1.5 * a.y);
	vec2 p = abs(lp - cen);
	float d = max(p.x, dot(p, vec2(0.5, sqrt(3.0) * 0.5)));
	float inner = hex_radius * sqrt(3.0) * 0.5;
	float edge_px = (inner - d) / max(fwidth(d), 1e-4);
	float edge = 1.0 - smoothstep(0.3, 1.2, edge_px);
	float row = a.y;
	float colx = a.x + floor(row / 2.0);
	vec2 cell = vec2(colx, row);
	vec4 hx = vec4(0.0, 0.0, 1.0, 0.0);
	bool inside = cell.x >= 0.0 && cell.y >= 0.0 && cell.x < hex_count.x && cell.y < hex_count.y;
	if (inside) {
		hx = texture(hex_tex, (cell + 0.5) / hex_count);
	}
	int mark = int(hx.r * 255.0 + 0.5);
	int ctl = int(hx.g * 255.0 + 0.5);
	float rim = 1.0 - smoothstep(0.0, hex_radius * 0.18, inner - d);
	// Görülmeyen hücreler hafif soluk
	vec3 faded = mix(col, vec3(dot(col, vec3(0.33))), 0.45) * 0.93;
	col = mix(faded, col, hx.b);
	if (hx.a > 0.5) {
		vec3 oc = ctl == 1 ? vec3(0.75, 0.1, 0.12) : (ctl == 2 ? vec3(0.2, 0.32, 0.62) : vec3(0.4));
		col = mix(col, oc, rim * 0.55 + 0.08);
	}
	if (mark == 1) {
		col = mix(col, vec3(1.0, 0.86, 0.35), 0.28 + rim * 0.35);
	} else if (mark == 2) {
		col = mix(col, vec3(0.95, 0.15, 0.1), 0.3 + rim * 0.5);
	} else if (mark == 3) {
		col = mix(col, vec3(1.0, 0.95, 0.6), rim * 0.9);
	} else if (mark == 4) {
		col = mix(col, vec3(1.0, 0.75, 0.2), 0.45 + rim * 0.4);
	}
	vec3 grid_col = h > 0.4 ? vec3(0.25, 0.2, 0.15) : vec3(0.95, 0.97, 1.0);
	col = mix(col, grid_col, edge * grid_alpha * (inside ? 1.0 : 0.0));

	// Renkler sRGB olarak seçildi; ışık hesabı doğrusal uzayda.
	ALBEDO = pow(col, vec3(2.2));
	ROUGHNESS = h > 0.4 ? 0.92 : 0.55;
	SPECULAR = h > 0.4 ? 0.2 : 0.4;
}
