class_name PlantVisuals
extends RefCounted
## Model rośliny dla danego etapu wzrostu.
## Gatunki z modelem z Blendera (art/models/plants/<id>.glb, trzy etapy:
## węzły <id>_stage0..2) ładują go; pozostałe budują się z prymitywów.
## Etap 0 = kiełek, ostatni etap = dojrzała roślina.
## Ruchome węzły modelu: Head/JawTop/JawBottom (Snapper), Cap (Boomshroom), Orbs (Mgielnik).

## Kąt otwarcia szczęk Snappera (radiany): górna +, dolna -.
const JAW_OPEN := 0.45

const MODELS := {
	&"voidberry": preload("res://art/models/plants/voidberry.glb"),
	&"crystal_bloom": preload("res://art/models/plants/crystal_bloom.glb"),
	&"snapper": preload("res://art/models/plants/snapper.glb"),
	&"boomshroom": preload("res://art/models/plants/boomshroom.glb"),
	&"mistbloom": preload("res://art/models/plants/mistbloom.glb"),
}
const MODEL_STAGES := 3
const GIANT_SCALE := 1.4

## Widoczne mutacje upraw: nazwa, bonus do plonu i wygląd.
const MUTATIONS := {
	&"golden": {"name": "Golden", "desc": "+1 yield", "harvest_bonus": 1, "seed_bonus": 0},
	&"giant": {"name": "Giant", "desc": "+2 yield", "harvest_bonus": 2, "seed_bonus": 0},
	&"glowing": {"name": "Glowing", "desc": "+1 seed", "harvest_bonus": 0, "seed_bonus": 1},
}
const GOLD := Color(0.98, 0.8, 0.25)

static var _materials: Dictionary = {}


static func build(data: PlantData, stage: int, mutation: StringName = &"") -> Node3D:
	var scene: PackedScene = MODELS.get(data.id)
	if scene == null:
		return _build_primitive(data, stage, mutation)
	var root := scene.instantiate() as Node3D
	root.name = "Model"
	# Etap danych -> etap modelu (modele mają 3 etapy).
	var model_stage := roundi(float(stage) / float(maxi(1, data.last_stage())) * (MODEL_STAGES - 1))
	var wanted := "%s_stage%d" % [data.id, model_stage]
	var keep: Node3D = null
	for child in root.get_children():
		if child.name == wanted:
			keep = child
		else:
			root.remove_child(child)
			child.free()
	if keep == null:
		return root
	keep.name = "Stage"
	var top := root.find_child("JawTop", true, false) as Node3D
	var bottom := root.find_child("JawBottom", true, false) as Node3D
	if top and bottom:
		top.rotation.x = JAW_OPEN
		bottom.rotation.x = -JAW_OPEN
	match mutation:
		&"golden":
			_tint_meshes(keep, GOLD, 0.65, 0.0)
		&"glowing":
			_tint_meshes(keep, Color.WHITE, 0.0, 0.5)
			var light := OmniLight3D.new()
			light.light_color = data.accent_color.lightened(0.3)
			light.light_energy = 1.2
			light.omni_range = 3.0
			light.position.y = 0.8
			root.add_child(light)
		&"giant":
			keep.scale = Vector3.ONE * GIANT_SCALE
	return root


## Kopie materiałów modelu: kolor przesunięty w stronę `tint`, opcjonalne świecenie.
static func _tint_meshes(node: Node, tint: Color, amount: float, glow: float) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		for i in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(i) as BaseMaterial3D
			if source == null:
				continue
			var copy := source.duplicate() as BaseMaterial3D
			if not copy.emission_enabled:
				copy.albedo_color = copy.albedo_color.lerp(tint, amount)
			if glow > 0.0:
				copy.emission_enabled = true
				copy.emission = copy.albedo_color
				copy.emission_energy_multiplier = maxf(copy.emission_energy_multiplier, glow) if source.emission_enabled else glow
			mesh_instance.set_surface_override_material(i, copy)


## Zapasowy model z prymitywów (gatunki bez modelu z Blendera).
static func _build_primitive(data: PlantData, stage: int, mutation: StringName = &"") -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var growth := float(stage) / float(maxi(1, data.last_stage()))
	var target := root
	if mutation != &"":
		# Mutacja zmienia kolory na kopii danych; olbrzymia powiększa wnętrze modelu
		# (zewnętrzny węzeł skaluje animacja "podskoku").
		data = data.duplicate()
		match mutation:
			&"golden":
				data.leaf_color = GOLD
				data.accent_color = data.accent_color.lerp(Color(1, 0.6, 0.1), 0.5)
			&"glowing":
				data.leaf_color = data.leaf_color.lightened(0.25)
				var light := OmniLight3D.new()
				light.light_color = data.accent_color.lightened(0.3)
				light.light_energy = 1.2
				light.omni_range = 2.5
				light.position.y = 0.6
				root.add_child(light)
			&"giant":
				target = Node3D.new()
				target.scale = Vector3.ONE * 1.4
				root.add_child(target)
	match data.shape:
		PlantData.Shape.BUSH:
			_build_bush(target, data, stage, growth)
		PlantData.Shape.CRYSTAL:
			_build_crystal(target, data, stage, growth)
		PlantData.Shape.SNAPPER:
			_build_snapper(target, data, stage, growth)
		PlantData.Shape.MUSHROOM:
			_build_mushroom(target, data, stage, growth)
		PlantData.Shape.MIST:
			_build_mist(target, data, stage, growth)
	if mutation == &"glowing":
		_glow_all(target)
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


static func _build_mushroom(root: Node3D, data: PlantData, stage: int, growth: float) -> void:
	if stage == 0:
		# Kiełek grzyba: mała kulka na nóżce.
		_add(root, _cylinder(0.03, 0.04, 0.16), Vector3(0, 0.08, 0), data.leaf_color)
		_add(root, _sphere(0.08, 0.1), Vector3(0, 0.18, 0), data.accent_color.darkened(0.2))
		return
	var height := lerpf(0.3, 0.55, growth)
	var radius := lerpf(0.22, 0.42, growth)
	_add(root, _cylinder(0.08, 0.11, height), Vector3(0, height * 0.5, 0), data.leaf_color)
	# Kapelusz na osobnym węźle "Cap": puff go ściska.
	var cap := Node3D.new()
	cap.name = "Cap"
	cap.position = Vector3(0, height, 0)
	root.add_child(cap)
	_add(cap, _sphere(radius, radius * 1.1), Vector3(0, radius * 0.25, 0), data.accent_color)
	var spot := _sphere(radius * 0.18, radius * 0.12)
	for i in 5:
		var angle := TAU * i / 5.0 + 0.4
		var pos := Vector3(cos(angle) * radius * 0.62, radius * 0.6, sin(angle) * radius * 0.62)
		_add(cap, spot, pos, Color(1, 0.95, 0.75), Vector3(sin(angle) * 0.6, 0, -cos(angle) * 0.6), 0.8 if stage == data.last_stage() else 0.0)
	if stage < data.last_stage():
		return
	# Dojrzały: oczka pod kapeluszem (trochę uroczo, trochę strasznie).
	for side in [-1.0, 1.0]:
		_add(root, _sphere(0.055, 0.09), Vector3(0.07 * side, height - 0.05, -0.1), Color(1, 1, 0.85), Vector3.ZERO, 0.6)
		_add(root, _sphere(0.025, 0.04), Vector3(0.07 * side, height - 0.05, -0.145), Color(0.1, 0.05, 0.1))


static func _build_mist(root: Node3D, data: PlantData, stage: int, growth: float) -> void:
	if stage == 0:
		# Uśpione nasiono: twarda, szara łupina z bladą szczeliną.
		_add(root, _sphere(0.13, 0.17), Vector3(0, 0.08, 0), Color(0.55, 0.58, 0.65))
		_add(root, _cylinder(0.012, 0.012, 0.14), Vector3(0, 0.13, 0.11), data.accent_color, Vector3(0.3, 0, 0), 0.8)
		return
	var height := lerpf(0.45, 0.95, growth)
	_add(root, _cylinder(0.025, 0.04, height), Vector3(0, height * 0.5, 0), data.leaf_color)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		_add(root, _sphere(0.13, 0.04), Vector3(0.1 * side, height * 0.35, 0), data.leaf_color.darkened(0.1), Vector3(0, 0, -0.5 * side))
	var bulb := lerpf(0.1, 0.2, growth)
	_add(root, _sphere(bulb, bulb * 1.5), Vector3(0, height + bulb * 0.4, 0), data.accent_color, Vector3.ZERO, 1.0)
	if stage < data.last_stage():
		return
	# Dojrzały: wokół bańki unoszą się małe, świecące krople mgły.
	var orb := _sphere(0.05, 0.1)
	for i in 4:
		var angle := TAU * i / 4.0
		_add(root, orb, Vector3(cos(angle) * 0.3, height + 0.1 + 0.08 * sin(angle * 2.0), sin(angle) * 0.3), Color(0.85, 0.95, 1.0), Vector3.ZERO, 1.5)


## Mutacja "świecąca": wszystkie części lekko świecą.
static func _glow_all(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh := child as MeshInstance3D
			var base := (mesh.material_override as StandardMaterial3D).albedo_color
			mesh.material_override = material(base, 0.5)
		_glow_all(child)


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
