// Wspólny shader modeli Grzybowego Lasu (art/models/forest/*.glb).
// Kolor z koloru wierzchołków (wariacje, mech, plamy kory), świecenie z UV (U = nasada -> brzeg,
// V = wzdłuż brzegu: blaszki), a do tego ruch, każdy egzemplarz w swoim rytmie (faza z pozycji w świecie):
//   sway  - kołysanie (paprocie, krzewy, kępy): im dalej od nasady, tym mocniej,
//   wave  - falowanie brzegów kapeluszy (U^2),
//   pulse - świecenie co jakiś czas narasta i gaśnie (nierówny rytm z dwóch sinusów).
shader_type spatial;
// Bez odbić: twarde błyski toon na jasnych kapeluszach i korze przepalały się w białe plamy.
render_mode cull_disabled, diffuse_toon, specular_disabled;

uniform vec3 albedo : source_color = vec3(1.0);
uniform float roughness = 0.75;
uniform bool glows = false;
uniform vec3 glow_color : source_color = vec3(0.4, 1.0, 0.3);
uniform float strength_in = 1.0;   // świecenie przy nasadzie (U = 0)
uniform float strength_out = 1.0;  // świecenie na brzegu (U = 1)
uniform float stripes = 0.0;       // liczba blaszek wzdłuż brzegu
uniform float stripe_amount = 0.0;
uniform float pulse = 0.35;        // ile świecenie przygasa/narasta
uniform float pulse_speed = 0.6;
// Ruch.
uniform vec3 grow_axis = vec3(0.0, 1.0, 0.0);  // kierunek wzrostu (naziemne: Y, ścienne: Z)
uniform float size_ref = 1.0;                  // typowa wysokość modelu (m)
uniform float sway = 0.0;                      // wychylenie czubka (m)
uniform float sway_speed = 0.8;
uniform float wave = 0.0;                      // falowanie brzegów kapeluszy (m)
uniform float rim_strength = 0.35;

varying float phase;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	phase = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831;
	float t = TIME;
	if (sway > 0.0) {
		float h = clamp(dot(VERTEX, grow_axis) / size_ref, 0.0, 1.5);
		float k = h * h;
		// Podmuch: wolna fala + drobne drżenie zależne od miejsca na liściu.
		float gust = sin(t * sway_speed + phase) * 0.7 + sin(t * sway_speed * 2.3 + phase * 1.7) * 0.3;
		float flutter = sin(t * 3.1 + dot(VERTEX, vec3(4.0, 3.0, 5.0)) + phase) * 0.15;
		vec3 side = normalize(cross(grow_axis, vec3(0.3, 0.2, 0.93)));
		vec3 side2 = cross(grow_axis, side);
		VERTEX += (side * (gust + flutter) + side2 * sin(t * sway_speed * 0.7 + phase * 2.1) * 0.5) * sway * k;
	}
	if (wave > 0.0) {
		float u = UV.x;
		VERTEX += NORMAL * sin(t * 1.3 + UV.y * 9.0 + phase) * wave * u * u;
	}
}

void fragment() {
	// Kolory wierzchołków są już liniowe (eksport z Blendera je przelicza). Bez pow(): przy zerowych
	// składowych dawało NaN, które poświata rozlewała w białe plamy.
	ALBEDO = albedo * max(COLOR.rgb, vec3(0.0));
	ROUGHNESS = roughness;
	RIM = rim_strength;
	RIM_TINT = 0.4;
	if (glows) {
		float u = UV.x;
		float s = 1.0;
		if (stripes > 0.0) {
			float ph = UV.y * stripes * 6.2831;
			s = 1.0 - stripe_amount * (0.5 + 0.5 * sin(ph));
			// Z daleka blaszki zlewają się w równą poświatę (bez migotania).
			s = mix(s, 1.0 - stripe_amount * 0.5, clamp(fwidth(ph) * 0.35, 0.0, 1.0));
		}
		float breath = 0.5 + 0.5 * sin(TIME * pulse_speed + phase) * sin(TIME * pulse_speed * 0.37 + phase * 3.0);
		float p = 1.0 - pulse + pulse * 2.0 * breath;
		EMISSION = glow_color * mix(strength_in, strength_out, u) * s * p * COLOR.a;
	}
}
