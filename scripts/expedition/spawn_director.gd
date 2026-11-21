class_name SpawnDirector
extends Node
## Reżyser przeciwników Grzybowego Lasu (jak w Risk of Rain 2): zbiera punkty z czasem
## (szybciej przy wyższym Przebudzeniu, x2 w burzy) i kupuje za nie grupy stworzeń, które
## wyrastają z kokonów z grzybni 25–45 m od gracza, zawsze POZA kamerą (poza stożkiem widzenia
## albo zasłonięte terenem). Naraz najwyżej MAX_ALIVE stworzeń; zostawione daleko wracają do grzybni
## (znikają, połowa punktów wraca). Bezpieczne strefy (wioska, oczyszczona Polana) i pierwsze
## sekundy po lądowaniu są wolne od spawnu. Zabicie stworzenia: +2 Przebudzenia.

signal spawned(creatures: Array)

const CREDIT_RATE := 0.6
const MAX_ALIVE := 12
const MIN_DIST := 25.0
const MAX_DIST := 45.0
const DESPAWN_DIST := 90.0
const START_GRACE := 20.0
const KILL_AWAKENING := 2.0
## Grupy: rodzaj, koszt jednej sztuki, liczebność, waga losowania.
const PACKS := [
	{"kind": "sporebat", "cost": 4.0, "min": 3, "max": 5, "weight": 1.0},
	{"kind": "rotling", "cost": 6.0, "min": 2, "max": 4, "weight": 1.0},
	{"kind": "spore_tick", "cost": 5.0, "min": 1, "max": 3, "weight": 0.8},
	{"kind": "rot_thornback", "cost": 14.0, "min": 1, "max": 1, "weight": 0.5},
]

var credits := 0.0
var alive: Array[ForestCreature] = []
var enabled := true
## Bezpieczne strefy: Vector4(x, y, z, promień).
var safe_zones: Array[Vector4] = []
var elapsed := 0.0

var _level: Node3D
var _terrain: ForestTerrain
var _player: Player
var _run: RunState
var _tick := 0.0
var _cocoons := 0


func setup(level: Node3D, terrain: ForestTerrain, player: Player, run: RunState) -> void:
	_level = level
	_terrain = terrain
	_player = player
	_run = run


func add_safe_zone(center: Vector3, radius: float) -> void:
	safe_zones.append(Vector4(center.x, center.y, center.z, radius))


func rate() -> float:
	var awakening := _run.awakening if _run else 0.0
	var r := CREDIT_RATE * (1.0 + awakening / 50.0)
	if awakening >= 100.0:
		r *= 2.0
	return r


func _process(delta: float) -> void:
	if not enabled or _player == null:
		return
	elapsed += delta
	credits += rate() * delta
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	_despawn_far()
	if elapsed < START_GRACE or alive.size() + _cocoons >= MAX_ALIVE:
		return
	var pack := _pick_pack()
	if pack.is_empty():
		return
	var room := MAX_ALIVE - alive.size() - _cocoons
	var count := mini(mini(int(pack["max"]), int(credits / float(pack["cost"]))), room)
	if count < int(pack["min"]) and count < room:
		return
	var at := find_spawn_point()
	if at == Vector3.INF:
		return
	credits -= count * float(pack["cost"])
	spawn_pack(String(pack["kind"]), count, at)


## Losuje grupę, na którą stać reżysera (co najmniej minimalna liczebność).
func _pick_pack() -> Dictionary:
	var options: Array = []
	var total := 0.0
	for p: Dictionary in PACKS:
		if credits >= float(p["cost"]) * int(p["min"]):
			options.append(p)
			total += float(p["weight"])
	if options.is_empty():
		return {}
	var roll := randf() * total
	for p: Dictionary in options:
		roll -= float(p["weight"])
		if roll <= 0.0:
			return p
	return options[-1]


## Punkt 25–45 m od gracza, na terenie do chodzenia, poza kamerą i poza strefami bezpiecznymi.
## Vector3.INF, jeśli nie znalazł.
func find_spawn_point() -> Vector3:
	var origin := _player.global_position
	var lim := _terrain.half_size - 10.0
	for attempt in 30:
		var a := randf() * TAU
		var d := randf_range(MIN_DIST, MAX_DIST)
		var x := origin.x + cos(a) * d
		var z := origin.z + sin(a) * d
		if absf(x) > lim or absf(z) > lim:
			continue
		if _terrain.slope_at(x, z) > 0.45 or _terrain.in_pit(x, z, 2.0):
			continue
		var p := _terrain.surface_point(x, z)
		if in_safe_zone(p) or is_visible(p):
			continue
		return p
	return Vector3.INF


func in_safe_zone(p: Vector3) -> bool:
	for zone in safe_zones:
		if Vector2(p.x - zone.x, p.z - zone.z).length() < zone.w:
			return true
	return false


## Czy gracz widzi ten punkt: w stożku kamery i nie zasłonięty terenem.
func is_visible(p: Vector3) -> bool:
	var cam := _player.camera
	if cam == null:
		return false
	var target := p + Vector3(0, 1.0, 0)
	if not cam.is_position_in_frustum(target):
		return false
	var from := cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, target, 1, [_player.get_rid()])
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return (hit["position"] as Vector3).distance_to(target) < 1.0


## Kokon w punkcie `at`; po pęknięciu wychodzi `count` stworzeń rodzaju `kind`.
func spawn_pack(kind: String, count: int, at: Vector3) -> SporeCocoon:
	var cocoon := SporeCocoon.new()
	_level.add_child(cocoon)
	cocoon.global_position = at
	_cocoons += count
	cocoon.hatched.connect(func(c: SporeCocoon) -> void: _hatch(c, kind, count))
	return cocoon


func _hatch(cocoon: SporeCocoon, kind: String, count: int) -> void:
	_cocoons = maxi(0, _cocoons - count)
	var made: Array = []
	var cost := 4.0
	for p: Dictionary in PACKS:
		if p["kind"] == kind:
			cost = float(p["cost"])
	for i in count:
		var creature := make_creature(kind)
		creature.ground_height = _terrain.mesh_height_at
		creature.director_cost = cost
		var a := TAU * i / maxf(count, 1)
		var off := Vector3(cos(a), 0, sin(a)) * 1.2
		var p := cocoon.global_position + off
		p.y = _terrain.mesh_height_at(p.x, p.z) + (1.5 if kind == "sporebat" else 0.3)
		_level.add_child(creature)
		creature.global_position = p
		creature.killed.connect(_on_killed)
		alive.append(creature)
		made.append(creature)
	spawned.emit(made)


static func make_creature(kind: String) -> ForestCreature:
	match kind:
		"sporebat":
			return Sporebat.new()
		"spore_tick":
			return SporeTick.new()
		"rot_thornback":
			return RotThornback.new()
	return Rotling.new()


func _on_killed(creature: ForestCreature) -> void:
	alive.erase(creature)
	if _run:
		_run.add_awakening(KILL_AWAKENING)


## Stworzenia zostawione daleko wracają do grzybni (połowa punktów wraca do puli).
func _despawn_far() -> void:
	var origin := _player.global_position
	for c in alive.duplicate():
		if not is_instance_valid(c):
			alive.erase(c)
			continue
		if c.global_position.distance_to(origin) > DESPAWN_DIST:
			credits += c.director_cost * 0.5
			alive.erase(c)
			c.queue_free()
