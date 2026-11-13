class_name TreeGenerator
extends RefCounted
## Generator pokrzywionych drzew: każde drzewo z innego ziarna wygląda inaczej.
## Pień i gałęzie to rurki wzdłuż krzywych łamanych z losowym zgięciem,
## na końcach gałęzi kępy liści (albo zwisające pnącza, płaskie korony, świecące kulki).

const SPECIES := {
	# Gruby, mocno skręcony pień, kilka długich krzywych gałęzi w bok, małe kępy liści.
	&"gnarled": {
		"height": [3.8, 5.4], "radius": [0.3, 0.42], "segments": 12, "bend": 0.5, "up": 0.35, "droop": 0.0,
		"branches": [4, 6], "depth": 2, "child_len": 0.62, "spread": 1.1, "branch_from": 0.3, "twigs": [2, 3],
		"bark": Color(0.32, 0.2, 0.26), "leaf": Color(0.12, 0.55, 0.47), "foliage": "clump", "clump": [0.55, 0.9],
	},
	# Wygięty pień, gałęzie łukiem w górę i w dół, zwisające pnącza z różowymi liśćmi.
	&"willow": {
		"height": [4.2, 5.8], "radius": [0.24, 0.32], "segments": 11, "bend": 0.28, "up": 0.5, "droop": 0.9,
		"branches": [5, 7], "depth": 2, "child_len": 0.7, "spread": 1.3, "branch_from": 0.5,
		"bark": Color(0.42, 0.3, 0.36), "leaf": Color(0.78, 0.35, 0.62), "foliage": "strands", "clump": [0.3, 0.45],
	},
	# Pochylony pień zygzakiem, płaskie korony jak parasole (pomarańczowe liście).
	&"umbrella": {
		"height": [4.0, 5.4], "radius": [0.22, 0.3], "segments": 10, "bend": 0.6, "up": 0.25, "droop": 0.0,
		"branches": [3, 5], "depth": 2, "child_len": 0.55, "spread": 0.9, "branch_from": 0.45, "twigs": [2, 3],
		"bark": Color(0.36, 0.24, 0.18), "leaf": Color(0.95, 0.5, 0.2), "foliage": "disc", "clump": [0.7, 1.1],
	},
	# Nagie, rozwidlone, ciemne drzewo; na końcach gałązek małe świecące kulki (nocą widać tylko je).
	&"spooky": {
		"height": [3.4, 4.8], "radius": [0.22, 0.32], "segments": 11, "bend": 0.6, "up": 0.3, "droop": 0.15,
		"branches": [4, 5], "depth": 3, "child_len": 0.6, "spread": 1.2, "branch_from": 0.25, "twigs": [3, 5],
		"bark": Color(0.16, 0.12, 0.16), "leaf": Color(0.45, 1.0, 0.85), "foliage": "glow", "clump": [0.06, 0.1],
	},
}
## Liczba boków rurki zależy od grubości: pień 8, gałęzie 6, gałązki 4.
static func _sides_for(radius: float) -> int:
	return 8 if radius > 0.12 else (6 if radius > 0.045 else 4)

var _rng := RandomNumberGenerator.new()
var _cfg: Dictionary
var _bark: Buffer
var _leaves: Buffer
var _glow: Buffer
var _leaf_color: Color

## Szablony kul liści (ośmiościan podzielony 0, 1, 2 razy): wierzchołki trójkątów
## i numer unikalnego wierzchołka (żeby poszarpanie nie rozrywało ścian). Liczone raz.
static var _blob_templates: Dictionary = {}


## Geometria w tablicach (szybsze niż SurfaceTool przy setkach tysięcy wierzchołków).
class Buffer:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()


## Wersja generatora: zmiana kształtu drzew = podbić, żeby stara pamięć podręczna nie wróciła.
const VERSION := 3
const CACHE_DIR := "user://tree_cache"

## Materiały współdzielone między drzewami (mniej wywołań rysowania).
static var _materials: Dictionary = {}


## Buduje drzewo gatunku `species` z ziarna `seed`. Zwraca Node3D z siatkami.
static func build(species: StringName, seed: int) -> Node3D:
	var gen := TreeGenerator.new()
	return gen._build(species, seed)


## Jak build(), ale z pamięcią podręczną na dysku: to samo ziarno = to samo drzewo,
## więc po pierwszym uruchomieniu siatki są tylko wczytywane.
static func build_cached(species: StringName, seed: int) -> Node3D:
	var path := "%s/%s_%d_v%d.res" % [CACHE_DIR, species, seed, VERSION]
	if FileAccess.file_exists(path):
		var meshes := ResourceLoader.load(path) as Resource
		if meshes is TreeMeshes:
			return (meshes as TreeMeshes).instantiate()
	var tree := build(species, seed)
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	ResourceSaver.save(TreeMeshes.from_tree(tree), path)
	return tree


func _build(species: StringName, seed: int) -> Node3D:
	_cfg = SPECIES.get(species, SPECIES[&"gnarled"])
	_rng.seed = seed
	_bark = Buffer.new()
	_leaves = Buffer.new()
	_glow = Buffer.new()
	var base: Color = _cfg["leaf"]
	_leaf_color = Color.from_hsv(fposmod(base.h + _rng.randf_range(-0.04, 0.04), 1.0), base.s, base.v * _rng.randf_range(0.85, 1.1))
	var height := _rng.randf_range(_cfg["height"][0], _cfg["height"][1])
	var radius := _rng.randf_range(_cfg["radius"][0], _cfg["radius"][1])
	var lean := Vector3(_rng.randf_range(-0.35, 0.35), 1.0, _rng.randf_range(-0.35, 0.35)).normalized()
	_roots(radius)
	_branch(Vector3.ZERO, lean, height, radius, 0)

	var root := Node3D.new()
	root.name = "Tree"
	_add_mesh(root, _bark, shared_material(_cfg["bark"], 0.0), "Bark")
	_add_mesh(root, _leaves, shared_material(Color.WHITE, 0.0), "Leaves")
	_add_mesh(root, _glow, shared_material(Color(_cfg["leaf"]), 2.5), "Glow")
	return root


func _branch(start: Vector3, direction: Vector3, length: float, radius: float, depth: int) -> void:
	var segments: int = maxi(4, int(_cfg["segments"]) - depth * 2)
	var points: Array[Vector3] = [start]
	var radii: Array[float] = [radius]
	var dirs: Array[Vector3] = [direction]
	var d := direction
	var p := start
	var bend: float = _cfg["bend"]
	for i in segments:
		var t := float(i + 1) / segments
		var wobble := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.4, 0.6), _rng.randf_range(-1, 1)) * bend
		d = (d + wobble * 0.6 + Vector3.UP * float(_cfg["up"]) * 0.3 + Vector3.DOWN * float(_cfg["droop"]) * t * 0.6).normalized()
		p += d * length / segments
		points.append(p)
		radii.append(maxf(radius * (1.0 - t * 0.75), 0.025))
		dirs.append(d)
	_tube(points, radii)

	if depth < int(_cfg["depth"]):
		var count := _rng.randi_range(_cfg["branches"][0], _cfg["branches"][1]) - depth
		for k in maxi(count, 1):
			var at := clampi(int(lerpf(float(_cfg["branch_from"]), 1.0, _rng.randf()) * segments), 1, segments)
			var side := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
			var child_dir := (dirs[at] * 0.5 + side * float(_cfg["spread"]) + Vector3.UP * 0.3).normalized()
			_branch(points[at], child_dir, length * float(_cfg["child_len"]), radii[at] * 0.7, depth + 1)
	elif _cfg.has("twigs"):
		# Najcieńsze gałązki: krótkie odrosty z końcówki, każdy z własną kępą liści.
		for k in _rng.randi_range(_cfg["twigs"][0], _cfg["twigs"][1]):
			var at := clampi(int(_rng.randf_range(0.5, 1.0) * segments), 1, segments)
			var side := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.2, 0.6), _rng.randf_range(-1, 1)).normalized()
			_twig(points[at], (dirs[at] + side * 1.2).normalized(), length * _rng.randf_range(0.25, 0.4), radii[at] * 0.6, depth + 1)
	_foliage(p, d, depth)


func _twig(start: Vector3, direction: Vector3, length: float, radius: float, depth: int) -> void:
	var points: Array[Vector3] = [start]
	var radii: Array[float] = [maxf(radius, 0.02)]
	var d := direction
	var p := start
	for i in 3:
		d = (d + Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.2, 0.4), _rng.randf_range(-0.5, 0.5))).normalized()
		p += d * length / 3.0
		points.append(p)
		radii.append(maxf(radius * (1.0 - (i + 1) / 3.5), 0.012))
	_tube(points, radii)
	_foliage(p, d, depth)


func _foliage(tip: Vector3, direction: Vector3, depth: int) -> void:
	var size := _rng.randf_range(_cfg["clump"][0], _cfg["clump"][1])
	match String(_cfg["foliage"]):
		"clump":
			if depth >= 2:
				# Kępa z kilku mniejszych kul w różnych odcieniach.
				_blob(_leaves, tip, Vector3(size, size * 0.8, size) * 0.7, _shade(_leaf_color, 0.0), 2)
				for k in _rng.randi_range(2, 3):
					var off := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.4, 0.8), _rng.randf_range(-1, 1)) * size * 0.55
					var sz := size * _rng.randf_range(0.4, 0.6)
					_blob(_leaves, tip + off, Vector3(sz, sz * 0.8, sz), _shade(_leaf_color, off.y), 1)
		"strands":
			if depth >= 1:
				for k in 2:
					var off := Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.05, 0.15), _rng.randf_range(-0.25, 0.25))
					_blob(_leaves, tip + off, Vector3(size, size * 0.65, size) * _rng.randf_range(0.7, 1.0), _shade(_leaf_color, off.y), 1)
				for s in _rng.randi_range(5, 8):
					var off := Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))
					var top := tip + off
					var drop := _rng.randf_range(1.4, 3.0)
					var sway := Vector3(_rng.randf_range(-0.15, 0.15), 0, _rng.randf_range(-0.15, 0.15))
					var strand: Array[Vector3] = [top, top + sway + Vector3(0, -drop * 0.5, 0), top + sway * 2.2 + Vector3(0, -drop, 0)]
					var widths: Array[float] = [0.025, 0.018, 0.008]
					_tube(strand, widths, _leaves, _leaf_color.darkened(0.1))
					# Drobne listki wzdłuż pnącza.
					if s % 2 == 0:
						for l in 2:
							var at := strand[0].lerp(strand[2], 0.4 + l * 0.3)
							_blob(_leaves, at, Vector3(0.08, 0.06, 0.08), _leaf_color.lightened(0.08), 0)
		"disc":
			if depth >= 1:
				# Płaska korona z kilku spłaszczonych kępek, jaśniejsza u góry.
				_blob(_leaves, tip, Vector3(size, size * 0.24, size), _leaf_color.darkened(0.05))
				for k in _rng.randi_range(4, 6):
					var a := _rng.randf() * TAU
					var off := Vector3(cos(a), 0, sin(a)) * size * _rng.randf_range(0.2, 0.6) + Vector3(0, _rng.randf_range(0.08, 0.2), 0)
					var sz := size * _rng.randf_range(0.35, 0.55)
					_blob(_leaves, tip + off, Vector3(sz, sz * 0.3, sz), _shade(_leaf_color, off.y + 0.2), 1)
		"glow":
			if depth >= 2 and _rng.randf() < 0.75:
				_blob(_glow, tip, Vector3.ONE * size, Color.WHITE, 1)


func _roots(radius: float) -> void:
	for i in _rng.randi_range(3, 4):
		var a := TAU * i / 4.0 + _rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(a), 0, sin(a))
		var pts: Array[Vector3] = [out * radius * 0.4 + Vector3(0, 0.45, 0), out * radius * 1.6 + Vector3(0, 0.12, 0), out * radius * 2.6 + Vector3(0, -0.05, 0)]
		var rr: Array[float] = [radius * 0.55, radius * 0.35, radius * 0.12]
		_tube(pts, rr)


# --- Geometria -----------------------------------------------------------------

func _tube(points: Array[Vector3], radii: Array[float], tool: Buffer = null, color := Color.WHITE) -> void:
	var bark := tool == null
	if bark:
		tool = _bark
		color = Color.WHITE
	var sides := _sides_for(radii[0])
	var rings: Array = []
	var shades: Array[Color] = []
	var normal := Vector3.RIGHT
	for i in points.size():
		var tangent: Vector3
		if i == 0:
			tangent = (points[1] - points[0]).normalized()
		elif i == points.size() - 1:
			tangent = (points[i] - points[i - 1]).normalized()
		else:
			tangent = (points[i + 1] - points[i - 1]).normalized()
		# Transport równoległy: pierścienie nie skręcają się między segmentami.
		normal = (normal - tangent * normal.dot(tangent))
		if normal.length_squared() < 0.0001:
			normal = tangent.cross(Vector3.FORWARD)
		normal = normal.normalized()
		var binormal := tangent.cross(normal)
		var ring: Array[Vector3] = []
		for s in sides:
			var a := TAU * s / sides
			# Lekko nierówna kora: promień drga o kilka procent.
			var bump := 1.0 + (_rng.randf_range(-0.08, 0.08) if bark else 0.0)
			ring.append(points[i] + (normal * cos(a) + binormal * sin(a)) * radii[i] * bump)
		rings.append(ring)
		shades.append(color.darkened(_rng.randf_range(0.0, 0.15)) if bark else color)
	for i in rings.size() - 1:
		var r0: Array[Vector3] = rings[i]
		var r1: Array[Vector3] = rings[i + 1]
		for s in sides:
			var n := (s + 1) % sides
			_tri(tool, r0[s], r1[s], r1[n], shades[i], points[i])
			_tri(tool, r0[s], r1[n], r0[n], shades[i], points[i])
	# Zamknięcie końca (czubek gałęzi).
	var last: Array[Vector3] = rings[rings.size() - 1]
	var tip := points[points.size() - 1]
	for s in sides:
		_tri(tool, last[s], tip, last[(s + 1) % sides], color, points[points.size() - 2])


## Kępa liści: ośmiościan podzielony `detail` razy (2 = 128 trójkątów),
## z poszarpanymi wierzchołkami.
func _blob(tool: Buffer, center: Vector3, size: Vector3, color: Color, detail := 2) -> void:
	var template: Array = _blob_template(detail)
	var corners: PackedVector3Array = template[0]
	var ids: PackedInt32Array = template[1]
	var unique: int = template[2]
	var jitter := 0.16 if detail > 0 else 0.0
	var scale := PackedFloat32Array()
	scale.resize(unique)
	for i in unique:
		scale[i] = 1.0 + _rng.randf_range(-jitter, jitter)
	var dark := color.darkened(0.12)
	for t in range(0, corners.size(), 3):
		var a := center + corners[t] * scale[ids[t]] * size
		var b := center + corners[t + 1] * scale[ids[t + 1]] * size
		var c := center + corners[t + 2] * scale[ids[t + 2]] * size
		_tri(tool, a, b, c, dark if a.y < center.y else color, center)


static func _blob_template(detail: int) -> Array:
	if _blob_templates.has(detail):
		return _blob_templates[detail]
	var verts := [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	var faces := [[0, 4, 3], [0, 3, 5], [0, 5, 2], [0, 2, 4], [1, 3, 4], [1, 5, 3], [1, 2, 5], [1, 4, 2]]
	var tris: Array = []
	for f: Array in faces:
		tris.append([verts[f[0]], verts[f[1]], verts[f[2]]])
	for level in detail:
		var finer: Array = []
		for t: Array in tris:
			var a: Vector3 = t[0]
			var b: Vector3 = t[1]
			var c: Vector3 = t[2]
			var ab := (a + b).normalized()
			var bc := (b + c).normalized()
			var ca := (c + a).normalized()
			finer.append_array([[a, ab, ca], [ab, b, bc], [ca, bc, c], [ab, bc, ca]])
		tris = finer
	var corners := PackedVector3Array()
	var ids := PackedInt32Array()
	var index := {}
	for t: Array in tris:
		for v: Vector3 in t:
			var key := v.snapped(Vector3.ONE * 0.001)
			if not index.has(key):
				index[key] = index.size()
			corners.append(v)
			ids.append(index[key])
	var template := [corners, ids, index.size()]
	_blob_templates[detail] = template
	return template


## Trójkąt z normalną skierowaną od punktu `inside` (oś gałęzi, środek kępy).
## Ściany niezależne = płaskie cieniowanie (low poly).
## Liście u góry kępy jaśniejsze, u dołu ciemniejsze, z drobnym losowym odchyleniem.
func _shade(base: Color, height: float) -> Color:
	var c := base.lightened(clampf(height, 0.0, 0.5) * 0.25) if height > 0.0 else base.darkened(clampf(-height, 0.0, 0.5) * 0.3)
	return Color.from_hsv(fposmod(c.h + _rng.randf_range(-0.015, 0.015), 1.0), c.s, c.v * _rng.randf_range(0.92, 1.05))


func _tri(tool: Buffer, a: Vector3, b: Vector3, c: Vector3, color: Color, inside: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		n = -n
		var tmp := b
		b = c
		c = tmp
	tool.verts.append(a)
	tool.verts.append(c)
	tool.verts.append(b)
	for k in 3:
		tool.normals.append(n)
		tool.colors.append(color)


func _add_mesh(parent: Node3D, tool: Buffer, mat: Material, mesh_name: String) -> void:
	if tool.verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = tool.verts
	arrays[Mesh.ARRAY_NORMAL] = tool.normals
	arrays[Mesh.ARRAY_COLOR] = tool.colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = mesh
	instance.material_override = mat
	parent.add_child(instance)


static func shared_material(color: Color, glow: float) -> StandardMaterial3D:
	var key := "%s_%.2f" % [color.to_html(), glow]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	_materials[key] = mat
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = glow == 0.0
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat
