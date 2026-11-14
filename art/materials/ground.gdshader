// Ziemia liczona w shaderze (bez plików tekstur, tylko bezszwowy szum).
// style 0 = malowana łąka (baza), style 1 = obca ziemia z fioletowymi łachami (łąka wyprawy).
shader_type spatial;

uniform int style = 0;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 c_light : source_color = vec3(0.5, 0.78, 0.44);
uniform vec3 c_dark : source_color = vec3(0.28, 0.55, 0.34);
uniform vec3 c_third : source_color = vec3(0.36, 0.66, 0.56);
uniform vec3 c_soil : source_color = vec3(0.5, 0.34, 0.5);
uniform vec3 c_fleck : source_color = vec3(1.0, 0.9, 0.55);

varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// Gładki szum z tekstury; `meters` = rozmiar jednego kafla szumu w metrach.
float n(vec2 p, float meters, float rot) {
	float c = cos(rot);
	float s = sin(rot);
	vec2 q = mat2(vec2(c, -s), vec2(s, c)) * p;
	return texture(noise_tex, q / meters).r;
}

// Drobne kropki (kwiatki, kryształki): jedna kropka w części komórek siatki.
float flecks(vec2 p, float density, float size) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 c = vec2(hash(cell + 3.1), hash(cell + 7.7)) * 0.8 + 0.1;
	return step(1.0 - density, hash(cell)) * smoothstep(size, size * 0.5, length(f - c));
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	vec2 warp = (vec2(n(p, 31.0, 0.3), n(p, 37.0, 1.1)) - 0.5) * 5.0;
	vec3 col;
	if (style == 0) {
		float big = n(p + warp, 60.0, 0.0);
		float mid = n(p + warp, 17.0, 0.7);
		col = mix(c_dark, c_light, smoothstep(0.35, 0.65, big));
		col = mix(col, c_third, smoothstep(0.5, 0.7, mid) * 0.55);
		col *= 0.9 + 0.16 * n(vec2(p.x * 3.0, p.y * 0.6), 9.0, 0.4);
		col = mix(col, c_fleck, flecks(p * 1.3, 0.05, 0.12) * 0.8);
	} else {
		float v = n(p + warp, 45.0, 0.0);
		float soil = smoothstep(0.68, 0.72, n(p + warp, 22.0, 2.0));
		col = mix(c_dark, c_third, smoothstep(0.3, 0.7, v));
		col = mix(col, c_light, smoothstep(0.55, 0.75, n(p, 7.0, 0.9)) * 0.45);
		col = mix(col, c_soil, soil);
		float crystals = flecks(p * 2.0, 0.035, 0.09) * soil;
		col = mix(col, vec3(0.6, 0.9, 1.0), crystals);
		EMISSION = vec3(0.4, 0.8, 1.0) * crystals * 0.6;
		col = mix(col, c_fleck, flecks(p * 1.1, 0.03, 0.1) * (1.0 - soil) * 0.7);
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
