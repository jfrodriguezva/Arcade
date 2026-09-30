shader_type canvas_item;

// Paisajes naturales procedurales, uno distinto por nivel (6 escenas que se
// repiten con otra semilla a partir del nivel 7): lago alpino al atardecer,
// playa tropical, bosque con niebla, aurora boreal sobre montañas nevadas,
// cañón desértico y valle verde con río y arcoíris.
//
// Este shader es pesado (fbm, varias capas), así que NO se dibuja cada
// frame: panic_reveal.gd lo hornea una sola vez por nivel en un SubViewport
// (UPDATE_ONCE) y el tablero muestra esa textura ya lista. El tinte de
// "modo monstruo" se aplica aparte (panic_tint.gdshader), barato.
//
// Coordenadas: p = (UV.x * aspect, UV.y) -- y crece hacia abajo, y x va de
// 0 a `aspect` para que círculos y árboles no salgan estirados.

uniform float level = 1.0;
uniform float aspect = 0.7407;

const float AA = 0.0012;  // ~1 px del tablero horneado

// Hashes sin sin(): el clásico fract(sin(x) * 43758.5) pierde precisión
// en float32 con coordenadas grandes y deja "bloques" rectangulares en
// nubes y montañas. Estos (Dave Hoskins) son estables.
float hash1(float n) {
	n = fract(n * 0.1031);
	n *= n + 33.33;
	n *= n + n;
	return fract(n);
}

float hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// Ruido "ridged": crestas afiladas, para perfiles de montaña creíbles.
float ridged(float x, float seed) {
	float v = 0.0;
	float a = 0.5;
	float f = 1.0;
	for (int i = 0; i < 6; i++) {
		float n = 1.0 - abs(vnoise(vec2(x * f + seed, seed * 1.37 + float(i) * 3.1)) * 2.0 - 1.0);
		v += a * n * n;
		f *= 2.1;
		a *= 0.5;
	}
	return v;
}

float ridge_top(float x, float base, float amp, float freq, float seed) {
	return base - amp * ridged(x * freq, seed);
}

// 1 debajo de la línea `top` (y hacia abajo), 0 arriba, con borde suave.
float below(float y, float top) {
	return smoothstep(top - AA, top + AA, y);
}

// Qué tanto le pega la luz a una ladera (luz desde la izquierda). Cerca de
// la cresta se usa la pendiente del perfil; más abajo, la de un relieve 2D
// de ruido -- si solo se usara la del perfil, cada columna tendría la misma
// luz de arriba a abajo y la montaña saldría con rayas verticales.
float ridge_light(vec2 p, float base, float amp, float freq, float seed) {
	float x = p.x;
	float sl = ridge_top(x + 0.008, base, amp, freq, seed) - ridge_top(x - 0.008, base, amp, freq, seed);
	float crest = clamp(0.5 - sl * 22.0, 0.0, 1.0);
	float top = ridge_top(x, base, amp, freq, seed);
	vec2 q = vec2(x * 7.0 + seed, p.y * 4.0 + (p.y - top) * 3.0);
	float hx = fbm(q + vec2(0.03, 0.0)) - fbm(q - vec2(0.03, 0.0));
	float relief = clamp(0.5 - hx * 6.0, 0.0, 1.0);
	return mix(crest, relief, smoothstep(0.0, 0.07, p.y - top));
}

// Distancia a un segmento; .y = posición a lo largo (0..1).
vec2 seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return vec2(length(pa - ba * h), h);
}

// Hilera de pinos parados en y = ground (solo los árboles, sin el suelo).
// `keep` = fracción de huecos que sí tienen árbol (1 = bosque cerrado).
float pines(vec2 p, float ground, float density, float hmin, float hmax, float seed, float keep) {
	float m = 0.0;
	float id = floor(p.x * density);
	for (int k = -1; k <= 1; k++) {
		float cid = id + float(k);
		if (hash1(cid * 5.17 + seed * 0.7) > keep) {
			continue;
		}
		float cx = (cid + 0.5 + (hash1(cid * 7.13 + seed) - 0.5) * 0.7) / density;
		float th = mix(hmin, hmax, hash1(cid * 3.71 + seed * 1.3));
		float top = ground + 0.01 - th;
		float t = (p.y - top) / th;
		if (t > 0.0 && t < 1.2) {
			float tier = fract(t * 4.0);
			float wd = th * 0.26 * min(t, 1.0) * (0.55 + 0.45 * tier);
			m = max(m, 1.0 - smoothstep(wd - AA, wd + AA, abs(p.x - cx)));
			// tronco
			if (t > 0.95) {
				m = max(m, 1.0 - smoothstep(th * 0.025, th * 0.025 + AA, abs(p.x - cx)));
			}
		}
	}
	return m;
}

float stars(vec2 p) {
	vec2 g = p * 90.0;
	vec2 id = floor(g);
	float h = hash2(id);
	if (h < 0.93) {
		return 0.0;
	}
	vec2 off = vec2(hash2(id + 3.1), hash2(id + 7.7)) * 0.6 + 0.2;
	float d = length(fract(g) - off);
	return smoothstep(0.14, 0.0, d) * (h - 0.93) / 0.07;
}

vec3 sun(vec3 col, vec2 p, vec2 c, float r, vec3 glow_col, float glow, float falloff, vec3 disc) {
	float d = distance(p, c);
	col += glow_col * glow * exp(-d * falloff);
	return mix(col, disc, smoothstep(r + AA, r - AA, d));
}

vec3 cumulus(vec3 col, vec2 p, float seed, float bottom) {
	float cn = fbm(vec2(p.x * 4.0 + seed, p.y * 7.0));
	float cm = smoothstep(0.55, 0.68, cn) * smoothstep(bottom, bottom - 0.12, p.y);
	vec3 cc = mix(vec3(0.74, 0.79, 0.90), vec3(1.0), smoothstep(0.58, 0.80, cn));
	return mix(col, cc, cm * 0.95);
}

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

// ------------------------------------------------ 0: lago alpino, atardecer
vec3 lake_above(vec2 p, float seed, float H) {
	float y = p.y;
	vec3 col = mix(vec3(0.10, 0.12, 0.32), vec3(0.58, 0.34, 0.50), smoothstep(0.0, 0.35, y));
	col = mix(col, vec3(1.0, 0.62, 0.30), smoothstep(0.30, H, y));
	col = sun(col, p, vec2(aspect * 0.62, H - 0.11), 0.045, vec3(1.0, 0.55, 0.25), 0.5, 8.0, vec3(1.0, 0.92, 0.70));
	float c = smoothstep(0.52, 0.72, fbm(vec2(p.x * 3.0 + seed, y * 9.0))) * smoothstep(0.46, 0.15, y);
	vec3 cloud_col = mix(vec3(1.0, 0.64, 0.55), vec3(0.45, 0.28, 0.45), smoothstep(0.05, 0.4, y));
	col = mix(col, cloud_col, c * 0.85);

	// cordillera lejana con nieve
	float t1 = ridge_top(p.x, 0.52, 0.30, 2.6, seed);
	float lit = ridge_light(p, 0.52, 0.30, 2.6, seed);
	vec3 rock = mix(vec3(0.30, 0.22, 0.38), vec3(0.66, 0.42, 0.48), lit);
	float snow = 1.0 - smoothstep(0.03, 0.05, y - t1 - 0.04 * vnoise(vec2(p.x * 40.0, y * 30.0)));
	vec3 snow_col = mix(vec3(0.60, 0.52, 0.72), vec3(1.0, 0.84, 0.78), lit);
	vec3 mcol = mix(rock, snow_col, snow);
	mcol = mix(mcol, col, 0.2 + 0.3 * smoothstep(t1, H, y));
	col = mix(col, mcol, below(y, t1));

	// sierra intermedia
	float t2 = ridge_top(p.x, 0.60, 0.12, 4.2, seed + 11.0);
	float lit2 = ridge_light(p, 0.60, 0.12, 4.2, seed + 11.0);
	col = mix(col, mix(vec3(0.14, 0.12, 0.24), vec3(0.30, 0.18, 0.28), lit2), below(y, t2));

	// pinos de la orilla
	float m = pines(p, H, 55.0, 0.015, 0.05, seed, 0.9);
	col = mix(col, vec3(0.05, 0.06, 0.09), m);
	return col;
}

vec3 scene_lake(vec2 p, float seed) {
	float H = 0.64;
	if (p.y < H) {
		return lake_above(p, seed, H);
	}
	float depth = p.y - H;
	float rip = (vnoise(vec2(p.x * 30.0, p.y * 260.0)) - 0.5) * 0.012 * (0.3 + depth * 3.0);
	vec3 col = lake_above(vec2(p.x + rip, H - depth - 0.001), seed, H) * vec3(0.62, 0.66, 0.80);
	float glint = exp(-pow((p.x - aspect * 0.62) / (0.02 + depth * 0.3), 2.0));
	glint *= step(0.62, vnoise(vec2(p.x * 90.0, p.y * 420.0)));
	col += vec3(1.0, 0.75, 0.45) * glint * 0.55;
	col = mix(col, vec3(0.04, 0.05, 0.10), smoothstep(0.0, 0.36, depth) * 0.55);
	float shore = 0.95 + 0.02 * sin(p.x * 14.0 + seed) + 0.012 * vnoise(vec2(p.x * 60.0, seed));
	vec3 grass = mix(vec3(0.05, 0.07, 0.05), vec3(0.12, 0.10, 0.06), vnoise(p * 180.0));
	return mix(col, grass, below(p.y, shore));
}

// ---------------------------------------------------- 1: playa tropical
vec3 scene_beach(vec2 p, float seed) {
	float H = 0.48;
	float y = p.y;
	vec3 col = mix(vec3(0.10, 0.38, 0.82), vec3(0.72, 0.89, 0.98), smoothstep(0.0, H, y));
	vec2 sun_c = vec2(aspect * 0.80, 0.11);
	col = sun(col, p, sun_c, 0.038, vec3(1.0, 0.95, 0.8), 0.35, 6.0, vec3(1.0, 1.0, 0.92));
	col = cumulus(col, p, seed, H - 0.03);

	// isla lejana
	float bump = 0.04 * exp(-pow((p.x - aspect * 0.34) / 0.08, 2.0)) + 0.018 * exp(-pow((p.x - aspect * 0.46) / 0.05, 2.0));
	col = mix(col, vec3(0.26, 0.44, 0.46), below(y, H - bump));

	if (y >= H) {
		float t = clamp((y - H) / 0.30, 0.0, 1.0);
		vec3 sea = mix(vec3(0.04, 0.28, 0.56), vec3(0.06, 0.70, 0.72), smoothstep(0.0, 1.0, t));
		float w = vnoise(vec2(p.x * 45.0, 5.0 / (y - H + 0.02)));
		sea += (w - 0.5) * 0.07;
		float glint = exp(-pow((p.x - sun_c.x) / 0.10, 2.0)) * step(0.82, vnoise(vec2(p.x * 140.0, y * 320.0)));
		sea += vec3(1.0) * glint * 0.45;
		col = sea;
	}

	float shore = 0.76 + 0.025 * sin(p.x * 8.0 + seed) + 0.01 * sin(p.x * 23.0 + seed);
	if (y > shore) {
		vec3 sand = mix(vec3(0.96, 0.86, 0.63), vec3(0.87, 0.73, 0.51), vnoise(p * 220.0) * 0.6);
		sand = mix(vec3(0.74, 0.64, 0.46), sand, smoothstep(0.0, 0.035, y - shore));
		col = sand;
	}
	float foam = smoothstep(0.010, 0.0, abs(y - shore)) * (0.55 + 0.45 * vnoise(vec2(p.x * 90.0, y * 90.0)));
	col = mix(col, vec3(0.97, 0.99, 1.0), foam);

	// palmera: tronco curvo (bezier en 10 tramos) + frondas caídas
	vec2 b0 = vec2(aspect * 0.12, 1.02);
	vec2 b1 = vec2(aspect * 0.08, 0.70);
	vec2 b2 = vec2(aspect * 0.30, 0.42);
	float trunk = 0.0;
	float ring = 0.0;
	vec2 prev = b0;
	for (int i = 1; i <= 10; i++) {
		float s = float(i) / 10.0;
		vec2 q = mix(mix(b0, b1, s), mix(b1, b2, s), s);
		vec2 d = seg(p, prev, q);
		float along = (float(i) - 1.0 + d.y) / 10.0;
		float wdt = mix(0.022, 0.011, along);
		float m = 1.0 - smoothstep(wdt - AA, wdt + AA, d.x);
		if (m > trunk) {
			trunk = m;
			ring = step(0.5, fract(along * 24.0));
		}
		prev = q;
	}
	col = mix(col, vec3(0.36, 0.25, 0.15) * (0.82 + 0.18 * ring), trunk);

	float frond = 0.0;
	float frond_shade = 0.0;
	for (int j = 0; j < 8; j++) {
		float ang = mix(-3.35, 0.25, float(j) / 7.0);
		vec2 dir = vec2(cos(ang), sin(ang));
		float len = 0.16 + 0.04 * hash1(float(j) + seed);
		vec2 a = b2;
		for (int k = 1; k <= 4; k++) {
			float s = float(k) / 4.0;
			vec2 q = b2 + dir * len * s + vec2(0.0, 0.10 * s * s);
			vec2 d = seg(p, a, q);
			float along = (float(k) - 1.0 + d.y) / 4.0;
			float wdt = 0.017 * (1.0 - along * 0.85) * (0.55 + 0.45 * abs(sin(along * 38.0)));
			float m = 1.0 - smoothstep(wdt - AA, wdt + AA, d.x);
			if (m > frond) {
				frond = m;
				frond_shade = float(j % 2);
			}
			a = q;
		}
	}
	col = mix(col, mix(vec3(0.07, 0.32, 0.11), vec3(0.18, 0.48, 0.14), frond_shade), frond);
	for (int c = 0; c < 3; c++) {
		vec2 cc = b2 + vec2(-0.012 + 0.012 * float(c), 0.014 + 0.004 * float(c % 2));
		col = mix(col, vec3(0.30, 0.20, 0.08), smoothstep(0.011 + AA, 0.011 - AA, distance(p, cc)));
	}
	return col;
}

// ------------------------------------------- 2: bosque de pinos con niebla
vec3 scene_forest(vec2 p, float seed) {
	float y = p.y;
	vec3 col = mix(vec3(0.50, 0.62, 0.78), vec3(1.0, 0.86, 0.62), smoothstep(0.05, 0.5, y));
	vec2 sun_c = vec2(aspect * 0.45, 0.30);
	vec2 dv = p - sun_c;
	col = sun(col, p, sun_c, 0.045, vec3(1.0, 0.85, 0.55), 0.55, 5.0, vec3(1.0, 0.97, 0.85));
	vec3 fog = vec3(0.86, 0.82, 0.72);
	for (int k = 0; k < 5; k++) {
		float fk = float(k);
		float ground = 0.42 + fk * 0.13 + 0.015 * sin(p.x * 7.0 + fk * 2.0 + seed);
		float m = pines(p, ground, 16.0 - fk * 2.2, 0.08 + fk * 0.03, 0.16 + fk * 0.05, seed + fk * 13.0, 0.92);
		vec3 tc = mix(fog * 0.82, vec3(0.03, 0.09, 0.06), (fk + 1.0) / 5.0);
		col = mix(col, tc, max(m, below(y, ground)));
		col = mix(col, fog, smoothstep(ground - 0.09, ground, y) * 0.35 * (1.0 - fk / 5.0));
	}
	// rayos de sol entre la niebla
	float rays = pow(vnoise(vec2(atan(dv.y, dv.x) * 9.0, seed)), 3.0) * smoothstep(0.0, 0.25, dv.y) * exp(-length(dv) * 1.5);
	col += vec3(1.0, 0.9, 0.7) * rays * 0.45;
	return col;
}

// ------------------------------------ 3: aurora boreal sobre montañas nevadas
vec3 scene_aurora(vec2 p, float seed) {
	float y = p.y;
	vec3 col = mix(vec3(0.01, 0.02, 0.07), vec3(0.05, 0.12, 0.25), smoothstep(0.0, 0.6, y));
	col += vec3(0.9, 0.95, 1.0) * stars(p + seed);
	for (int k = 0; k < 2; k++) {
		float fk = float(k);
		float center = 0.22 + fk * 0.12 + 0.07 * sin(p.x * 5.0 + seed + fk * 2.0) + 0.08 * (fbm(vec2(p.x * 2.0 + fk * 5.0, seed)) - 0.5);
		float dy = y - center;
		float curtain = exp(-max(dy, 0.0) * 30.0) * smoothstep(-0.20, 0.0, dy);
		float streak = 0.5 + 0.5 * vnoise(vec2(p.x * 70.0, fk * 9.0));
		vec3 ac = mix(vec3(0.15, 1.0, 0.55), vec3(0.65, 0.25, 0.90), smoothstep(0.0, -0.16, dy));
		col += ac * curtain * streak * (0.6 - fk * 0.22);
	}
	col = sun(col, p, vec2(aspect * 0.18, 0.11), 0.028, vec3(0.7, 0.8, 1.0), 0.25, 9.0, vec3(0.93, 0.95, 1.0));

	float t1 = ridge_top(p.x, 0.66, 0.32, 2.2, seed);
	float lit = ridge_light(p, 0.66, 0.32, 2.2, seed);
	vec3 mcol = mix(vec3(0.14, 0.18, 0.32), vec3(0.62, 0.74, 0.90), lit);
	mcol += vec3(0.0, 0.08, 0.04) * lit;
	mcol = mix(mcol, vec3(0.08, 0.10, 0.18), smoothstep(t1, t1 + 0.3, y) * 0.6);
	col = mix(col, mcol, below(y, t1));

	float t2 = ridge_top(p.x, 0.76, 0.12, 4.0, seed + 9.0);
	float lit2 = ridge_light(p, 0.76, 0.12, 4.0, seed + 9.0);
	col = mix(col, mix(vec3(0.10, 0.13, 0.24), vec3(0.42, 0.52, 0.70), lit2), below(y, t2));

	float g = 0.86 + 0.02 * sin(p.x * 6.0 + seed);
	col = mix(col, vec3(0.55, 0.62, 0.78) * (0.9 + 0.1 * vnoise(p * 80.0)), below(y, g));
	float m = pines(p, 0.89, 9.0, 0.14, 0.26, seed + 3.0, 0.6);
	col = mix(col, vec3(0.02, 0.05, 0.07), m);
	return col;
}

// ------------------------------------------------------ 4: cañón desértico
float mesa(vec2 p, float cx, float half_w, float top, float slope) {
	float w = half_w + max(p.y - top, 0.0) * slope;
	float edge = top + 0.004 * vnoise(vec2(p.x * 200.0, cx * 10.0));
	return below(p.y, edge) * (1.0 - smoothstep(w - AA, w + AA, abs(p.x - cx)));
}

vec3 scene_desert(vec2 p, float seed) {
	float y = p.y;
	vec3 col = mix(vec3(0.22, 0.34, 0.66), vec3(1.0, 0.72, 0.42), smoothstep(0.05, 0.62, y));
	col = sun(col, p, vec2(aspect * 0.20, 0.50), 0.05, vec3(1.0, 0.6, 0.3), 0.6, 5.0, vec3(1.0, 0.9, 0.65));
	float streaks = smoothstep(0.55, 0.75, fbm(vec2(p.x * 2.0 + seed, y * 25.0))) * smoothstep(0.45, 0.1, y);
	col = mix(col, vec3(1.0, 0.72, 0.68), streaks * 0.6);

	// mesas lejanas con bruma
	float far = max(mesa(p, aspect * 0.12, 0.09, 0.52, 0.6), mesa(p, aspect * 0.58, 0.13, 0.55, 0.5));
	far = max(far, below(y, 0.62));
	col = mix(col, mix(vec3(0.62, 0.44, 0.52), col, 0.3), far);

	// mesa grande y aguja de roca cercanas
	float cx1 = aspect * 0.80;
	float cx2 = aspect * 0.36;
	float near_a = mesa(p, cx1, 0.13, 0.40, 0.35);
	float near_b = mesa(p, cx2, 0.035, 0.46, 0.25);
	vec3 rock = vec3(0.80, 0.38, 0.20) * (0.88 + 0.12 * sin(y * 260.0 + vnoise(p * 30.0) * 3.0));
	float lit_a = smoothstep(cx1 + 0.02, cx1 - 0.10, p.x);
	float lit_b = smoothstep(cx2 + 0.01, cx2 - 0.03, p.x);
	col = mix(col, rock * mix(0.55, 1.0, lit_a), near_a);
	col = mix(col, rock * mix(0.55, 1.0, lit_b), near_b);
	col = mix(col, vec3(0.86, 0.56, 0.33), below(y, 0.66));

	// dunas con rizos de viento
	for (int k = 0; k < 2; k++) {
		float fk = float(k);
		float base = 0.74 + fk * 0.12;
		float f1 = 7.0 - fk * 2.0;
		float d = base + 0.04 * sin(p.x * f1 + seed + fk) + 0.015 * sin(p.x * 19.0 + seed * 2.0 + fk);
		float ds = 0.04 * f1 * cos(p.x * f1 + seed + fk) + 0.285 * cos(p.x * 19.0 + seed * 2.0 + fk);
		// Luz suave según la pendiente de la cresta, que se desvanece hacia
		// el valle de la duna (si no, cada columna sale del mismo tono de
		// arriba a abajo y se ven franjas verticales).
		float lit = clamp(0.55 - ds * 1.6, 0.0, 1.0);
		lit = mix(lit, 0.45, smoothstep(0.0, 0.10, y - d));
		vec3 dune = mix(vec3(0.72, 0.38, 0.22), vec3(0.99, 0.72, 0.44), lit);
		dune *= 0.96 + 0.04 * sin((y - d) * 420.0 + p.x * 30.0 + vnoise(p * 40.0) * 4.0);
		col = mix(col, dune, below(y, d));
	}

	// saguaro
	float sx = aspect * 0.24;
	float cactus = 0.0;
	cactus = max(cactus, 1.0 - smoothstep(0.018, 0.018 + AA, seg(p, vec2(sx, 0.95), vec2(sx, 0.66)).x));
	cactus = max(cactus, 1.0 - smoothstep(0.012, 0.012 + AA, seg(p, vec2(sx, 0.83), vec2(sx - 0.05, 0.83)).x));
	cactus = max(cactus, 1.0 - smoothstep(0.012, 0.012 + AA, seg(p, vec2(sx - 0.05, 0.83), vec2(sx - 0.05, 0.74)).x));
	cactus = max(cactus, 1.0 - smoothstep(0.012, 0.012 + AA, seg(p, vec2(sx, 0.78), vec2(sx + 0.045, 0.78)).x));
	cactus = max(cactus, 1.0 - smoothstep(0.012, 0.012 + AA, seg(p, vec2(sx + 0.045, 0.78), vec2(sx + 0.045, 0.70)).x));
	vec3 cactus_col = vec3(0.14, 0.32, 0.15) * (0.85 + 0.15 * step(0.5, fract(p.x * 260.0)));
	col = mix(col, cactus_col, cactus);
	return col;
}

// ------------------------------------------ 5: valle verde, río y arcoíris
float hill_y(float x, float fk, float seed) {
	return 0.60 + fk * 0.09 + 0.035 * sin(x * (4.0 + fk * 2.0) + seed + fk * 1.7) + 0.02 * sin(x * 11.0 + fk);
}

vec3 scene_valley(vec2 p, float seed) {
	float y = p.y;
	vec3 col = mix(vec3(0.26, 0.54, 0.92), vec3(0.82, 0.92, 1.0), smoothstep(0.0, 0.5, y));
	col = cumulus(col, p, seed, 0.45);

	float r = distance(p, vec2(aspect * 0.55, 0.80));
	float band = (r - 0.46) / 0.07;
	if (band > 0.0 && band < 1.0) {
		float a = 0.35 * smoothstep(0.0, 0.15, band) * smoothstep(1.0, 0.85, band);
		col = mix(col, hue(0.78 * (1.0 - band)), a);
	}

	float t = ridge_top(p.x, 0.56, 0.18, 2.4, seed);
	float lit = ridge_light(p, 0.56, 0.18, 2.4, seed);
	vec3 mcol = mix(vec3(0.38, 0.50, 0.72), vec3(0.62, 0.72, 0.88), lit);
	float snow = 1.0 - smoothstep(0.02, 0.035, y - t - 0.02 * vnoise(vec2(p.x * 40.0, y * 30.0)));
	mcol = mix(mcol, vec3(0.95, 0.97, 1.0), snow * 0.9);
	col = mix(col, mix(mcol, col, 0.25), below(y, t));

	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		float hy = hill_y(p.x, fk, seed);
		vec3 hc = mix(vec3(0.52, 0.74, 0.38), vec3(0.20, 0.46, 0.15), fk / 2.0);
		hc *= 0.9 + 0.15 * vnoise(p * vec2(30.0, 60.0) + fk * 10.0);
		col = mix(col, hc, below(y, hy));
		// arbolitos redondos sobre la cresta
		float density = 30.0 - fk * 8.0;
		float id = floor(p.x * density);
		for (int j = -1; j <= 1; j++) {
			float cid = id + float(j);
			if (hash1(cid * 3.3 + fk * 17.0 + seed) > 0.45) {
				continue;
			}
			float cx = (cid + 0.5) / density;
			float rr = (0.010 + 0.006 * fk) * (0.8 + 0.4 * hash1(cid + fk));
			vec2 cc = vec2(cx, hill_y(cx, fk, seed) - rr * 0.6);
			float d = distance(p, cc);
			vec3 tree = mix(vec3(0.10, 0.34, 0.12), vec3(0.22, 0.50, 0.18), smoothstep(rr, 0.0, distance(p, cc - vec2(rr * 0.3))));
			col = mix(col, tree, smoothstep(rr + AA, rr - AA, d));
		}
	}

	// río serpenteando hacia el frente
	if (y > 0.60) {
		float tt = (y - 0.60) / 0.40;
		float cxr = aspect * 0.52 + 0.14 * sin(tt * 5.0 + seed) * tt;
		float w = 0.003 + tt * 0.09;
		float d = abs(p.x - cxr);
		vec3 water = mix(vec3(0.34, 0.60, 0.88), vec3(0.72, 0.86, 0.98), smoothstep(0.55, 0.85, vnoise(vec2(p.x * 80.0, y * 200.0))));
		col = mix(col, vec3(0.30, 0.34, 0.20), 1.0 - smoothstep(w + 0.004, w + 0.004 + AA, d));
		col = mix(col, water, 1.0 - smoothstep(w - AA, w + AA, d));
	}

	// flores en primer plano
	if (y > 0.82) {
		vec2 g = p * 85.0;
		vec2 id = floor(g);
		float h = hash2(id);
		if (h > 0.72) {
			vec2 off = vec2(hash2(id + 1.3), hash2(id + 4.1)) * 0.5 + 0.25;
			float d = length(fract(g) - off);
			float pick = hash2(id + 9.9);
			vec3 fc = pick < 0.25 ? vec3(0.95, 0.25, 0.25) : (pick < 0.5 ? vec3(1.0, 0.85, 0.2) : (pick < 0.75 ? vec3(1.0, 0.97, 0.95) : vec3(0.65, 0.35, 0.9)));
			col = mix(col, fc, smoothstep(0.22, 0.14, d) * smoothstep(0.82, 0.86, y));
		}
	}
	return col;
}

void fragment() {
	float lv = max(level, 1.0);
	int scene = int(mod(lv - 1.0, 6.0));
	float seed = 3.0 + lv * 7.31;
	vec2 p = vec2(UV.x * aspect, UV.y);
	vec3 col;
	if (scene == 0) {
		col = scene_lake(p, seed);
	} else if (scene == 1) {
		col = scene_beach(p, seed);
	} else if (scene == 2) {
		col = scene_forest(p, seed);
	} else if (scene == 3) {
		col = scene_aurora(p, seed);
	} else if (scene == 4) {
		col = scene_desert(p, seed);
	} else {
		col = scene_valley(p, seed);
	}
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
