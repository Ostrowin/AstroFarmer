extends "res://scripts/expedition/expedition.gd"
## Wyprawa do Grzybowego Lasu (wersja testowa).
## Teren losowany przy każdej wyprawie (ForestTerrain): pagórki, uskoki, doły, kanion.
## Grzyby z brył wg szkicu (ForestMushrooms), w kanionie Hammer Capy.
## Reszta zasad (Przebudzenie, burza, ewakuacja, plecak) jak na łące.

const FOREST_PICKUPS := 40
const FOREST_NIGHT_PICKUPS := 12
const FOREST_BUSHES := 10
const HAMMER_CAPS := 7
## Znajdźki w jaskiniach: zwykła jaskinia i Grota Zarodników (najlepsze, ale halucynacje bez maski).
const CAVE_LOOT := 3
const SPORE_HOLLOW_LOOT := 5

## Reżyser przeciwników (spawn poza polem widzenia gracza).
var director: SpawnDirector
## Halucynacje od zarodników (Grota Zarodników, Spore Ticki).
var hallucination: Hallucination

@onready var _terrain: ForestTerrain = $Level/Terrain


func _spawn_world() -> void:
	day_night.canopy = 1.0
	# Nierówny teren: przyklejanie do podłoża przy schodzeniu ze zboczy.
	_player.floor_snap_length = 0.6
	var pad := _terrain.pad_point()
	_beacon.global_position = pad
	($Level/PlayerSpawn as Node3D).global_position = pad + Vector3(0, 0.3, -1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = _terrain.rng.randi()

	for i in FOREST_PICKUPS:
		_add_pickup(_roll_loot(), _loot_point(rng))
	for i in FOREST_NIGHT_PICKUPS:
		_add_pickup(_roll_night_loot(), _loot_point(rng))

	# Jaskinie: znajdźki w głębi; w Grocie Zarodników rzadkie próbki i Odłamek gwiazdy.
	var caves := $Level/Caves as ForestCaves
	if caves:
		for ci in _terrain.caves.size():
			if caves.is_spore_hollow(ci):
				for entry in [Pickup.entry_for(&"sample_glowmoss", 1), Pickup.entry_for(&"sample_glowmoss", 1),
						Pickup.entry_for(&"starfall_shard", 1), _roll_loot(), _roll_loot()]:
					_add_pickup(entry, caves.inside_point(ci, rng))
			else:
				for k in CAVE_LOOT:
					_add_pickup(_roll_loot(), caves.inside_point(ci, rng))

	# Ulepszenie w środku kanionu, między Hammer Capami: ryzyko za nagrodę.
	var buff: Dictionary = BUFFS.pick_random()
	_add_pickup({"kind": "artifact", "buff": buff, "color": Color(1.0, 0.8, 0.3)}, _terrain.canyon_point(0.5, 0.0))

	for i in FOREST_BUSHES:
		var bush := WildBush.new()
		bush.position = _terrain.random_point(rng)
		_level.add_child(bush)

	# Hammer Capy wyrastają ze ścian kanionu (na przemian z lewej i prawej) i biją w jego dno.
	for i in HAMMER_CAPS:
		var hammer := HammerCap.new()
		var t := lerpf(0.22, 0.78, float(i) / (HAMMER_CAPS - 1))
		hammer.transform = _terrain.canyon_wall_mount(t, 1.0 if i % 2 == 0 else -1.0, rng.randf_range(2.6, 3.4))
		hammer.ground_height = _terrain.mesh_height_at
		hammer.phase = i * 0.55
		_level.add_child(hammer)

	director = SpawnDirector.new()
	director.name = "SpawnDirector"
	add_child(director)
	director.setup(_level, _terrain, _player, run)

	hallucination = Hallucination.new()
	hallucination.name = "Hallucination"
	hallucination.add_to_group("hallucination")
	add_child(hallucination)
	hallucination.setup(_player, _level, _hud)


## Znajdźki: większość w lesie, część na dnie dołów i w kanionie (trzeba tam zejść).
func _loot_point(rng: RandomNumberGenerator) -> Vector3:
	var roll := rng.randf()
	if roll < 0.15 and not _terrain.pits.is_empty():
		var pit: Vector4 = _terrain.pits.pick_random()
		var a := rng.randf_range(0, TAU)
		var d := rng.randf_range(0.0, pit.z * 0.35)
		return _terrain.surface_point(pit.x + cos(a) * d, pit.y + sin(a) * d)
	if roll < 0.3:
		return _terrain.canyon_point(rng.randf_range(0.1, 0.9), rng.randf_range(-3.5, 3.5))
	return _terrain.random_point(rng)


func _add_pickup(entry: Dictionary, at: Vector3) -> void:
	var pickup := Pickup.new()
	pickup.setup(entry)
	pickup.position = at
	_level.add_child(pickup)


## Las ma na razie jeden poziom.
func _apply_level_2() -> void:
	pass
