// Zaorane pole: bruzdy co pół metra wzdłuż osi X i grudki ziemi.
shader_type spatial;

uniform vec3 soil : source_color = vec3(0.42, 0.28, 0.22);
uniform vec3 furrow : source_color = vec3(0.28, 0.18, 0.15);

varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rows = 0.5 + 0.5 * cos(wp.z * 6.2832 * 2.0 + noise(wp.xz * 3.0) * 0.8);
	vec3 col = mix(furrow, soil, smoothstep(0.2, 0.8, rows));
	col *= 0.85 + 0.25 * noise(wp.xz * 9.0);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
