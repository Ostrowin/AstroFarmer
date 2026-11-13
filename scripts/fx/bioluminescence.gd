class_name Bioluminescence
extends Node3D
## Nocne świecenie poziomu: kępy trawy ze świecącymi czubkami, plamy mchu,
## świetliki i zarodniki w powietrzu, drzewa-grzyby świecące od spodu
## i świecące ślady stóp gracza. W dzień wszystko gaśnie (trawa jest zwykła).
## Układ zależy od `layout_seed`, więc mapa jest za każdym razem taka sama.

const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 base_color : source_color = vec3(0.06, 0.2, 0.15);
uniform vec3 day_base : source_color = vec3(0.22, 0.45, 0.32);
uniform vec3 day_tip : source_color = vec3(0.45, 0.72, 0.5);
uniform vec3 tip_color : source_color = vec3(0.2, 1.0, 0.75);
uniform float glow = 2.0;
uniform float night = 1.0;
varying float h;
void vertex() {
	h = UV.y;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.x += sin(TIME * 1.3 + world.x * 0.7 + world.z * 0.5) * 0.08 * h * h;
	VERTEX.z += cos(TIME * 1.1 + world.z * 0.6) * 0.06 * h * h;
}
void fragment() {
	// Źdźbła oświetlone jak ziemia (normalna w górę z obu stron), inaczej tył źdźbła jest czarny.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ALBEDO = mix(mix(day_base, base_color, night), mix(day_tip, tip_color * 0.4, night), h);
	float tip = smoothstep(0.55, 1.0, h);
	EMISSION = tip_color * tip * glow * night * (0.7 + 0.3 * sin(TIME * 2.0 + h * 6.0));
}
"""

const MOSS_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
uniform vec3 color : source_color = vec3(0.15, 0.9, 1.0);
uniform float strength = 0.9;
uniform float night = 1.0;
uniform float seed = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	vec2 q = UV + vec2(seed);
	float n = noise(q * 9.0 + TIME * 0.05) * 0.6 + noise(q * 23.0) * 0.4;
	float a = smoothstep(1.0, 0.2, r + (n - 0.5) * 0.6) * smoothstep(0.35, 0.65, n);
	ALBEDO = color * a * strength * night * (0.8 + 0.2 * sin(TIME * 0.9 + n * 6.0));
}
"""

const STEP_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
uniform vec3 color : source_color = vec3(0.3, 1.0, 0.8);
uniform float fade = 1.0;
void fragment() {
	vec2 c = (UV * 2.0 - 1.0) * vec2(1.6, 1.0);
	float a = smoothstep(1.0, 0.3, length(c));
	ALBEDO = color * a * fade * 1.6;
}
"""

const MOSS_COLORS := [Color(0.15, 0.9, 1.0), Color(0.4, 1.0, 0.55), Color(0.65, 0.4, 1.0)]
const STEP_SPACING := 0.55
const STEP_SECONDS := 4.0
const STEP_POOL := 48
const MUSHROOM_LIGHT := 2.5

@export var layout_seed := 5
## Prostokąt (środek w 0,0): połowa szerokości X i Z.
@export var half_extents := Vector2(42, 42)
@export var grass_clumps := 260
@export var blades := 9000
@export var moss_patches := 22
@export var fireflies := 260
@export var spores := 400
## Bez trawy i mchu w tym promieniu od środka (farma w bazie).
@export var inner_radius := 0.0
## Strefy bez trawy i mchu: Vector3(x, z, promień).
@export var keep_clear: Array[Vector3] = []

var night := 0.0
var _grass_mat: ShaderMaterial
var _moss_mats: Array[ShaderMaterial] = []
var _particles: Array[GPUParticles3D] = []
var _mushroom_lights: Array[OmniLight3D] = []
var _mushroom_mats: Array[StandardMaterial3D] = []
var _steps: Array[MeshInstance3D] = []
var _step_age: Array[float] = []
var _next_step := 0
var _last_step := Vector3.INF
var _blockers: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = layout_seed
	_collect_blockers()
	_build_grass()
	_build_moss()
	_particles.append(_make_particles(Color(0.85, 1.0, 0.35), fireflies, Vector3(half_extents.x, 2.0, half_extents.y), 1.2, 0.06, 6.0, Vector3.ZERO))
	_particles.append(_make_particles(Color(0.4, 0.75, 1.0), spores, Vector3(half_extents.x, 0.5, half_extents.y), 0.4, 0.04, 10.0, Vector3(0, 0.25, 0)))
	_light_mushrooms()
	_build_step_pool()
	_apply(GameState.night_amount(GameState.time_of_day))


func _process(delta: float) -> void:
	var n := GameState.night_amount(GameState.time_of_day)
	if absf(n - night) > 0.001:
		_apply(n)
	_update_steps(delta)


func _apply(n: float) -> void:
	night = n
	_grass_mat.set_shader_parameter("night", n)
	for m in _moss_mats:
		m.set_shader_parameter("night", n)
	for p in _particles:
		p.emitting = n > 0.3
		p.visible = n > 0.05
	for light in _mushroom_lights:
		light.light_energy = MUSHROOM_LIGHT * n
		light.visible = n > 0.05
	for m in _mushroom_mats:
		m.emission_energy_multiplier = 2.0 * n


# --- Trawa ------------------------------------------------------------------

func _build_grass() -> void:
	var blade := _blade_mesh()
	_grass_mat = ShaderMaterial.new()
	_grass_mat.shader = _shader(GRASS_SHADER)
	blade.surface_set_material(0, _grass_mat)
	var clumps: Array[Vector3] = []
	var attempts := 0
	while clumps.size() < grass_clumps and attempts < grass_clumps * 20:
		attempts += 1
		var p := Vector3(_rng.randf_range(-half_extents.x, half_extents.x), 0, _rng.randf_range(-half_extents.y, half_extents.y))
		if _free(p):
			clumps.append(p)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blade
	mm.instance_count = blades if not clumps.is_empty() else 0
	for i in mm.instance_count:
		var c: Vector3 = clumps[i % clumps.size()]
		var p := c + Vector3(_rng.randf_range(-0.9, 0.9), 0, _rng.randf_range(-0.9, 0.9))
		var s := _rng.randf_range(0.6, 1.4)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.6), s)), p))
	var grass := MultiMeshInstance3D.new()
	grass.name = "Grass"
	grass.multimesh = mm
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)


func _blade_mesh() -> ArrayMesh:
	# Trzy źdźbła w kępce: wąskie trójkąty, UV.y = wysokość (0 dół, 1 czubek).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := k * TAU / 3.0
		var off := Vector3(cos(a), 0, sin(a)) * 0.05
		var side := Vector3(-sin(a), 0, cos(a)) * 0.025
		var top := off * 2.5 + Vector3(0, 0.45 + 0.1 * k, 0)
		for v in [[off - side, 0.0], [off + side, 0.0], [top, 1.0]]:
			st.set_uv(Vector2(0, v[1]))
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0])
	return st.commit()


# --- Mech -------------------------------------------------------------------

func _build_moss() -> void:
	var shader := _shader(MOSS_SHADER)
	var placed := 0
	var attempts := 0
	while placed < moss_patches and attempts < moss_patches * 30:
		attempts += 1
		var p := Vector3(_rng.randf_range(-half_extents.x, half_extents.x), 0.03, _rng.randf_range(-half_extents.y, half_extents.y))
		if not _free(p):
			continue
		var quad := PlaneMesh.new()
		var size := _rng.randf_range(2.5, 6.0)
		quad.size = Vector2(size, size)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("color", MOSS_COLORS[placed % MOSS_COLORS.size()])
		mat.set_shader_parameter("seed", _rng.randf() * 50.0)
		_moss_mats.append(mat)
		var moss := MeshInstance3D.new()
		moss.name = "Moss%d" % placed
		moss.mesh = quad
		moss.material_override = mat
		moss.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		moss.position = p
		moss.rotation.y = _rng.randf() * TAU
		add_child(moss)
		placed += 1


# --- Świetliki i zarodniki --------------------------------------------------

func _make_particles(color: Color, amount: int, box: Vector3, speed: float, size: float, lifetime: float, gravity: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.visibility_aabb = AABB(Vector3(-box.x, -box.y - 1.0, -box.z) * 1.2, Vector3(box.x, box.y + 4.0, box.z) * 2.4)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = speed * 0.3
	pm.initial_velocity_max = speed
	pm.gravity = gravity
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.5
	pm.turbulence_noise_scale = 3.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	var tex := CurveTexture.new()
	tex.curve = curve
	pm.scale_curve = tex
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 4.0
	quad.material = m
	p.draw_pass_1 = quad
	p.position.y = box.y + 0.3
	add_child(p)
	return p


# --- Grzyby -----------------------------------------------------------------

func _light_mushrooms() -> void:
	var level := get_parent()
	if level == null:
		return
	for node in level.find_children("Mushroom*", "StaticBody3D", true, false):
		var light := OmniLight3D.new()
		light.name = "UnderGlow"
		light.light_color = Color(0.25, 0.6, 1.0)
		light.omni_range = 6.0
		light.position = Vector3(0, 2.8, 0)
		node.add_child(light)
		_mushroom_lights.append(light)
		var disc := CylinderMesh.new()
		disc.top_radius = 1.7
		disc.bottom_radius = 1.7
		disc.height = 0.02
		disc.radial_segments = 24
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.5, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.25, 0.6, 1.0)
		_mushroom_mats.append(mat)
		var under := MeshInstance3D.new()
		under.name = "UnderGills"
		under.mesh = disc
		under.material_override = mat
		under.set_meta("no_outline", true)
		under.position = Vector3(0, 3.12, 0)
		node.add_child(under)


# --- Ślady stóp -------------------------------------------------------------

func _build_step_pool() -> void:
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.22, 0.34)
	var shader := _shader(STEP_SHADER)
	for i in STEP_POOL:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var step := MeshInstance3D.new()
		step.mesh = quad
		step.material_override = mat
		step.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		step.visible = false
		add_child(step)
		_steps.append(step)
		_step_age.append(STEP_SECONDS)


## Liczba świecących śladów widocznych teraz (do testów).
func visible_steps() -> int:
	return _steps.filter(func(s: MeshInstance3D) -> bool: return s.visible).size()


func _update_steps(delta: float) -> void:
	for i in _steps.size():
		if not _steps[i].visible:
			continue
		_step_age[i] += delta
		var fade := 1.0 - _step_age[i] / STEP_SECONDS
		if fade <= 0.0:
			_steps[i].visible = false
		else:
			(_steps[i].material_override as ShaderMaterial).set_shader_parameter("fade", fade * night)
	if night < 0.3:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	# Tylko przy ziemi (w skoku śladów nie ma).
	if player == null or player.global_position.y > 0.6:
		return
	var at := player.global_position
	if _last_step != Vector3.INF and Vector2(at.x - _last_step.x, at.z - _last_step.z).length() < STEP_SPACING:
		return
	var heading := Vector2(at.x - _last_step.x, at.z - _last_step.z) if _last_step != Vector3.INF else Vector2(0, 1)
	_last_step = at
	var side := 1.0 if _next_step % 2 == 0 else -1.0
	var right := Vector3(heading.y, 0, -heading.x).normalized() * 0.12 * side
	var step := _steps[_next_step]
	step.global_position = Vector3(at.x, 0.04, at.z) + right
	step.rotation.y = atan2(heading.x, heading.y)
	step.visible = true
	_step_age[_next_step] = 0.0
	(step.material_override as ShaderMaterial).set_shader_parameter("fade", night)
	_next_step = (_next_step + 1) % _steps.size()


# --- Pomocnicze --------------------------------------------------------------

func _free(p: Vector3) -> bool:
	if Vector2(p.x, p.z).length() < inner_radius:
		return false
	for zone in keep_clear:
		if Vector2(p.x - zone.x, p.z - zone.y).length() < zone.z:
			return false
	for b in _blockers:
		if Vector2(p.x - b.x, p.z - b.y).length() < b.z:
			return false
	return true


## Budynki, źródła wody i lądowiska bez trawy (drzewa i skały mogą mieć trawę u stóp).
func _collect_blockers() -> void:
	var level := get_parent()
	if level == null:
		return
	for node in level.get_children():
		var body := node as StaticBody3D
		if body == null or body.name in ["Ground", "Bounds"] or body.name.begins_with("Rock") or body.name.begins_with("Mushroom") or body.name.begins_with("Cone"):
			continue
		var local := to_local(body.global_position)
		_blockers.append(Vector3(local.x, local.z, 4.5))


func _shader(code: String) -> Shader:
	var s := Shader.new()
	s.code = code
	return s
