class_name ForestMushrooms
extends Node3D
## Grzyby Grzybowego Lasu z brył (wersja testowa, wg szkicu art/source/sketches/mushroom_*):
##   Towercap - olbrzymy 22-40 m, kapelusze robią sufit lasu, blaszki świecą turkusem,
##   Bellcap  - średnie 5-11 m, dzwonowaty kapelusz, blaszki magenta,
##   Glowcap  - kępki małych świecących grzybków na ziemi.
## Rysowane przez MultiMesh (jedno wywołanie na rodzaj części). Trzony mają kolizję.
## Układ losowy razem z terenem (to samo RNG), omija lądowisko, kanion i doły.

@export var terrain_path: NodePath
@export var giant_count := 110
@export var bell_count := 110
@export var glowcap_clusters := 90

const STEM_COLOR := Color(0.5, 0.46, 0.56)
const BELL_STEM_COLOR := Color(0.36, 0.42, 0.44)

var giants: Array[Dictionary] = []

var _terrain: ForestTerrain


func _ready() -> void:
	_terrain = get_node(terrain_path) as ForestTerrain
	var rng := RandomNumberGenerator.new()
	rng.seed = _terrain.rng.randi()
	_place_giants(rng)
	var bells := _place_bells(rng)
	_build_giants()
	_build_bells(bells)
	_build_glowcaps(rng)


# --- Rozmieszczenie ----------------------------------------------------------

func _place_giants(rng: RandomNumberGenerator) -> void:
	giants.clear()
	var tries := 0
	while giants.size() < giant_count and tries < giant_count * 12:
		tries += 1
		var radius := rng.randf_range(9.0, 16.0)
		# Kapelusz nie może przykrywać lądowiska (słup światła latarni ma być widać).
		var base := _terrain.random_point(rng, radius + 6.0, true, true)
		var ok := true
		for g in giants:
			var other: Vector3 = g["base"]
			if Vector2(base.x - other.x, base.z - other.z).length() < (radius + float(g["radius"])) * 0.55:
				ok = false
				break
		if not ok or _terrain.slope_at(base.x, base.z) > 0.45:
			continue
		var tilt := Vector3(rng.randf_range(-0.09, 0.09), 0, rng.randf_range(-0.09, 0.09))
		giants.append({"base": base, "height": rng.randf_range(22.0, 40.0), "radius": radius,
			"stem": 0.6 + radius * 0.075, "tilt": tilt, "spin": rng.randf_range(0, TAU)})


func _place_bells(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var bells: Array[Dictionary] = []
	for i in bell_count:
		var base := _terrain.random_point(rng, 4.0, true, true)
		bells.append({"base": base, "height": rng.randf_range(5.0, 11.0), "radius": rng.randf_range(1.4, 3.0),
			"tilt": Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15)), "spin": rng.randf_range(0, TAU)})
	return bells


# --- Budowa -------------------------------------------------------------------

func _build_giants() -> void:
	var stem := _multimesh(_stem_mesh(0.62), giants.size())
	var cap := _multimesh(_cap_mesh(), giants.size())
	(stem.multimesh.mesh as ArrayMesh).surface_set_material(0, _plain(STEM_COLOR))
	(cap.multimesh.mesh as ArrayMesh).surface_set_material(0, _cap_material(Color(0.3, 0.16, 0.4), Color(0.72, 0.62, 0.86), 1.1))
	(cap.multimesh.mesh as ArrayMesh).surface_set_material(1, _gill_material(Color(0.1, 0.75, 0.9), 0.75, 90.0))
	for i in giants.size():
		var g := giants[i]
		var up := Basis.from_euler(g["tilt"])
		var h: float = g["height"]
		var r: float = g["stem"]
		var base: Vector3 = g["base"] - Vector3(0, 0.5, 0)
		stem.multimesh.set_instance_transform(i, Transform3D(up.scaled(Vector3(r, h + 0.5, r)), base + up.y * (h + 0.5) * 0.5))
		var top := base + up.y * (h + 0.5)
		var cap_r: float = g["radius"]
		var cap_basis := (up * Basis(Vector3.UP, g["spin"])).scaled(Vector3(cap_r, cap_r, cap_r))
		cap.multimesh.set_instance_transform(i, Transform3D(cap_basis, top))
		_add_stem_collision(g["base"], up, h, r * 0.85)
	add_child(stem)
	add_child(cap)


func _build_bells(bells: Array[Dictionary]) -> void:
	var stem := _multimesh(_stem_mesh(0.7), bells.size())
	var cap := _multimesh(_bell_mesh(), bells.size())
	(stem.multimesh.mesh as ArrayMesh).surface_set_material(0, _plain(BELL_STEM_COLOR))
	(cap.multimesh.mesh as ArrayMesh).surface_set_material(0, _cap_material(Color(0.06, 0.2, 0.24), Color(0.5, 0.85, 0.8), 2.6))
	(cap.multimesh.mesh as ArrayMesh).surface_set_material(1, _gill_material(Color(0.95, 0.25, 0.75), 1.1, 50.0))
	for i in bells.size():
		var b := bells[i]
		var up := Basis.from_euler(b["tilt"])
		var h: float = b["height"]
		var r: float = b["radius"]
		var stem_r := 0.18 + r * 0.06
		var base: Vector3 = b["base"] - Vector3(0, 0.3, 0)
		stem.multimesh.set_instance_transform(i, Transform3D(up.scaled(Vector3(stem_r, h, stem_r)), base + up.y * h * 0.5))
		cap.multimesh.set_instance_transform(i, Transform3D((up * Basis(Vector3.UP, b["spin"])).scaled(Vector3(r, r, r)), base + up.y * (h - 0.1 * r)))
		_add_stem_collision(b["base"], up, h, stem_r)
	add_child(stem)
	add_child(cap)


func _build_glowcaps(rng: RandomNumberGenerator) -> void:
	var transforms: Array[Transform3D] = []
	for c in glowcap_clusters:
		var center := _terrain.random_point(rng, 3.0, false, false)
		for i in rng.randi_range(4, 9):
			var a := rng.randf_range(0, TAU)
			var d := rng.randf_range(0.0, 1.0)
			var x := center.x + cos(a) * d
			var z := center.z + sin(a) * d
			var s := rng.randf_range(0.06, 0.16)
			var stem_h := rng.randf_range(0.15, 0.55)
			var y := _terrain.height_at(x, z) + stem_h
			transforms.append(Transform3D(Basis.from_scale(Vector3(s, s * 0.55, s)), Vector3(x, y, z)))
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	var glow := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = GLOWCAP_SHADER
	glow.shader = shader
	mesh.material = glow
	var mm := MultiMeshInstance3D.new()
	mm.name = "Glowcaps"
	mm.multimesh = MultiMesh.new()
	mm.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	mm.multimesh.mesh = mesh
	mm.multimesh.instance_count = transforms.size()
	for i in transforms.size():
		mm.multimesh.set_instance_transform(i, transforms[i])
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mm)


func _add_stem_collision(base: Vector3, up: Basis, height: float, radius: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	body.transform = Transform3D(up, base + up.y * height * 0.5)
	add_child(body)


func _multimesh(mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mm := MultiMeshInstance3D.new()
	mm.multimesh = MultiMesh.new()
	mm.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	mm.multimesh.mesh = mesh
	mm.multimesh.instance_count = count
	mm.set_meta("no_outline", true)
	return mm


# --- Siatki (bryły obrotowe) --------------------------------------------------

## Trzon: zwężający się walec o wysokości 1 i promieniu podstawy 1 (środek w połowie wysokości).
func _stem_mesh(top_ratio: float) -> ArrayMesh:
	return _lathe([[Vector2(1.15, -0.5), Vector2(1.0, -0.44), Vector2(0.82, -0.1), Vector2(top_ratio, 0.5)]], 14)


## Kapelusz olbrzyma: kopuła z falistym brzegiem (powierzchnia 0) + wklęsłe blaszki (1). Promień 1.
func _cap_mesh() -> ArrayMesh:
	var top := [Vector2(0.0, 0.42), Vector2(0.35, 0.39), Vector2(0.65, 0.3), Vector2(0.87, 0.16), Vector2(0.98, 0.03), Vector2(1.0, -0.04)]
	var gills := [Vector2(1.0, -0.04), Vector2(0.75, 0.0), Vector2(0.4, 0.07), Vector2(0.08, 0.14)]
	return _lathe([top, gills], 40)


## Kapelusz dzwonowaty (Bellcap): wysoki, z rozchylonym brzegiem.
func _bell_mesh() -> ArrayMesh:
	var top := [Vector2(0.0, 1.15), Vector2(0.45, 1.06), Vector2(0.75, 0.82), Vector2(0.92, 0.45), Vector2(1.05, 0.12), Vector2(1.2, 0.0)]
	var gills := [Vector2(1.2, 0.0), Vector2(0.8, 0.25), Vector2(0.4, 0.5), Vector2(0.1, 0.62)]
	return _lathe([top, gills], 28)


## Bryła obrotowa wokół osi Y; każdy profil (lista Vector2(promień, wysokość)) to osobna powierzchnia.
func _lathe(profiles: Array, segments: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for profile: Array in profiles:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for s in segments:
			var a0 := TAU * s / segments
			var a1 := TAU * (s + 1) / segments
			for k in profile.size() - 1:
				var p: Vector2 = profile[k]
				var q: Vector2 = profile[k + 1]
				var v00 := Vector3(cos(a0) * p.x, p.y, sin(a0) * p.x)
				var v01 := Vector3(cos(a1) * p.x, p.y, sin(a1) * p.x)
				var v10 := Vector3(cos(a0) * q.x, q.y, sin(a0) * q.x)
				var v11 := Vector3(cos(a1) * q.x, q.y, sin(a1) * q.x)
				st.add_vertex(v00)
				st.add_vertex(v10)
				st.add_vertex(v01)
				st.add_vertex(v01)
				st.add_vertex(v10)
				st.add_vertex(v11)
		st.generate_normals()
		st.commit(mesh)
	return mesh


# --- Materiały ----------------------------------------------------------------

func _plain(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	return m


func _cap_material(base: Color, spot: Color, spot_scale: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = CAP_SHADER
	m.shader = shader
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("spot_color", spot)
	m.set_shader_parameter("spot_scale", spot_scale)
	return m


func _gill_material(glow: Color, strength: float, stripes: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = GILL_SHADER
	m.shader = shader
	m.set_shader_parameter("glow_color", glow)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("stripes", stripes)
	return m


## Małe świecące grzybki: migoczą, każdy w swoim rytmie.
const GLOWCAP_SHADER := """
shader_type spatial;
render_mode unshaded;
varying float phase;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	phase = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831;
}
void fragment() {
	float b = 0.5 + 0.5 * sin(TIME * 1.3 + phase) * sin(TIME * 0.41 + phase * 2.0);
	ALBEDO = vec3(0.4, 1.0, 0.6) * (0.45 + 0.75 * b);
}
"""

## Kapelusz: kolor bazowy + jasne plamki (komórki w przestrzeni siatki), plamki lekko świecą.
const CAP_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_toon;
uniform vec3 base_color : source_color;
uniform vec3 spot_color : source_color;
uniform float spot_scale = 1.0;
varying vec3 lp;
varying float phase;
void vertex() {
	lp = VERTEX;
	vec3 o = MODEL_MATRIX[3].xyz;
	phase = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831;
	// Brzeg kapelusza powoli faluje (ta sama formuła w kapeluszu i blaszkach, żeby się nie rozjechały).
	float r = length(VERTEX.xz);
	VERTEX.y += sin(TIME * 0.7 + atan(VERTEX.z, VERTEX.x) * 3.0 + phase) * 0.025 * r * r;
}
vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}
void fragment() {
	vec3 p = lp * 9.0 * spot_scale;
	vec3 cell = floor(p);
	float d = 9.0;
	for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) for (int z = -1; z <= 1; z++) {
		vec3 c = cell + vec3(float(x), float(y), float(z));
		d = min(d, length(p - c - hash3(c)));
	}
	float spot = 1.0 - smoothstep(0.12, 0.18, d);
	ALBEDO = mix(base_color, spot_color, spot);
	EMISSION = spot_color * spot * 0.15;
	ROUGHNESS = 0.7;
}
"""

## Blaszki: gęste, nieregularne promieniste paski; najjaśniej blisko brzegu, przy trzonie ciemno.
const GILL_SHADER := """
shader_type spatial;
render_mode cull_disabled, unshaded;
uniform vec3 glow_color : source_color;
uniform float strength = 1.5;
uniform float stripes = 120.0;
varying vec3 lp;
varying float phase;
void vertex() {
	lp = VERTEX;
	vec3 o = MODEL_MATRIX[3].xyz;
	phase = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831;
	// Brzeg kapelusza powoli faluje (ta sama formuła w kapeluszu i blaszkach, żeby się nie rozjechały).
	float r = length(VERTEX.xz);
	VERTEX.y += sin(TIME * 0.7 + atan(VERTEX.z, VERTEX.x) * 3.0 + phase) * 0.025 * r * r;
}
void fragment() {
	float r = length(lp.xz);
	float a = atan(lp.z, lp.x);
	float wobble = sin(r * 23.0 + a * 3.0) * 0.12;
	float sp = (a + wobble) * stripes;
	float s = 0.45 + 0.55 * (0.5 + 0.5 * sin(sp));
	// Z daleka paski zlewają się w równą poświatę (bez migotania).
	s = mix(s, 0.72, clamp(fwidth(sp) * 0.4, 0.0, 1.0));
	float radial = smoothstep(0.15, 0.75, r) * (1.0 - 0.6 * smoothstep(0.85, 1.05, r));
	// Świecenie co jakiś czas narasta i gaśnie (każdy grzyb w swoim rytmie).
	float breath = 0.5 + 0.5 * sin(TIME * 0.45 + phase) * sin(TIME * 0.17 + phase * 3.0);
	ALBEDO = glow_color * s * radial * strength * (0.7 + 0.6 * breath);
}
"""
