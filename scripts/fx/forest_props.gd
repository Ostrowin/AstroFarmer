class_name ForestProps
extends RefCounted
## Modele otoczenia Grzybowego Lasu (art/models/forest/*.glb, z tools/blender/forest_props.py).
## Materiały z Blendera to tylko nazwy: tu dostają wspólny shader lasu (forest_prop.gdshader)
## z kolorem, świeceniem i ruchem (kołysanie, falowanie, pulsowanie).

const PATH := "res://art/models/forest/%s.glb"
const SHADER := preload("res://art/materials/forest_prop.gdshader")

## Parametry shadera dla każdego materiału z Blendera (po nazwie).
const MATERIALS := {
	"GhostTop": {"albedo": Color(0.5, 0.75, 0.42), "glows": true, "glow_color": Color(0.45, 1.0, 0.3),
		"strength_in": 0.85, "strength_out": 0.55, "stripes": 26.0, "stripe_amount": 0.25, "wave": 0.03},
	"GhostGill": {"albedo": Color(0.4, 0.65, 0.3), "glows": true, "glow_color": Color(0.6, 1.0, 0.3),
		"strength_in": 1.0, "strength_out": 0.5, "stripes": 60.0, "stripe_amount": 0.6, "wave": 0.03},
	"RuffleGlow": {"albedo": Color(0.3, 0.7, 0.28), "glows": true, "glow_color": Color(0.3, 1.0, 0.25),
		"strength_in": 0.6, "strength_out": 0.95, "stripes": 18.0, "stripe_amount": 0.55, "wave": 0.025},
	"OysterTop": {"albedo": Color(0.6, 0.56, 0.7), "roughness": 0.55, "wave": 0.03},
	"GillOrange": {"albedo": Color(0.45, 0.28, 0.14), "glows": true, "glow_color": Color(1.0, 0.55, 0.15),
		"strength_in": 2.2, "strength_out": 0.35, "stripes": 70.0, "stripe_amount": 0.6, "wave": 0.03},
	"InkCap": {"albedo": Color(0.16, 0.12, 0.2), "roughness": 0.45},
	"InkRim": {"albedo": Color(0.2, 0.1, 0.3), "glows": true, "glow_color": Color(0.65, 0.3, 1.0),
		"strength_in": 1.6, "strength_out": 1.6, "pulse": 0.5},
	"StemPale": {"albedo": Color(0.7, 0.68, 0.66)},
	"Coral": {"albedo": Color(0.24, 0.13, 0.32), "roughness": 0.6},
	"CoralTip": {"albedo": Color(0.3, 0.8, 0.9), "glows": true, "glow_color": Color(0.3, 0.95, 1.0),
		"strength_in": 2.0, "strength_out": 2.0, "pulse": 0.6, "pulse_speed": 0.9},
	"FernLeaf": {"albedo": Color(0.14, 0.3, 0.27), "roughness": 0.7},
	"ShrubLeaf": {"albedo": Color(0.24, 0.17, 0.33), "roughness": 0.65},
	"BulbGlow": {"albedo": Color(0.8, 0.3, 0.6), "glows": true, "glow_color": Color(1.0, 0.35, 0.75),
		"strength_in": 2.0, "strength_out": 2.0, "pulse": 0.6, "pulse_speed": 0.8},
	"Rock": {"albedo": Color(1, 1, 1), "roughness": 0.9, "rim_strength": 0.15},
	"Bark": {"albedo": Color(1, 1, 1), "roughness": 0.9, "rim_strength": 0.2},
	"Birch": {"albedo": Color(0.62, 0.6, 0.66), "roughness": 0.8, "rim_strength": 0.2},
	"HammerCap": {"albedo": Color(0.55, 0.16, 0.11), "roughness": 0.55},
	"HammerStem": {"albedo": Color(0.82, 0.74, 0.64)},
	"Puff": {"albedo": Color(1.0, 0.95, 0.85), "roughness": 0.85, "rim_strength": 0.3},
	"PuffVent": {"albedo": Color(0.6, 0.7, 0.3), "glows": true, "glow_color": Color(0.85, 1.0, 0.4),
		"strength_in": 1.5, "strength_out": 1.5, "pulse": 0.4, "pulse_speed": 1.2},
	"Tooth": {"albedo": Color(1, 1, 1), "roughness": 0.5},
	"BossEye": {"albedo": Color(0.8, 1.0, 0.3), "glows": true, "glow_color": Color(0.85, 1.0, 0.25),
		"strength_in": 4.0, "strength_out": 4.0, "pulse": 0.2, "pulse_speed": 3.0},
	"Throat": {"albedo": Color(0.5, 0.7, 0.2), "glows": true, "glow_color": Color(0.7, 1.0, 0.2),
		"strength_in": 2.0, "strength_out": 2.0, "pulse": 0.5, "pulse_speed": 1.6},
	"KinSkin": {"albedo": Color(1.5, 1.5, 1.5), "roughness": 0.55, "rim_strength": 0.5},
	"KinEyeWhite": {"albedo": Color(0.95, 0.95, 0.9), "roughness": 0.3},
	"KinCheek": {"albedo": Color(0.9, 0.45, 0.45), "roughness": 0.6},
	"Eye": {"albedo": Color(0.03, 0.03, 0.04), "roughness": 0.2},
	"Reed": {"albedo": Color(0.6, 0.58, 0.34), "roughness": 0.85},
	"Wood": {"albedo": Color(0.4, 0.28, 0.2), "roughness": 0.85},
	"Lantern": {"albedo": Color(1.0, 0.75, 0.4), "glows": true, "glow_color": Color(1.0, 0.7, 0.3),
		"strength_in": 2.2, "strength_out": 2.2, "pulse": 0.15, "pulse_speed": 2.0},
	"KinCapOrange": {"albedo": Color(0.8, 0.38, 0.14), "roughness": 0.6},
	"KinCapTeal": {"albedo": Color(0.14, 0.5, 0.5), "roughness": 0.6},
	"CaveGlow": {"albedo": Color(0.2, 0.4, 0.9), "glows": true, "glow_color": Color(0.25, 0.55, 1.0),
		"strength_in": 1.6, "strength_out": 1.6, "pulse": 0.4},
	"Metal": {"albedo": Color(0.6, 0.62, 0.66), "roughness": 0.35},
	"Glass": {"albedo": Color(0.65, 0.82, 0.9), "roughness": 0.1},
	"Liquid": {"albedo": Color(0.2, 0.5, 0.9), "glows": true, "glow_color": Color(0.2, 0.55, 1.0),
		"strength_in": 0.8, "strength_out": 0.8, "pulse": 0.3},
	"TickShell": {"albedo": Color(0.24, 0.14, 0.17), "roughness": 0.35},
	"SporeSac": {"albedo": Color(0.5, 0.25, 0.6), "glows": true, "glow_color": Color(0.75, 0.35, 1.0),
		"strength_in": 1.6, "strength_out": 1.6, "pulse": 0.5, "pulse_speed": 1.4},
	"EyeGlow": {"albedo": Color(1, 0.9, 0.6), "glows": true, "glow_color": Color(1.0, 0.85, 0.5),
		"strength_in": 2.0, "strength_out": 2.0, "pulse": 0.0},
	"ShelfTop": {"albedo": Color(0.62, 0.36, 0.18), "roughness": 0.7},
	"ShelfGlow": {"albedo": Color(0.5, 0.3, 0.1), "glows": true, "glow_color": Color(1.0, 0.58, 0.12),
		"strength_in": 1.3, "strength_out": 0.6, "stripes": 40.0, "stripe_amount": 0.5, "pulse": 0.25},
	"BatSkin": {"albedo": Color(0.24, 0.15, 0.3), "roughness": 0.6},
	"BatMembrane": {"albedo": Color(0.36, 0.18, 0.44), "roughness": 0.5},
	"BatGlow": {"albedo": Color(0.2, 0.6, 0.7), "glows": true, "glow_color": Color(0.25, 0.9, 1.0),
		"strength_in": 1.0, "strength_out": 1.0, "pulse": 0.0},
	"Thread": {"albedo": Color(0.75, 0.75, 0.72), "roughness": 0.8},
	"ThreadGlow": {"albedo": Color(0.5, 0.8, 0.85), "glows": true, "glow_color": Color(0.4, 0.95, 1.0),
		"strength_in": 1.2, "strength_out": 1.2, "pulse": 0.6, "pulse_speed": 1.5},
	"RotCap": {"albedo": Color(0.42, 0.34, 0.18), "roughness": 0.7},
	"RotGlow": {"albedo": Color(0.4, 0.6, 0.2), "glows": true, "glow_color": Color(0.6, 1.0, 0.25),
		"strength_in": 1.4, "strength_out": 1.4, "pulse": 0.5, "pulse_speed": 1.1},
	"HammerGlow": {"albedo": Color(0.4, 0.2, 0.08), "glows": true, "glow_color": Color(1.0, 0.55, 0.12),
		"strength_in": 1.0, "strength_out": 0.5, "stripes": 50.0, "stripe_amount": 0.5, "pulse": 0.0},
}

## Ruch całego modelu (dopisywany do każdego materiału tego modelu).
const MOTION := {
	"fern_a": {"sway": 0.18, "size_ref": 1.6},
	"fern_b": {"sway": 0.25, "size_ref": 2.4},
	"shrub": {"sway": 0.12, "size_ref": 1.6},
	"coral": {"sway": 0.05, "size_ref": 1.8},
	"inkcap_a": {"sway": 0.06, "size_ref": 1.4},
	"inkcap_b": {"sway": 0.08, "size_ref": 2.2},
	"ghost_ground": {"sway": 0.04, "size_ref": 0.6},
	"ghost_wall_a": {"sway": 0.04, "size_ref": 0.8, "grow_axis": Vector3(0, 0, 1)},
	"ghost_wall_b": {"sway": 0.06, "size_ref": 1.4, "grow_axis": Vector3(0, 0, 1)},
	"ruffle": {"sway": 0.03, "size_ref": 1.0, "grow_axis": Vector3(0, 0, 1)},
	"oyster": {"sway": 0.03, "size_ref": 1.0, "grow_axis": Vector3(0, 0, 1)},
}

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


## Siatka modelu z podmienionymi materiałami (z pamięci podręcznej) i transformacja z pliku.
static func mesh(prop: String) -> Array:
	if _meshes.has(prop):
		return _meshes[prop]
	var scene := load(PATH % prop) as PackedScene
	var root := scene.instantiate()
	var mi := _find_mesh(root)
	var result := [null, Transform3D.IDENTITY]
	if mi:
		var m := mi.mesh.duplicate() as Mesh
		for i in m.get_surface_count():
			var src := m.surface_get_material(i)
			if src:
				m.surface_set_material(i, material(src.resource_name, prop))
		result = [m, _relative(root, mi)]
	root.free()
	_meshes[prop] = result
	return result


## Podmienia materiały we wszystkich siatkach węzła (np. Hammer Cap).
static func apply(node: Node, prop := "") -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src:
				mi.set_surface_override_material(i, material(src.resource_name, prop))
	for child in node.get_children():
		apply(child, prop)


static func material(blender_name: String, prop := "") -> ShaderMaterial:
	var key := blender_name + "|" + prop
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var params: Dictionary = MATERIALS.get(_base_name(blender_name), {})
	for k in params:
		m.set_shader_parameter(k, params[k])
	var motion: Dictionary = MOTION.get(prop, {})
	for k in motion:
		m.set_shader_parameter(k, motion[k])
	_materials[key] = m
	return m


## Blender dopisuje ".001" do powtórzonych nazw.
static func _base_name(n: String) -> String:
	var dot := n.find(".")
	return n if dot < 0 else n.substr(0, dot)


static func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found:
			return found
	return null


static func _relative(root: Node, node: Node3D) -> Transform3D:
	var t := node.transform
	var p := node.get_parent()
	while p and p != root:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
