class_name DayNight
extends Node
## Pora doby: pcha zegar GameState i co klatkę ustawia niebo, słońce/księżyc,
## mgłę i światło otoczenia. Dzień każdej sceny zostaje taki, jak w scenie;
## świt, zmierzch i noc są wspólne. Pogoda wyprawy (burza) i mgła poziomu 2
## nakładają się na porę doby.

const SKY_SHADER := """
shader_type sky;
uniform vec3 top_color = vec3(0.3, 0.5, 0.9);
uniform vec3 horizon_color = vec3(0.9, 0.7, 0.8);
uniform vec3 ground_color = vec3(0.2, 0.16, 0.3);
uniform float stars = 0.0;
uniform float sun_disc = 1.0;
uniform vec3 sun_color = vec3(1.0, 0.95, 0.85);
uniform vec3 moon_dir = vec3(0.35, 0.5, -0.8);
uniform vec3 moon2_dir = vec3(-0.6, 0.3, -0.7);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 col;
	if (EYEDIR.y >= 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(EYEDIR.y, 0.0, 1.0), 0.5));
		vec3 cell = floor(EYEDIR * 220.0);
		float star = step(0.9965, hash(cell)) * smoothstep(0.0, 0.25, EYEDIR.y);
		col += vec3(star) * (0.5 + 0.5 * hash(cell + 3.0)) * stars;
		float d = dot(EYEDIR, normalize(moon_dir));
		col += vec3(0.85, 0.9, 1.0) * smoothstep(0.9988, 0.9992, d) * 1.4 * stars;
		col += vec3(0.2, 0.25, 0.45) * pow(max(d, 0.0), 60.0) * 0.4 * stars;
		col += vec3(0.75, 0.5, 1.0) * smoothstep(0.99965, 0.9998, dot(EYEDIR, normalize(moon2_dir))) * stars;
		if (LIGHT0_ENABLED) {
			float s = dot(EYEDIR, LIGHT0_DIRECTION);
			col += sun_color * smoothstep(0.9993, 0.9996, s) * 2.0 * sun_disc;
			col += sun_color * pow(max(s, 0.0), 40.0) * 0.25 * sun_disc;
		}
	} else {
		col = mix(horizon_color, ground_color, clamp(-EYEDIR.y * 4.0, 0.0, 1.0));
	}
	COLOR = col;
}
"""

## Kierunek księżyca (światło nocą pada z tej strony).
const MOON_DIR := Vector3(0.35, 0.5, -0.8)

# Paleta: świt, zmierzch, noc. Dzień czytany ze sceny w setup().
const DAWN := {
	"top": Color(0.3, 0.35, 0.65), "horizon": Color(1.0, 0.68, 0.58), "ground": Color(0.2, 0.15, 0.25),
	"fog": Color(0.9, 0.7, 0.75), "fog_density": 0.005, "ambient": 0.7,
	"light": Color(1.0, 0.75, 0.6), "energy": 0.7, "glow": 0.8,
}
const DUSK := {
	"top": Color(0.22, 0.2, 0.48), "horizon": Color(1.0, 0.5, 0.35), "ground": Color(0.2, 0.12, 0.2),
	"fog": Color(0.95, 0.55, 0.45), "fog_density": 0.005, "ambient": 0.65,
	"light": Color(1.0, 0.6, 0.35), "energy": 0.7, "glow": 0.8,
}
## Noc prawie czarna: widać tylko sylwetki gór na tle gwiazd, latarkę i to, co samo świeci
## (później bioluminescencja). Światło otoczenia nocą nie pochodzi z nieba, tylko z NIGHT_AMBIENT.
const NIGHT := {
	"top": Color(0.0012, 0.0014, 0.005), "horizon": Color(0.004, 0.0038, 0.01), "ground": Color(0.002, 0.002, 0.004),
	"fog": Color(0.002, 0.002, 0.005), "fog_density": 0.02, "ambient": 1.0,
	"light": Color(0.5, 0.6, 1.0), "energy": 0.02, "glow": 1.3,
}
const NIGHT_AMBIENT := Color(0.004, 0.005, 0.01)

## Czy ten węzeł pcha zegar (w testach można wyłączyć).
var drive_clock := true
## Mgła poziomu 2 (0..1).
var mist := 0.0

var _env: Environment
var _sun: DirectionalLight3D
var _sky_mat: ShaderMaterial
var _day: Dictionary = {}
var _weather_from: Dictionary = {}
var _weather_to: Dictionary = {}
var _weather_t := 1.0


func setup(env: Environment, sun: DirectionalLight3D) -> void:
	_env = env
	_sun = sun
	var day_sky: ProceduralSkyMaterial = null
	if env.sky:
		day_sky = env.sky.sky_material as ProceduralSkyMaterial
	_day = {
		"top": day_sky.sky_top_color if day_sky else Color(0.32, 0.5, 0.86),
		"horizon": day_sky.sky_horizon_color if day_sky else Color(0.86, 0.66, 0.82),
		"ground": day_sky.ground_bottom_color if day_sky else Color(0.2, 0.16, 0.3),
		"fog": env.fog_light_color, "fog_density": env.fog_density, "ambient": env.ambient_light_energy,
		"light": sun.light_color, "energy": sun.light_energy, "glow": env.glow_intensity,
	}
	_sky_mat = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SKY_SHADER
	_sky_mat.shader = shader
	_sky_mat.set_shader_parameter("moon_dir", MOON_DIR)
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	env.sky = sky
	env.fog_sky_affect = 0.15
	_weather_from = _no_weather()
	_weather_to = _no_weather()
	apply(GameState.time_of_day)


## Pogoda wyprawy: płynne przejście w 4 s do nowej mgły i światła.
func set_weather(fog_density: float, light_scale: float, light_color: Color, fog_color: Color) -> void:
	_weather_from = _current_weather()
	_weather_to = {"mix": 1.0, "fog_density": fog_density, "scale": light_scale, "light": light_color, "fog": fog_color}
	_weather_t = 0.0


func _process(delta: float) -> void:
	if drive_clock:
		GameState.advance_time(delta)
	if _weather_t < 1.0:
		_weather_t = minf(_weather_t + delta / 4.0, 1.0)
	if _env:
		apply(GameState.time_of_day)


func _unhandled_input(event: InputEvent) -> void:
	# Debug: F8 przesuwa zegar o 2 godziny.
	if event.is_action_pressed("debug_skip_time"):
		GameState.advance_time(GameState.DAY_SECONDS / 12.0)


## Paleta dla pory doby t (0..1).
static func palette(t: float, day: Dictionary) -> Dictionary:
	t = fposmod(t, 1.0)
	# Klatki kluczowe: noc -> świt -> dzień -> zmierzch -> noc.
	var keys := [[0.0, NIGHT], [0.21, NIGHT], [0.25, DAWN], [0.3, day], [0.7, day], [0.75, DUSK], [0.79, NIGHT], [1.0, NIGHT]]
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if t <= b[0]:
			var k := smoothstep(0.0, 1.0, (t - a[0]) / maxf(b[0] - a[0], 0.0001))
			return _mix(a[1], b[1], k)
	return NIGHT.duplicate()


func apply(t: float) -> void:
	var p := palette(t, _day)
	var night := GameState.night_amount(t)
	var w := _current_weather()
	var wm: float = w["mix"]
	# Pogoda przyciemniona nocą, żeby burza w nocy nie świeciła.
	var bright := 1.0 - night * 0.9
	var fog_color: Color = (p["fog"] as Color).lerp((w["fog"] as Color) * bright, wm)
	var top: Color = (p["top"] as Color).lerp((w["fog"] as Color).darkened(0.4) * bright, wm)
	var horizon: Color = (p["horizon"] as Color).lerp((w["fog"] as Color) * bright, wm)
	if mist > 0.0:
		fog_color = fog_color.lerp(Color(0.7, 0.8, 0.95) * bright, mist * 0.7)
	_sky_mat.set_shader_parameter("top_color", Vector3(top.r, top.g, top.b))
	_sky_mat.set_shader_parameter("horizon_color", Vector3(horizon.r, horizon.g, horizon.b))
	var ground: Color = p["ground"]
	_sky_mat.set_shader_parameter("ground_color", Vector3(ground.r, ground.g, ground.b))
	_sky_mat.set_shader_parameter("stars", night * (1.0 - wm * 0.8))
	_sky_mat.set_shader_parameter("sun_disc", 1.0 - night)
	_env.fog_light_color = fog_color
	_env.fog_density = lerpf(p["fog_density"], w["fog_density"], wm) + mist * 0.008
	# Niebo jako źródło światła otoczenia rozjaśnia scenę nawet przy małej sile,
	# więc nocą przechodzimy na prawie czarny kolor otoczenia.
	_env.ambient_light_sky_contribution = 1.0 - night
	_env.ambient_light_color = NIGHT_AMBIENT
	_env.ambient_light_energy = p["ambient"]
	_env.glow_intensity = p["glow"]
	var light: Color = (p["light"] as Color).lerp(w["light"], wm * (1.0 - night))
	_sun.light_color = light
	_sun.light_energy = p["energy"] * lerpf(1.0, w["scale"], wm)
	_sun.basis = Basis.looking_at(-_light_dir(t, night))


## Kierunek, z którego pada światło: słońce po łuku w dzień, księżyc w nocy.
static func _light_dir(t: float, night: float) -> Vector3:
	var arc := clampf((fposmod(t, 1.0) - 0.22) / 0.56, 0.0, 1.0)
	var elevation := sin(arc * PI) * deg_to_rad(62.0) + deg_to_rad(6.0)
	var azimuth := lerpf(deg_to_rad(100.0), deg_to_rad(-100.0), arc)
	var sun := Vector3(sin(azimuth) * cos(elevation), sin(elevation), -cos(azimuth) * cos(elevation))
	return sun.lerp(MOON_DIR.normalized(), smoothstep(0.5, 1.0, night)).normalized()


func _current_weather() -> Dictionary:
	return _mix(_weather_from, _weather_to, smoothstep(0.0, 1.0, _weather_t))


func _no_weather() -> Dictionary:
	return {"mix": 0.0, "fog_density": _day.get("fog_density", 0.004), "scale": 1.0,
		"light": _day.get("light", Color.WHITE), "fog": _day.get("fog", Color.WHITE)}


static func _mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in a:
		var va = a[key]
		var vb = b.get(key, va)
		if va is Color:
			out[key] = (va as Color).lerp(vb, k)
		else:
			out[key] = lerpf(float(va), float(vb), k)
	return out
