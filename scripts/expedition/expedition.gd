extends Node3D
## Wyprawa na Dziką łąkę.
## Losowe znajdźki, dzikie krzewy, ulepszenie i drapieżnik w legowisku.
## Przebudzenie rośnie z czasem i z chciwością (rzadkie znaleziska):
##   25: niepokój · 50: pogoda się zmienia, drapieżnik patroluje
##   75: burza gęstnieje · 100: planeta się broni, 90 s na ewakuację, burza zabiera Kondycję.
## Ewakuacja: E przy lądowisku i 5 s na nim. Porażka: Kondycja 0 albo koniec odliczania.

signal finished(report: Dictionary)

const AWAKENING_PER_SECOND := 0.35
const STORM_SECONDS := 90.0
const STORM_DAMAGE_PER_SECOND := 1.0
const EVAC_SECONDS := 5.0
const EVAC_RADIUS := 4.5
const PICKUP_COUNT := 11
## Poziom 2: więcej znajdziek, Przebudzenie od 10, Mgliste źródło i Mgielnik.
const LEVEL2_EXTRA_PICKUPS := 2
const LEVEL2_START_AWAKENING := 10.0
const SPRING_POSITION := Vector3(-27, 0, 0)
const MISTBLOOM_POSITION := Vector3(-24, 0, -7)
## Stadka małych stworzeń: [rodzaj, środek, liczba].
const CRITTERS := [
	[Critter.Kind.POLLENBUG, Vector3(-9, 0, 16), 1],
	[Critter.Kind.POLLENBUG, Vector3(-18, 0, -12), 1],
	[Critter.Kind.POLLENBUG, Vector3(20, 0, -4), 1],
	[Critter.Kind.CHRUPIK, Vector3(15, 0, 8), 3],
]

const LOOT := [
	{"item": &"seed_voidberry", "min": 1, "max": 2, "kind": "seed", "plant": &"voidberry", "weight": 3.0},
	{"item": &"seed_snapper", "min": 1, "max": 2, "kind": "seed", "plant": &"snapper", "weight": 2.0},
	{"item": &"seed_crystal_bloom", "min": 1, "max": 1, "kind": "seed", "plant": &"crystal_bloom", "weight": 1.5},
	{"item": &"seed_boomshroom", "min": 1, "max": 2, "kind": "seed", "plant": &"boomshroom", "weight": 1.5},
	{"item": &"crystal", "min": 1, "max": 2, "kind": "crystal", "weight": 3.0, "scan": &"crystal_vein", "scan_name": "Żyła kryształów", "color": Color(0.45, 0.95, 1.0)},
	{"item": &"sample_glowmoss", "min": 1, "max": 1, "kind": "sample", "rare": true, "weight": 1.2, "scan": &"glowmoss", "scan_name": "Lśniący mech", "color": Color(0.85, 1.0, 0.4)},
]

const BUFFS := [
	{"id": "speed", "name": "Turbo-buty", "desc": "+25% szybkości do końca wyprawy"},
	{"id": "vitality", "name": "Moduł witalności", "desc": "+25 maks. Kondycji do końca wyprawy"},
]

## Scena po zakończeniu. Puste = zostań (testy nasłuchują sygnału `finished`).
@export_file("*.tscn") var return_scene := "res://scenes/main.tscn"

var run: RunState

var _ending := false
var _evac_time := -1.0
var _storm_time := -1.0

@onready var _player: Player = $Player
@onready var _hud: ExpeditionHud = $HUD
@onready var _level: Node3D = $Level
@onready var _beacon: Node3D = $Level/EvacBeacon
@onready var _sun: DirectionalLight3D = $Sun

var _environment: Environment
## Mnożnik tempa Przebudzenia (danie z kuchni).
var _awakening_rate := 1.0


func _ready() -> void:
	# Kopia środowiska: pogoda zmienia je w trakcie wyprawy, a zasób sceny jest
	# współdzielony i następna wyprawa zaczynałaby się w burzy.
	var world_env := $WorldEnvironment as WorldEnvironment
	_environment = world_env.environment.duplicate(true)
	world_env.environment = _environment
	# Uruchomiona bezpośrednio z edytora (F6): wyprawa testowa bez wyposażenia.
	run = GameState.run if GameState.run else GameState.start_run({})
	_spawn_world()
	if run.level >= 2:
		_apply_level_2()
	_player.global_position = ($Level/PlayerSpawn as Node3D).global_position

	var interaction := _player.interaction as ExpeditionInteraction
	interaction.evac_requested.connect(_start_evac)
	_hud.bind(interaction)
	_hud.set_player(_player)
	_player.died.connect(func() -> void: _finish(false, "Kondycja spadła do zera."))
	run.threshold_reached.connect(_on_threshold)
	run.changed.connect(_hud.refresh)
	_hud.refresh()
	_apply_meal()
	if run.level >= 2:
		_hud.notify("Dzika łąka, poziom 2: gęsta mgła. Mgliste źródło bije na zachodzie.")
	_hud.notify("Dzika łąka. Zbieraj (E), skanuj (Q), uważaj na legowisko na północy.")
	_hud.notify("Gdy zechcesz wrócić: E przy lądowisku i 5 s na nim.")


func _process(delta: float) -> void:
	if _ending:
		return
	run.add_awakening(AWAKENING_PER_SECOND * _awakening_rate * delta)
	_hud.set_awakening(run.awakening)

	var alert := ""
	if _storm_time >= 0.0:
		_storm_time -= delta
		_player.take_damage(STORM_DAMAGE_PER_SECOND * delta, Vector3.INF, true)
		alert = "PLANETA SIĘ BRONI! Wracaj na lądowisko: %d s" % ceili(maxf(_storm_time, 0.0))
		if _storm_time <= 0.0:
			_finish(false, "Burza Przebudzenia: nie zdążyłeś na lądowisko.")
			return
	if _evac_time >= 0.0:
		var offset := _player.global_position - _beacon.global_position
		if Vector2(offset.x, offset.z).length() > EVAC_RADIUS:
			_evac_time = -1.0
			_hud.notify("Ewakuacja przerwana: wróć na lądowisko")
			Sfx.play(&"deny")
		else:
			_evac_time -= delta
			alert = "Ewakuacja za %.1f s · zostań na lądowisku" % maxf(_evac_time, 0.0)
			if _evac_time <= 0.0:
				_finish(true)
				return
	_hud.set_alert(alert)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _ending and GameState.run:
		GameState.finish_run(false, "Gra zamknięta w trakcie wyprawy.")
		GameState.save_game()


# --- Świat -------------------------------------------------------------------

func _spawn_world() -> void:
	var spots := $Level/PickupSpots.get_children()
	spots.shuffle()
	for i in mini(PICKUP_COUNT, spots.size()):
		var pickup := Pickup.new()
		pickup.setup(_roll_loot())
		pickup.position = (spots[i] as Node3D).position
		_level.add_child(pickup)

	var artifact_spots := $Level/ArtifactSpots.get_children()
	if not artifact_spots.is_empty():
		var buff: Dictionary = BUFFS.pick_random()
		var artifact := Pickup.new()
		artifact.setup({"kind": "artifact", "buff": buff, "color": Color(1.0, 0.8, 0.3)})
		artifact.position = (artifact_spots.pick_random() as Node3D).position
		_level.add_child(artifact)

	for spot in $Level/BushSpots.get_children():
		var bush := WildBush.new()
		bush.position = (spot as Node3D).position
		_level.add_child(bush)

	var den := $Level/DenSpot as Node3D
	var creature := Creature.new()
	creature.position = den.position
	creature.den_position = den.position
	_level.add_child(creature)

	for group: Array in CRITTERS:
		for i in int(group[2]):
			var critter := Critter.new()
			critter.kind = group[0]
			critter.home = group[1]
			critter.position = group[1] + Vector3(i * 1.2, 0.5, i * 0.7)
			_level.add_child(critter)


## Poziom 2: mgła, Mgliste źródło, nasiono Mgielnika i dodatkowe znajdźki.
func _apply_level_2() -> void:
	_environment.fog_density = 0.012
	_environment.fog_light_color = Color(0.7, 0.8, 0.95)
	var spring := MistySpring.new()
	spring.position = SPRING_POSITION
	_level.add_child(spring)
	var seed_pickup := Pickup.new()
	var mistbloom := PlantCatalog.get_plant(&"mistbloom")
	seed_pickup.setup({"kind": "seed", "item": mistbloom.seed_item(), "amount": 1, "scan": mistbloom.id,
		"scan_name": mistbloom.display_name, "color": mistbloom.accent_color})
	seed_pickup.position = MISTBLOOM_POSITION
	_level.add_child(seed_pickup)
	var spots := $Level/PickupSpots.get_children()
	spots.shuffle()
	for i in LEVEL2_EXTRA_PICKUPS:
		var pickup := Pickup.new()
		pickup.setup(_roll_loot())
		pickup.position = (spots[i] as Node3D).position + Vector3(2.5, 0, 1.5)
		_level.add_child(pickup)
	run.add_awakening(LEVEL2_START_AWAKENING)


## Danie z kuchni zjedzone przed wyjściem.
func _apply_meal() -> void:
	if run.meal == &"":
		return
	var meal := Meals.get_meal(run.meal)
	match meal.get("effect", ""):
		"vitality":
			_player.add_max_health(25.0)
		"speed":
			_player.speed_multiplier = maxf(_player.speed_multiplier, 1.2)
		"calm":
			_awakening_rate = Meals.awakening_rate(run.meal)
	if not run.buffs.has(meal["name"]):
		run.buffs.append(meal["name"])
	_hud.notify("Danie z kuchni: %s (%s)" % [meal["name"], meal["desc"]])


func _roll_loot() -> Dictionary:
	var total := 0.0
	for entry: Dictionary in LOOT:
		total += float(entry["weight"])
	var roll := randf() * total
	var chosen: Dictionary = LOOT[0]
	for entry: Dictionary in LOOT:
		roll -= float(entry["weight"])
		if roll <= 0.0:
			chosen = entry
			break
	var result := chosen.duplicate()
	result["amount"] = randi_range(int(chosen["min"]), int(chosen["max"]))
	if chosen["kind"] == "seed":
		var plant := PlantCatalog.get_plant(chosen["plant"])
		result["scan"] = plant.id
		result["scan_name"] = plant.display_name
		result["color"] = plant.accent_color
	return result


# --- Przebudzenie i pogoda ---------------------------------------------------

func _on_threshold(threshold: int) -> void:
	match threshold:
		25:
			_hud.notify("Przebudzenie 25: coś się poruszyło w trawie...")
		50:
			_hud.notify("Przebudzenie 50: pogoda się zmienia, drapieżnik wyszedł z legowiska!")
			Sfx.play(&"alarm")
			_weather(0.012, 0.8, Color(1.0, 0.85, 0.75), Color(0.75, 0.55, 0.7))
		75:
			_hud.notify("Przebudzenie 75: burza gęstnieje, drapieżnik węszy szerzej.")
			_weather(0.02, 0.6, Color(1.0, 0.7, 0.6), Color(0.6, 0.4, 0.55))
		100:
			_storm_time = STORM_SECONDS
			_hud.notify("PRZEBUDZENIE 100! Planeta się broni. Masz %d s na ewakuację." % int(STORM_SECONDS))
			Sfx.play(&"alarm")
			_weather(0.035, 0.45, Color(1.0, 0.4, 0.35), Color(0.55, 0.15, 0.2))


func _weather(fog: float, light: float, light_color: Color, fog_color: Color) -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(_environment, "fog_density", fog, 4.0)
	tween.tween_property(_environment, "fog_light_color", fog_color, 4.0)
	tween.tween_property(_sun, "light_energy", light, 4.0)
	tween.tween_property(_sun, "light_color", light_color, 4.0)
	var sky := _environment.sky.sky_material as ProceduralSkyMaterial
	if sky:
		tween.tween_property(sky, "sky_top_color", fog_color.darkened(0.4), 4.0)
		tween.tween_property(sky, "sky_horizon_color", fog_color, 4.0)


# --- Koniec wyprawy ----------------------------------------------------------

func _start_evac() -> void:
	if _ending or _evac_time >= 0.0:
		return
	_evac_time = EVAC_SECONDS
	Sfx.play(&"evac", _beacon.global_position)
	_hud.notify("Ewakuacja wezwana! Zostań na lądowisku.")


func _finish(success: bool, cause := "") -> void:
	if _ending:
		return
	_ending = true
	_player.input_enabled = false
	_hud.set_alert("")
	var text := "Ewakuacja udana!\nWracasz do bazy." if success else "Kapsuła ratunkowa zabiera cię nieprzytomnego...\n" + cause
	await _hud.fade_out(text)
	var report := GameState.finish_run(success, cause)
	GameState.save_game()
	finished.emit(report)
	if return_scene != "":
		await get_tree().create_timer(1.4).timeout
		get_tree().change_scene_to_file(return_scene)
