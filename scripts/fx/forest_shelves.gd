class_name ForestShelves
extends Node3D
## Shelfcapy: grzyby-półki na ścianach kanionu i dołów, ułożone w schody (co ok. 1,15 m w górę,
## na zmianę w lewo i w prawo), po których da się wyjść z kanionu w połowie drogi albo z dołu
## bez szukania rampy. Wygląd: art/models/forest/shelfcap.glb (spód świeci bursztynem).

@export var terrain_path: NodePath
@export var canyon_stairs := 6
@export var pit_stairs := 3
@export var shelf_scale := 1.8

const STEP := 1.15
const PROP := "shelfcap"

## Schody: każda to lista Transform3D półek (od dołu).
var stairs: Array = []

var _terrain: ForestTerrain
var _all: Array[Transform3D] = []


func _ready() -> void:
	_terrain = get_node(terrain_path) as ForestTerrain
	var rng := RandomNumberGenerator.new()
	rng.seed = _terrain.rng.randi()
	for k in canyon_stairs:
		_canyon_stair(rng)
	var pits := _terrain.pits.duplicate()
	for k in mini(pit_stairs, pits.size()):
		_pit_stair(k, rng)
	_build()


func _canyon_stair(rng: RandomNumberGenerator) -> void:
	var t := rng.randf_range(0.15, 0.85)
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var floor_p := _terrain.canyon_point(t)
	var rim_p := _terrain.canyon_point(t, side * (_terrain.canyon_floor_half + _terrain.canyon_wall + 3.0))
	var top := rim_p.y - floor_p.y - 0.4
	var list: Array[Transform3D] = []
	var h := 1.1
	var k := 0
	while h < top and k < 16:
		var dt := (0.9 if k % 2 == 0 else -0.9) / maxf(_terrain.canyon_length(), 1.0)
		var m := _terrain.canyon_wall_mount(t + dt, side, h, floor_p.y)
		# Ściana tu się kończy (punkt nie leży na zboczu): koniec schodów.
		if absf(_terrain.mesh_height_at(m.origin.x, m.origin.z) - m.origin.y) > 0.6 or _too_far(list, m):
			break
		list.append(m)
		h += STEP
		k += 1
	_add_stair(list)


func _pit_stair(i: int, rng: RandomNumberGenerator) -> void:
	var pit: Vector4 = _terrain.pits[i]
	var centre := Vector2(pit.x, pit.y)
	var bottom := _terrain.mesh_height_at(pit.x, pit.y)
	var rim := _terrain.mesh_height_at(pit.x + pit.z * 1.6, pit.y)
	var a := _terrain.pit_ramps[i] + PI + rng.randf_range(-0.4, 0.4)
	var list: Array[Transform3D] = []
	var h := 1.1
	while h < rim - bottom - 0.3 and list.size() < 10:
		var m := _terrain.wall_mount_along(centre, Vector2(cos(a), sin(a)), bottom, h, pit.z * 2.0)
		if absf(_terrain.mesh_height_at(m.origin.x, m.origin.z) - m.origin.y) > 0.6 or _too_far(list, m):
			break
		list.append(m)
		h += STEP
		a += 0.25
	_add_stair(list)


## Następna półka za daleko w bok od poprzedniej (zbocze łagodnieje u góry): koniec schodów.
static func _too_far(list: Array[Transform3D], m: Transform3D) -> bool:
	if list.is_empty():
		return false
	var prev: Vector3 = list[-1].origin
	return Vector2(m.origin.x - prev.x, m.origin.z - prev.z).length() > 3.0


func _add_stair(list: Array[Transform3D]) -> void:
	if list.is_empty():
		return
	stairs.append(list)
	for t in list:
		var mount := Transform3D(t.basis.scaled(Vector3.ONE * shelf_scale), t.origin - t.basis.z * 0.25)
		_all.append(mount)
		_collision(t)


func _collision(t: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var box := BoxShape3D.new()
	var s := shelf_scale
	box.size = Vector3(1.6 * s, 0.3 * s, 0.9 * s)
	var cs := CollisionShape3D.new()
	cs.shape = box
	cs.position = Vector3(0, -0.13 * s, 0.42 * s)
	body.add_child(cs)
	body.transform = t
	add_child(body)


func _build() -> void:
	if _all.is_empty():
		return
	var info := ForestProps.mesh(PROP)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = info[0]
	mm.instance_count = _all.size()
	for i in _all.size():
		mm.set_instance_transform(i, _all[i] * (info[1] as Transform3D))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Shelves"
	mmi.multimesh = mm
	add_child(mmi)
