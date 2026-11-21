// Grzybnia: cieniutkie, kręte nitki (izolinie zawirowanego szumu) o stałej grubości w pikselach,
// więc z bliska i z daleka zostają włosowate. `cord` (0..1) pogrubia je w sznury (przy arenie bossa).
// Szum liczony w shaderze (float): 8-bitowa tekstura dawała schodki, które zamieniały nitki w szerokie pasy.

vec2 myc_hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// Szum gradientowy 2D, wynik w przybliżeniu -1..1.
float myc_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(myc_hash2(i), f);
	float b = dot(myc_hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(myc_hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(myc_hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 1.6;
}

float myc_layer(vec2 p, float meters, float rot, float width_m) {
	float c = cos(rot);
	float s = sin(rot);
	vec2 q = (mat2(vec2(c, -s), vec2(s, c)) * p) / meters;
	vec2 warp = vec2(myc_noise(q * 0.35 + 3.7), myc_noise(q * 0.35 + 9.1)) * 0.9;
	float v = myc_noise(q + warp);
	float fw = max(fwidth(v), 1e-4);
	float m_per_px = max(fwidth(p.x), fwidth(p.y)) + 1e-5;
	float w = width_m / m_per_px;
	float w_px = max(0.35, w);
	float faint = clamp(w / 0.35, 0.35, 1.0);  // nitka cieńsza niż piksel: jaśnieje słabiej, zamiast grubieć
	// Jedna izolinia (v = 0): krzywe, które się rozgałęziają i łączą jak strzępki.
	return (1.0 - smoothstep(w_px * 0.5, w_px * 0.5 + 0.8, abs(v) / fw)) * faint;
}

float mycelium_threads(vec2 p, float cord) {
	// Cieńsze (uwaga autora): poniżej piksela nitka słabnie zamiast się pogrubiać.
	float t = myc_layer(p, 2.6, 0.0, 0.0015 + cord * 0.09);
	t = max(t, myc_layer(p, 1.3, 1.3, 0.001 + cord * 0.035) * 0.65);
	t = max(t, myc_layer(p + 7.0, 0.7, 2.4, 0.0008) * 0.3 * (1.0 - cord));
	return t;
}
