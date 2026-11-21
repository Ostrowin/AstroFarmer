class_name ForestDetails
extends Node3D
## Drobne (i duże) detale Grzybowego Lasu, które nic nie znaczą dla rozgrywki, ale robią klimat:
##   na ziemi: paprocie (w kępach), krzewy z bulwami, czernidłaki, grzyby koralowe, głazy z mchem,
##             zwalone kłody, martwe pnie z boczniakami, kępy świecących wachlarzy,
##   na ścianach (kanion, doły, uskoki): świecące wachlarze, kędzierzawe rozety, boczniaki,
##   na trzonach olbrzymów: piętra boczniaków i wachlarzy, czasem ogromne.
## Rysowane przez MultiMesh w kawałkach mapy (znikają za mgłą). Kłody, pnie i duże głazy mają kolizję.
## Ruch (kołysanie, falowanie, pulsowanie) robi shader (ForestProps).

@export var terrain_path: NodePath
@export var mushrooms_path: NodePath
## Bok kawałka mapy (m) i odległość, od której kawałek znika.
@export var chunk_size := 48.0
@export var view_distance := 110.0

## Rozsiew na ziemi: [model, kępy, sztuk w kępie (min, max), promień kępy, skala (min, max), max nachylenie, w kanionie?]
const GROUND := [
	["fern_a", 140, Vector2i(2, 6), 4.0, Vector2(0.6, 1.4), 0.45, true],
	["fern_b", 70, Vector2i(1, 4), 5.0, Vector2(0.7, 1.6), 0.4, false],
	["shrub", 110, Vector2i(1, 3), 3.0, Vector2(0.7, 1.5), 0.45, true],
	["inkcap_a", 90, Vector2i(1, 3), 3.0, Vector2(0.6, 1.8), 0.5, true],
	["inkcap_b", 45, Vector2i(1, 2), 3.0, Vector2(0.8, 2.6), 0.45, false],
	["coral", 70, Vector2i(1, 3), 2.5, Vector2(0.6, 1.5), 0.5, true],
	["ghost_ground", 80, Vector2i(1, 3), 2.0, Vector2(0.7, 1.8), 0.5, true],
	["rock_a", 90, Vector2i(1, 3), 4.0, Vector2(0.5, 1.6), 0.6, true],
	["rock_b", 45, Vector2i(1, 2), 5.0, Vector2(0.6, 1.8), 0.5, true],
	["log", 26, Vector2i(1, 1), 0.0, Vector2(0.8, 1.4), 0.25, false],
	["snag", 22, Vector2i(1, 1), 0.0, Vector2(0.8, 1.5), 0.3, false],
]
## Na ścianach: [model, próby, skala (min, max)]
const WALL := [
	["ghost_wall_a", 900, Vector2(0.7, 1.6)],
	["ghost_wall_b", 500, Vector2(0.7, 1.8)],
	["ruffle", 500, Vector2(0.6, 1.5)],
	["oyster", 600, Vector2(0.7, 1.6)],
]
## Modele z kolizją: model -> [promień, wysokość] (kształt walca) albo "log".
const SOLID := {"snag": [0.7, 8.0], "rock_b": [1.6, 2.0], "rock_a": [1.0, 1.2]}

var placed: Dictionary = {}  # model -> liczba sztuk (do testów)

var _terrain: ForestTerrain
var _mushrooms: ForestMushrooms
var _chunks: Dictionary = {}  # model -> {Vector2i: Array[Transform3D]}


func _ready() -> void:
	_terrain = get_node(terrain_path) as ForestTerrain
	_mushrooms = get_node_or_null(mushrooms_path) as ForestMushrooms
	var rng := RandomNumberGenerator.new()
	rng.seed = _terrain.rng.randi()
	_scatter_ground(rng)
	_scatter_walls(rng)
	_scatter_canyon_walls(rng)
	_scatter_pit_walls(rng)
	_scatter_stems(rng)
	_build()


func _add(prop: String, t: Transform3D) -> void:
	if not _chunks.has(prop):
		_chunks[prop] = {}
	var key := Vector2i(floori(t.origin.x / chunk_size), floori(t.origin.z / chunk_size))
	var by_chunk: Dictionary = _chunks[prop]
	if not by_chunk.has(key):
		by_chunk[key] = []
	(by_chunk[key] as Array).append(t)
	placed[prop] = int(placed.get(prop, 0)) + 1


# --- Rozmieszczenie ----------------------------------------------------------

func _scatter_ground(rng: RandomNumberGenerator) -> void:
	for row: Array in GROUND:
		var prop: String = row[0]
		var per: Vector2i = row[2]
		var spread: float = row[3]
		var scale_range: Vector2 = row[4]
		var max_slope: float = row[5]
		var canyon_ok: bool = row[6]
		for c in int(row[1]):
			var center := _terrain.random_point(rng, 8.0, not canyon_ok, true)
			for i in rng.randi_range(per.x, per.y):
				var a := rng.randf_range(0, TAU)
				var d := spread * sqrt(rng.randf())
				var x := center.x + cos(a) * d
				var z := center.z + sin(a) * d
				if _terrain.slope_at(x, z) > max_slope or _near_pad(x, z):
					continue
				if not canyon_ok and _terrain.in_canyon(x, z):
					continue
				var s := rng.randf_range(scale_range.x, scale_range.y)
				var p := _terrain.surface_point(x, z)
				var sink := 0.05 + _terrain.slope_at(x, z) * (1.5 if prop in ["log", "snag", "rock_b"] else 0.6)
				var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * s)
				_add(prop, Transform3D(basis, p - Vector3(0, sink, 0)))
				if SOLID.has(prop) or prop == "log":
					_add_collision(prop, p, basis, s)


func _scatter_walls(rng: RandomNumberGenerator) -> void:
	var h := _terrain.half_size - 10.0
	for row: Array in WALL:
		var prop: String = row[0]
		var scale_range: Vector2 = row[2]
		for i in int(row[1]):
			var x := rng.randf_range(-h, h)
			var z := rng.randf_range(-h, h)
			if _terrain.slope_at(x, z) < 0.55 or _near_pad(x, z):
				continue
			var out := _terrain.downhill(x, z)
			var p := _terrain.surface_point(x, z) + out * 0.15
			var s := rng.randf_range(scale_range.x, scale_range.y)
			var yaw := Basis(Vector3.UP, rng.randf_range(-0.35, 0.35))
			var basis := (yaw * Basis(Vector3.UP.cross(out).normalized(), Vector3.UP, out)).scaled(Vector3.ONE * s)
			_add(prop, Transform3D(basis, p))


const WALL_MIX := ["ghost_wall_a", "ghost_wall_a", "ghost_wall_b", "ruffle", "oyster", "oyster"]


## Ściany kanionu: kępy na obu ścianach na różnych wysokościach (od dna po krawędź).
func _scatter_canyon_walls(rng: RandomNumberGenerator) -> void:
	for i in 260:
		var t := rng.randf_range(0.12, 0.88)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var mount := _terrain.canyon_wall_mount(t, side, rng.randf_range(0.6, _terrain.canyon_depth * 0.8))
		var prop: String = WALL_MIX[rng.randi() % WALL_MIX.size()]
		_add_wall(prop, mount, rng, Vector2(0.7, 2.0))


## Ściany dołów: kępy dookoła, nad dnem.
func _scatter_pit_walls(rng: RandomNumberGenerator) -> void:
	for pit: Vector4 in _terrain.pits:
		for i in 10:
			var a := rng.randf_range(0, TAU)
			for r in range(10):
				var d := pit.z * (0.55 + r * 0.06)
				var x := pit.x + cos(a) * d
				var z := pit.y + sin(a) * d
				if _terrain.slope_at(x, z) > 0.55:
					var out := _terrain.downhill(x, z)
					var basis := Basis(Vector3.UP.cross(out).normalized(), Vector3.UP, out)
					var prop: String = WALL_MIX[rng.randi() % WALL_MIX.size()]
					_add_wall(prop, Transform3D(basis, _terrain.surface_point(x, z) + out * 0.15), rng, Vector2(0.6, 1.4))
					break


func _add_wall(prop: String, mount: Transform3D, rng: RandomNumberGenerator, scale_range: Vector2) -> void:
	var s := rng.randf_range(scale_range.x, scale_range.y)
	var basis := (Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)) * mount.basis.orthonormalized()).scaled(Vector3.ONE * s)
	_add(prop, Transform3D(basis, mount.origin))


## Boczniaki i wachlarze na trzonach olbrzymów, czasem ogromne.
func _scatter_stems(rng: RandomNumberGenerator) -> void:
	if _mushrooms == null:
		return
	for g: Dictionary in _mushrooms.giants:
		for k in rng.randi_range(0, 3):
			var prop := "oyster" if rng.randf() < 0.6 else ("ghost_wall_b" if rng.randf() < 0.5 else "ruffle")
			var height: float = g["height"]
			var hh := rng.randf_range(1.2, minf(16.0, height * 0.55))
			var up := Basis.from_euler(g["tilt"])
			var ratio := lerpf(1.0, 0.62, hh / height)
			var a := rng.randf_range(0, TAU)
			var out := up * Vector3(cos(a), 0, sin(a))
			out.y = 0.0
			out = out.normalized()
			var base: Vector3 = g["base"]
			var p: Vector3 = base + up.y * hh + out * float(g["stem"]) * ratio * 0.95
			var s := rng.randf_range(1.0, 2.6)
			var basis := Basis(Vector3.UP.cross(out).normalized(), Vector3.UP, out).scaled(Vector3.ONE * s)
			_add(prop, Transform3D(basis, p))


func _near_pad(x: float, z: float) -> bool:
	return Vector2(x, z).distance_to(_terrain.pad_center) < _terrain.pad_radius + 4.0


func _add_collision(prop: String, at: Vector3, basis: Basis, s: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	if prop == "log":
		var box := BoxShape3D.new()
		box.size = Vector3(7.0, 1.3, 1.3) * s
		collision.shape = box
		collision.position = Vector3(0, 0.6 * s, 0)
		body.transform = Transform3D(basis.orthonormalized(), at)
	else:
		var dims: Array = SOLID[prop]
		var cyl := CylinderShape3D.new()
		cyl.radius = float(dims[0]) * s
		cyl.height = float(dims[1]) * s
		collision.shape = cyl
		collision.position = Vector3(0, cyl.height * 0.5, 0)
		body.position = at
	body.add_child(collision)
	add_child(body)


# --- Budowa ------------------------------------------------------------------

func _build() -> void:
	for prop: String in _chunks:
		var info := ForestProps.mesh(prop)
		var mesh := info[0] as Mesh
		if mesh == null:
			continue
		var local: Transform3D = info[1]
		var by_chunk: Dictionary = _chunks[prop]
		for key: Vector2i in by_chunk:
			var list: Array = by_chunk[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, (list[i] as Transform3D) * local)
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%d_%d" % [prop, key.x, key.y]
			mmi.multimesh = mm
			mmi.visibility_range_end = view_distance
			mmi.visibility_range_end_margin = 10.0
			if prop.begins_with("fern") or prop in ["shrub", "coral", "ghost_ground", "ghost_wall_a", "ghost_wall_b", "ruffle", "oyster"]:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
