// Dno Grzybowego Lasu (wersja testowa): ciemna, wilgotna ziemia z plamami fioletowego
// i zielonkawego mchu; strome zbocza (ściany kanionu, uskoki, doły) to skała w warstwach.
// Bez plików tekstur: tylko bezszwowy szum (ten sam co ziemia łąki).
// Na ziemi cieniutka grzybnia (mycelium.gdshaderinc): w plamach, gęsto przy sercach, w sznury przy arenie;
// z serc co jakiś czas rozchodzi się fala światła. Wnętrza jaskiń są przyciemnione.
shader_type spatial;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 c_mud : source_color = vec3(0.07, 0.075, 0.09);
uniform vec3 c_moss_violet : source_color = vec3(0.17, 0.11, 0.24);
uniform vec3 c_moss_green : source_color = vec3(0.08, 0.15, 0.13);
uniform vec3 c_rock : source_color = vec3(0.2, 0.17, 0.25);
uniform vec3 c_rock_band : source_color = vec3(0.3, 0.25, 0.34);
uniform vec3 c_lichen : source_color = vec3(0.3, 0.9, 0.6);
uniform vec3 c_mycelium : source_color = vec3(0.35, 0.9, 1.0);
// Serca grzybni: (x, z, zasięg, faza), arena bossa (x, z, promień, wysokość), jaskinie (x, z, promień, podłoga).
uniform vec4 hearts[16];
uniform int heart_count = 0;
uniform vec4 arena = vec4(0.0);
uniform vec4 caves[4];
uniform int cave_count = 0;

varying vec3 wp;
varying vec3 wn;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float n(vec2 p, float meters) {
	return texture(noise_tex, p / meters).r;
}

#include "res://art/materials/mycelium.gdshaderinc"

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = wp.xz;
	vec2 warp = (vec2(n(p, 29.0), n(p + 17.0, 33.0)) - 0.5) * 6.0;
	float v = n(p + warp, 40.0);
	vec3 ground = mix(c_mud, c_moss_violet, smoothstep(0.45, 0.7, v));
	ground = mix(ground, c_moss_green, smoothstep(0.55, 0.75, n(p + warp, 13.0)) * 0.7);
	ground *= 0.85 + 0.2 * n(p, 5.0);

	// Skała: pionowe pasy warstw (od wysokości), lekko pofalowane szumem.
	float bands = n(vec2(wp.y * 0.9 + n(p, 11.0) * 3.0, 0.5), 3.0);
	vec3 rock = mix(c_rock, c_rock_band, smoothstep(0.4, 0.6, bands));
	rock *= 0.85 + 0.25 * n(vec2(p.x + wp.y, p.y - wp.y), 4.0);

	float slope = 1.0 - clamp(wn.y, 0.0, 1.0);
	float rocky = smoothstep(0.32, 0.5, slope + (n(p, 7.0) - 0.5) * 0.15);
	vec3 col = mix(ground, rock, rocky);

	// Plamki świecącego porostu tylko na skale.
	vec2 lc = vec2(p.x + p.y, wp.y) * 2.5;
	vec2 cell = floor(lc);
	vec2 centre = vec2(hash(cell + 3.1), hash(cell + 7.7)) * 0.8 + 0.1;
	float lichen = step(0.93, hash(cell)) * smoothstep(0.09, 0.04, length(fract(lc) - centre)) * rocky;
	// Wnętrza jaskiń: ciemno.
	float dark = 0.0;
	for (int i = 0; i < cave_count; i++) {
		float cd = length(p - caves[i].xy);
		dark = max(dark, 1.0 - smoothstep(caves[i].z * 0.6, caves[i].z + 0.5, cd));
	}
	col *= mix(1.0, 0.18, dark);

	// Grzybnia: maska (plamy, serca, sznury przy arenie, jaskinie) i puls fal z serc.
	float pulse = 0.0;
	float near_heart = 0.0;
	for (int i = 0; i < heart_count; i++) {
		vec4 h = hearts[i];
		float d = length(p - h.xy);
		if (d < h.z) {
			float k = 1.0 - d / h.z;
			near_heart = max(near_heart, k);
			float front = mod(TIME * 3.5 + h.w * 1.7, h.z + 8.0);
			pulse += exp(-pow(d - front, 2.0) * 0.6) * k;
		}
	}
	float cord = 0.0;
	if (arena.z > 0.0) {
		cord = pow(1.0 - smoothstep(arena.z, arena.z + 70.0, length(p - arena.xy)), 2.0);
	}
	float dist = length(CAMERA_POSITION_WORLD - wp);
	float patches = smoothstep(0.5, 0.66, n(p + warp * 2.0, 55.0)) * 0.8;
	float mask = max(max(patches, near_heart * 1.4), max(cord, dark)) * (1.0 - rocky * 0.85);
	float fade = mix(1.0 - smoothstep(20.0, 55.0, dist), 1.0 - smoothstep(40.0, 110.0, dist), cord);
	float threads = clamp(mycelium_threads(p, cord) * mask * fade, 0.0, 1.0);
	col = mix(col, vec3(0.5, 0.55, 0.58), threads * 0.35);

	ALBEDO = col;
	EMISSION = c_lichen * lichen * 0.5 + c_mycelium * threads * (0.03 + 0.1 * cord + 1.6 * min(pulse, 1.0));
	ROUGHNESS = mix(0.95, 0.8, rocky);
}
