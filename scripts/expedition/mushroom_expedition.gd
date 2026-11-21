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
var trade_panel: TradePanel
## Słoneczna Polana i jej mini-boss.
var glade: ForestGlade
var shepherd: RotShepherd
## Arena i boss etapu.
var puffking: Puffking
var boss_defeated := false

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
	var village := $Level/Village as SporekinVillage
	if village and _terrain.village.z > 0.0:
		director.add_safe_zone(village.center(), village.radius() + 12.0)
	director.add_safe_zone(_terrain.pad_point(), 14.0)
	trade_panel = TradePanel.new()
	trade_panel.closed.connect(_on_trade_closed)
	trade_panel.traded.connect(func(id: StringName) -> void:
		var offer := Trades.get_offer(id)
		_hud.notify("Learned: " + String(offer["name"]) if offer.get("plan", false) else "+ " + String(offer["name"]))
		_hud.refresh())
	(_player.interaction as ExpeditionInteraction).trade_requested.connect(_open_trade)

	glade = $Level/Glade as ForestGlade
	if glade and _terrain.glade.z > 0.0:
		shepherd = glade.spawn_shepherd(_level, director)
		if shepherd:
			shepherd.killed.connect(_on_shepherd_killed)
			shepherd.phase_changed.connect(func(_p: int) -> void: _hud.notify("The Shepherd plants his staff"))
		glade.cleansed.connect(func() -> void: director.add_safe_zone(glade.center(), glade.radius() + 6.0))

	# The Puffking śpi na środku areny (droga: grubiejąca grzybnia).
	puffking = Puffking.new()
	puffking.arena_center = _terrain.arena_point()
	puffking.arena_radius = _terrain.arena.z
	puffking.ground_height = _terrain.mesh_height_at
	_level.add_child(puffking)
	puffking.global_position = _terrain.arena_point()
	puffking.phase_changed.connect(func(_p: int) -> void: _hud.notify("The Puffking bursts!"))
	puffking.defeated.connect(_on_puffking_defeated)

	hallucination = Hallucination.new()
	hallucination.name = "Hallucination"
	hallucination.add_to_group("hallucination")
	add_child(hallucination)
	hallucination.setup(_player, _level, _hud)
	if run.meal == &"stew":
		hallucination.resist = 0.5


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


func _ready() -> void:
	super._ready()
	_hud.add_child(trade_panel)


func _process(delta: float) -> void:
	super._process(delta)
	if _terrain.village.z > 0.0 and _terrain.in_village(_player.global_position.x, _player.global_position.z):
		GameState.learn(&"sporekin", "visit")
	var boss_fight := puffking != null and is_instance_valid(puffking) and puffking.awake() and not puffking.dead
	# W trakcie walki z bossem reżyser nie dosyła stworzeń (walka ma być czytelna).
	if director:
		director.boss_pause = boss_fight
	if boss_fight:
		_hud.show_boss("The Puffking", puffking.fight_fraction())
	elif shepherd and is_instance_valid(shepherd) and shepherd.awake() and not shepherd.dead:
		_hud.show_boss("Rot Shepherd", shepherd.health / shepherd.max_health)
	elif _hud.boss_visible():
		_hud.hide_boss()


## Boss pokonany: latarnia przylatuje na arenę (ewakuacja od razu), etap 2 odblokowany.
func _on_puffking_defeated() -> void:
	boss_defeated = true
	run.add_awakening(15.0)
	_hud.notify("The Puffking is defeated")
	_hud.notify("Forest II unlocked")
	var target := _terrain.surface_point(_terrain.arena.x + 6.0, _terrain.arena.y)
	var tw := create_tween()
	_beacon.global_position = target + Vector3(0, 40, 0)
	tw.tween_property(_beacon, "global_position", target, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _hud.notify("The beacon has landed"))


func _on_shepherd_killed(_c: ForestCreature) -> void:
	run.add_awakening(10.0)
	_hud.notify("The glade is free")
	_hud.notify("Lantern Moth joins you")
	if get_tree().get_first_node_in_group("lantern_moth") == null:
		add_companion()


func _open_trade() -> void:
	if _ending or trade_panel.visible:
		return
	_player.input_enabled = false
	_hud.modal = true
	trade_panel.open(run)


func _on_trade_closed() -> void:
	_hud.modal = false
	if not _ending:
		_player.input_enabled = true
		_player.capture_mouse()


## Las ma na razie jeden poziom.
func _apply_level_2() -> void:
	pass
