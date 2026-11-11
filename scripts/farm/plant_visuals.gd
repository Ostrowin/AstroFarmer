class_name PlantVisuals
extends RefCounted
## Buduje prosty, kreskówkowy model rośliny z prymitywów (prototyp bez assetów).
## Etap 0 = kiełek, ostatni etap = dojrzała roślina z owocami / kryształami / paszczą.

## Kąt otwarcia szczęk Snappera (radiany): górna +, dolna -.
const JAW_OPEN := 0.45

static var _materials: Dictionary = {}


static func build(data: PlantData, stage: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var growth := float(stage) / float(maxi(1, data.last_stage()))
	match data.shape:
		PlantData.Shape.BUSH:
			_build_bush(root, data, stage, growth)
		PlantData.Shape.CRYSTAL:
			_build_crystal(root, data, stage, growth)
		PlantData.Shape.SNAPPER:
			_build_snapper(root, data, stage, growth)
	return root


static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(), glow]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.8
		if glow > 0.0:
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = glow
		_materials[key] = mat
	return _materials[key]


# --- Kształty ----------------------------------------------------------------

static func _build_sprout(root: Node3D, color: Color) -> void:
	_add(root, _cylinder(0.025, 0.03, 0.25), Vector3(0, 0.125, 0), color)
	_add(root, _sphere(0.09, 0.05), Vector3(0.07, 0.25, 0), color, Vector3(0, 0, -0.5))
	_add(root, _sphere(0.09, 0.05), Vector3(-0.07, 0.27, 0), color, Vector3(0, 0, 0.5))


static func _build_bush(root: Node3D, data: PlantData, stage: int, growth: float) -> void:
	if stage == 0:
		_build_sprout(root, data.leaf_color)
		return
	var radius := lerpf(0.25, 0.5, growth)
	_add(root, _sphere(radius, radius * 1.6), Vector3(0, radius * 0.8, 0), data.leaf_color)
	_add(root, _sphere(radius * 0.7, radius * 1.1), Vector3(radius * 0.5, radius * 0.6, radius * 0.3), data.leaf_color.darkened(0.1))
	if stage == data.last_stage():
		var berry := _sphere(0.085, 0.17)
		for i in 6:
			var angle := TAU * i / 6.0
			var pos := Vector3(cos(angle) * radius * 0.85, radius * (0.75 + 0.35 * sin(angle * 2.0)), sin(angle) * radius * 0.85)
			_add(root, berry, pos, data.accent_color, Vector3.ZERO, 0.6)


static func _build_crystal(root: Node3D, data: PlantData, stage: int, growth: float) -> void:
	if stage == 0:
		_build_sprout(root, data.leaf_color)
		return
	var height := lerpf(0.45, 0.8, growth)
	_add(root, _cylinder(0.03, 0.05, height), Vector3(0, height * 0.5, 0), data.leaf_color)
	for i in 3:
		var angle := TAU * i / 3.0
		var leaf_pos := Vector3(cos(angle) * 0.14, 0.12, sin(angle) * 0.14)
		_add(root, _sphere(0.12, 0.05), leaf_pos, data.leaf_color.darkened(0.15), Vector3(0, -angle, 0.4))
	if stage < data.last_stage():
		_add(root, _cone(0.1, 0.22, 5), Vector3(0, height + 0.08, 0), data.accent_color.darkened(0.3))
		return
	var petal := _sphere(0.16, 0.06)
	for i in 5:
		var angle := TAU * i / 5.0
		_add(root, petal, Vector3(cos(angle) * 0.14, height, sin(angle) * 0.14), Color(0.95, 0.75, 1.0))
	var shard := _cone(0.06, 0.35, 4)
	_add(root, shard, Vector3(0, height + 0.2, 0), data.accent_color, Vector3.ZERO, 1.2)
	_add(root, shard, Vector3(0.1, height + 0.1, 0.05), data.accent_color, Vector3(0, 0, -0.5), 1.2)
	_add(root, shard, Vector3(-0.08, height + 0.1, -0.06), data.accent_color, Vector3(0.4, 0, 0.4), 1.2)


static func _build_snapper(root: Node3D, data: PlantData, stage: int, growth: float) -> void:
	if stage == 0:
		_build_sprout(root, data.leaf_color)
		return
	var height := lerpf(0.4, 0.75, growth)
	_add(root, _cylinder(0.04, 0.06, height), Vector3(0, height * 0.5, 0), data.leaf_color)
	_add(root, _sphere(0.18, 0.06), Vector3(0.14, 0.06, 0), data.leaf_color.darkened(0.1), Vector3(0, 0, -0.3))
	_add(root, _sphere(0.18, 0.06), Vector3(-0.14, 0.06, 0), data.leaf_color.darkened(0.1), Vector3(0, 0, 0.3))
	if stage < data.last_stage():
		_add(root, _sphere(0.14, 0.24), Vector3(0, height + 0.08, 0), data.accent_color.darkened(0.25))
		return
	# Dojrzała paszcza: dwie szczęki na zawiasach, z zębami i oczkiem.
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, height + 0.05, 0)
	root.add_child(head)
	for jaw_name in ["JawTop", "JawBottom"]:
		var pivot := Node3D.new()
		pivot.name = jaw_name
		var side := 1.0 if jaw_name == "JawTop" else -1.0
		pivot.rotation.x = JAW_OPEN * side
		head.add_child(pivot)
		_add(pivot, _sphere(0.24, 0.14), Vector3(0, 0.04 * side, -0.16), data.accent_color)
		var tooth := _cone(0.025, 0.08, 4)
		for t in 4:
			var x := -0.12 + t * 0.08
			_add(pivot, tooth, Vector3(x, -0.03 * side, -0.3), Color(1, 0.97, 0.9), Vector3(PI if side > 0 else 0.0, 0, 0))
	_add(head, _sphere(0.06, 0.12), Vector3(0, 0.2, 0.02), Color(1, 1, 0.85), Vector3.ZERO, 0.5)
	_add(head, _sphere(0.03, 0.06), Vector3(0, 0.21, -0.03), Color(0.1, 0.05, 0.1))


# --- Pomocnicze --------------------------------------------------------------

static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, rot := Vector3.ZERO, glow := 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rot
	instance.material_override = material(color, glow)
	parent.add_child(instance)
	return instance


static func _sphere(radius: float, height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 1
	return mesh


static func _cone(radius: float, height: float, segments: int) -> CylinderMesh:
	var mesh := _cylinder(0.0, radius, height)
	mesh.radial_segments = segments
	return mesh
