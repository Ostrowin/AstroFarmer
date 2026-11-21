class_name ForestSpores
extends Node3D
## Zarodniki pod kapeluszami (wg uwagi autora): drobne jak piksele, tylko pod kapeluszami.
## Każdy zarodnik ma własny czas życia (część gaśnie po chwili, część opada prawie do ziemi)
## i gaśnie w miarę opadania. Żeby nie liczyć całego lasu, pula emiterów obsługuje tylko
## najbliższe graczowi grzyby (przydział co sekundę).

@export var mushrooms_path: NodePath
@export var giant_emitters := 14
@export var range_m := 70.0

var emitters: Array[GPUParticles3D] = []

var _mushrooms: ForestMushrooms
var _assigned: Array[int] = []
var _timer := 0.0


func _ready() -> void:
	_mushrooms = get_node(mushrooms_path) as ForestMushrooms
	for i in giant_emitters:
		var e := _make_emitter()
		add_child(e)
		e.emitting = false
		emitters.append(e)
		_assigned.append(-1)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.0
	var cam := get_viewport().get_camera_3d()
	if cam == null or _mushrooms == null:
		return
	var origin := cam.global_position
	# Najbliższe olbrzymy.
	var near: Array = []
	for gi in _mushrooms.giants.size():
		var g: Dictionary = _mushrooms.giants[gi]
		var d := Vector2((g["base"] as Vector3).x - origin.x, (g["base"] as Vector3).z - origin.z).length()
		if d < range_m:
			near.append([d, gi])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var wanted: Array[int] = []
	for k in mini(near.size(), emitters.size()):
		wanted.append(int(near[k][1]))
	# Zostaw emitery już przypisane do potrzebnych grzybów, resztę przenieś.
	var free_slots: Array[int] = []
	for i in emitters.size():
		if _assigned[i] in wanted:
			wanted.erase(_assigned[i])
		else:
			free_slots.append(i)
	for i in free_slots:
		if wanted.is_empty():
			emitters[i].emitting = false
			_assigned[i] = -1
			continue
		var gi: int = wanted.pop_front()
		_assigned[i] = gi
		_place(emitters[i], _mushrooms.giants[gi])


## Emiter na dysku pod kapeluszem (tuż pod blaszkami), zasięg spadania wg wysokości grzyba.
func _place(e: GPUParticles3D, g: Dictionary) -> void:
	var up := Basis.from_euler(g["tilt"])
	var base: Vector3 = g["base"]
	var h: float = g["height"]
	var r: float = g["radius"]
	var top := base + up.y * (h + 0.5) - Vector3(0, 0.5, 0)
	e.global_position = top
	var pm := e.process_material as ParticleProcessMaterial
	pm.emission_ring_radius = r * 0.85
	pm.emission_ring_inner_radius = r * 0.2
	e.visibility_aabb = AABB(Vector3(-r, -h, -r), Vector3(r * 2, h + 1.0, r * 2))
	e.restart()
	e.emitting = true


func _make_emitter() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 260
	p.lifetime = 14.0
	p.preprocess = 10.0
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 1, 0)
	pm.emission_ring_height = 0.2
	pm.emission_ring_radius = 8.0
	pm.emission_ring_inner_radius = 1.0
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, -0.12, 0)
	pm.damping_min = 0.02
	pm.damping_max = 0.08
	# Część gaśnie szybko, część opada długo.
	pm.lifetime_randomness = 0.85
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	ramp.add_point(0.05, Color(1, 1, 1, 1.0))
	ramp.add_point(0.5, Color(1, 1, 1, 0.55))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_ramp = tex
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.45, 0.95, 1.0)
	quad.material = mat
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
