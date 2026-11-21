class_name SporekinVillage
extends Node3D
## Wioska Sporekinów (miejsce: ForestTerrain.village): chatki z trzciny na palach w kręgu,
## kładka między dwiema chatkami, lampiony na tyczkach, ognisko z grzybami pośrodku,
## kilku Sporekinów i handlarz z lampionem. Bezpieczna strefa reżysera przeciwników.

@export var terrain_path: NodePath

const HUT := preload("res://art/models/forest/stilt_hut.glb")
const HUT_SMALL := preload("res://art/models/forest/stilt_hut_small.glb")

var trader: Sporekin
var folk: Array[Sporekin] = []
var huts: Array[Node3D] = []

var _terrain: ForestTerrain


func _ready() -> void:
	_terrain = get_node(terrain_path) as ForestTerrain
	var v := _terrain.village
	if v.z <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _terrain.rng.randi()
	var center := _terrain.village_point()
	# Chatki w kręgu, wejściem do środka.
	var count := 5
	var a0 := rng.randf_range(0, TAU)
	for i in count:
		var a := a0 + TAU * i / count + rng.randf_range(-0.2, 0.2)
		var r := v.z * rng.randf_range(0.62, 0.8)
		var p := _terrain.surface_point(v.x + cos(a) * r, v.y + sin(a) * r)
		var big := i % 2 == 0
		var hut := (HUT if big else HUT_SMALL).instantiate() as Node3D
		add_child(hut)
		hut.global_position = p
		# Drzwi (w Blenderze -Y = Godot +Z) w stronę placu.
		var to := center - p
		hut.rotation.y = atan2(to.x, to.z)
		ForestProps.apply(hut, "stilt_hut")
		_hut_collision(p, 1.6 if big else 1.25, 4.2 if big else 3.4)
		huts.append(hut)
	# Kładka z desek między dwiema pierwszymi chatkami (na wysokości podłóg).
	if huts.size() >= 2:
		_walkway(huts[0].global_position + Vector3(0, 1.1, 0), huts[1].global_position + Vector3(0, 1.1, 0))
	# Ognisko i lampiony.
	_campfire(center)
	for i in 6:
		var a := a0 + TAU * (i + 0.5) / 6.0
		_lantern_post(_terrain.surface_point(v.x + cos(a) * v.z * 0.45, v.y + sin(a) * v.z * 0.45))
	# Sporekini: handlarz przy ognisku, reszta po placu.
	trader = Sporekin.new()
	trader.trader = true
	add_child(trader)
	var tp := _terrain.surface_point(v.x + 2.6, v.y + 0.5)
	trader.global_position = tp
	for i in 4:
		var kin := Sporekin.new()
		kin.variant = i
		add_child(kin)
		var a := rng.randf_range(0, TAU)
		var r := rng.randf_range(3.5, v.z * 0.5)
		kin.global_position = _terrain.surface_point(v.x + cos(a) * r, v.y + sin(a) * r)
		kin.rotation.y = rng.randf_range(0, TAU)
		folk.append(kin)


func center() -> Vector3:
	return _terrain.village_point()


func radius() -> float:
	return _terrain.village.z


func _hut_collision(at: Vector3, r: float, h: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = h * 0.5 + 0.9
	body.add_child(cs)
	add_child(body)
	body.global_position = at


func _walkway(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var flat := Vector3(d.x, 0, d.z)
	var n := int(flat.length() / 0.35)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.06, 0.26)
	var mat := ForestProps.material("Wood", "village")
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = maxi(n, 0)
	var basis := Basis.looking_at(flat.normalized(), Vector3.UP).rotated(Vector3.UP, PI / 2)
	for i in n:
		var t := (i + 0.5) / n
		var p := a + d * t + Vector3(0, -0.6 * 4.0 * t * (1.0 - t), 0)
		mm.set_instance_transform(i, Transform3D(basis.rotated(basis.y, randf_range(-0.05, 0.05)), p - global_position))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _campfire(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.7
	torus.outer_radius = 1.0
	ring.mesh = torus
	ring.material_override = ForestProps.material("Rock", "village")
	add_child(ring)
	ring.global_position = at + Vector3(0, 0.08, 0)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.3)
	light.light_energy = 2.2
	light.omni_range = 9.0
	add_child(light)
	light.global_position = at + Vector3(0, 0.8, 0)
	var flame := GPUParticles3D.new()
	flame.amount = 40
	flame.lifetime = 0.9
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.4, 1))
	ramp.set_color(1, Color(0.9, 0.2, 0.05, 0))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_ramp = tex
	flame.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.25, 0.25)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	quad.material = qm
	flame.draw_pass_1 = quad
	add_child(flame)
	flame.global_position = at + Vector3(0, 0.15, 0)


func _lantern_post(at: Vector3) -> void:
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.06
	cyl.height = 2.4
	pole.mesh = cyl
	pole.material_override = ForestProps.material("Wood", "village")
	add_child(pole)
	pole.global_position = at + Vector3(0, 1.2, 0)
	var bulb := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.14
	sph.height = 0.36
	bulb.mesh = sph
	bulb.material_override = ForestProps.material("Lantern", "village")
	add_child(bulb)
	bulb.global_position = at + Vector3(0.25, 2.25, 0)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.35)
	light.light_energy = 0.9
	light.omni_range = 5.0
	add_child(light)
	light.global_position = bulb.global_position
