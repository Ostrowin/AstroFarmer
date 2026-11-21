// Ściany jaskiń Grzybowego Lasu. Zewnątrz: skała w warstwach (jak zbocza).
// Wewnątrz: ciemna, wilgotna skała, na której co jakiś czas pulsuje cieniutka grzybnia
// (fale światła biegną po nitkach). `spore` = Grota Zarodników (fioletowy odcień, więcej grzybni).
// Wzór rzutowany z trzech stron (bez szwów i bez zbiegania się linii na sklepieniu).
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform bool inner = false;
uniform bool spore = false;
uniform vec3 center = vec3(0.0);
uniform vec3 c_rock : source_color = vec3(0.2, 0.17, 0.25);
uniform vec3 c_rock_band : source_color = vec3(0.3, 0.25, 0.34);

varying vec3 wp;
varying vec3 wn;

float n(vec2 p, float meters) {
	return texture(noise_tex, p / meters).r;
}

#include "res://art/materials/mycelium.gdshaderinc"

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float tri_threads(vec3 p, vec3 w) {
	return mycelium_threads(p.zy, 0.0) * w.x + mycelium_threads(p.xy, 0.0) * w.z + mycelium_threads(p.xz, 0.0) * w.y;
}

void fragment() {
	vec3 w = pow(abs(wn), vec3(4.0));
	w /= (w.x + w.y + w.z + 1e-4);
	float bands = n(vec2(wp.y * 0.9 + n(wp.xz, 11.0) * 3.0, 0.5), 3.0);
	vec3 rock = mix(c_rock, c_rock_band, smoothstep(0.4, 0.6, bands));
	rock *= 0.8 + 0.3 * n(wp.xz + wp.y, 4.0);
	if (!inner) {
		ALBEDO = rock;
		ROUGHNESS = 0.9;
	} else {
		vec3 col = rock * (spore ? vec3(0.3, 0.22, 0.4) : vec3(0.22));
		// Grzybnia tylko w plamach ("od czasu do czasu"), w grocie gęściej.
		float patches = smoothstep(spore ? 0.4 : 0.55, spore ? 0.6 : 0.7, n(wp.xz * 0.6 + wp.y * 0.4 + 31.0, 9.0));
		float threads = tri_threads(wp, w) * patches;
		threads *= 1.0 - smoothstep(16.0, 35.0, length(CAMERA_POSITION_WORLD - wp));
		// Fale: każda plama w swoim rytmie, światło biegnie po nitkach od dołu w górę.
		float seed = n(wp.xz * 0.05 + 5.0, 3.0) * 30.0;
		float front = mod(TIME * 2.2 + seed, 12.0);
		float wave = exp(-pow(wp.y - center.y + n(wp.xz, 6.0) * 2.0 - front + 1.0, 2.0) * 0.9);
		vec3 glow = spore ? vec3(0.7, 0.4, 1.0) : vec3(0.35, 0.9, 1.0);
		ALBEDO = mix(col, vec3(0.42, 0.42, 0.48), threads * 0.35);
		EMISSION = glow * threads * (0.04 + 1.4 * wave);
		ROUGHNESS = 0.75;
	}
}
