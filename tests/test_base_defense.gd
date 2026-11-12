extends Node
## M3 (część 1): Uwaga planety, najazdy na bazę, obrona, warsztat, nawóz,
## płot i rytuał powrotu z raportem.
## Uruchom:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_base_defense.tscn

const TEST_SAVE := "user://test_base_defense_save.json"

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.save_path = TEST_SAVE
	_test_raid_rules()
	_test_attention()
	_test_workshop()
	await _test_farm_raid()
	await _test_return_ritual()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	GameState.save_path = GameState.SAVE_PATH
	if _failures == 0:
		print("TESTY OK")
	else:
		printerr("TESTY: %d błędów" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# --- Czysta logika najazdu ---------------------------------------------------

func _test_raid_rules() -> void:
	_check(Raid.pressure_gain(0) == 15 and Raid.pressure_gain(60) == 45, "Niepokój rośnie szybciej przy wysokiej Uwadze")
	_check(Raid.pest_count(0) == 3 and Raid.pest_count(100) == 8, "więcej szkodników przy wysokiej Uwadze")
	_check(Raid.cycles_until(Raid.START_PRESSURE, 0) == 3, "pierwszy najazd po 3 cyklach")
	_check(Raid.cycles_text(1) == "1 cykl" and Raid.cycles_text(3) == "3 cykle" and Raid.cycles_text(5) == "5 cykli", "odmiana: cykl / cykle / cykli")

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var crops := [_entry("voidberry", 0, 0, 2), _entry("voidberry", 1, 0, 2), _entry("voidberry", 0, 1, 2)]

	var open := Raid.resolve(crops, [], 0, rng)
	_check(_sum(open["damaged"]) == 3 and open["destroyed"].is_empty(), "bez obrony: 3 szkodniki = 3 etapy straty")
	_check(open["fertilizer"] == 0, "bez obrony: brak nawozu")

	var guarded := crops + [_entry("snapper", 0.5, 0.5, 2)]
	var with_snapper := Raid.resolve(guarded, [], 0, rng)
	_check(int(with_snapper["repelled"].get(&"snapper", 0)) == 2, "dojrzały Snapper łapie 2")
	_check(_sum(with_snapper["damaged"]) == 1 and with_snapper["fertilizer"] == 2, "trzeci przechodzi, 2× nawóz")

	var young := crops + [_entry("snapper", 0.5, 0.5, 1)]
	_check(Raid.resolve(young, [], 0, rng)["repelled"].is_empty(), "niedojrzały Snapper nie broni")

	var boom := crops + [_entry("boomshroom", 3.5, 0, 2)]
	var with_boom := Raid.resolve(boom, [], 0, rng)
	_check(int(with_boom["repelled"].get(&"boomshroom", 0)) == 3 and with_boom["damaged"].is_empty(), "Boomshroom (zasięg 4.5 m) odrzuca 3")

	var fence := [_post(0, -1), _post(1, -1), _post(-1, 1)]
	var with_fence := Raid.resolve(crops, fence, 0, rng)
	_check(int(with_fence["repelled"].get(&"fence", 0)) == 3, "3 słupki płotu zatrzymują po 1")

	var far_fence := [_post(20, 20)]
	_check(Raid.resolve(crops, far_fence, 0, rng)["repelled"].is_empty(), "płot poza zasięgiem nie pomaga")

	var sprouts := [_entry("voidberry", 0, 0, 0), _entry("voidberry", 2, 0, 0), _entry("voidberry", 4, 0, 0), _entry("voidberry", 6, 0, 0)]
	var big := Raid.resolve(sprouts, [], 100, rng)
	_check(big["destroyed"].size() == 2, "najazd niszczy najwyżej połowę upraw (%d)" % big["destroyed"].size())
	_check(big["idle"] == 6, "reszta odchodzi bez łupu")
	_check(String(big["name"]).begins_with("Wielki"), "Uwaga 50+ = wielki rój")

	var tools_only := [_entry("snapper", 0, 0, 2)]
	var nothing := Raid.resolve(tools_only, [], 0, rng)
	_check(nothing["idle"] == 3 and nothing["damaged"].is_empty(), "rośliny-narzędzia nie są celem")
	_check((nothing["lines"] as Array).size() >= 2, "raport ma opis")


# --- Uwaga planety -----------------------------------------------------------

func _test_attention() -> void:
	GameState.new_game()
	GameState.start_run({})
	GameState.run.add_item(&"sample_glowmoss", 1)
	GameState.run.add_item(&"crystal", 2)
	var rich := GameState.finish_run(true)
	_check(GameState.planet_attention == 12 and rich["attention"] == 12, "wywiezienie mchu i 2 kryształów: Uwaga +12")

	GameState.start_run({})
	GameState.run.add_item(&"seed_voidberry", 2)
	var modest := GameState.finish_run(true)
	_check(GameState.planet_attention == 7 and modest["attention"] == -5, "skromna wyprawa: Uwaga -5")

	GameState.start_run({})
	GameState.run.add_item(&"sample_glowmoss", 3)
	GameState.finish_run(false)
	_check(GameState.planet_attention == 2, "porażka: nic nie wywiezione, Uwaga -5")
	GameState.change_planet_attention(-50)
	_check(GameState.planet_attention == 0, "Uwaga nie spada poniżej 0")


# --- Warsztat ----------------------------------------------------------------

func _test_workshop() -> void:
	GameState.new_game()
	_check(GameState.get_resource(&"seed_boomshroom") == 1, "nowa gra: 1 nasiono Boomshrooma")
	var fence := Recipes.get_recipe(&"fence")
	_check(Recipes.problem(fence).begins_with("Brakuje"), "bez kryształów nie zrobisz płotu")
	GameState.add_resource(&"crystal", 10)
	GameState.add_resource(&"sample_glowmoss", 1)
	_check(Recipes.craft(&"fence") and GameState.get_resource(&"fence_post") == 3, "2 kryształy = 3 słupki")
	_check(GameState.get_resource(&"crystal") == 8, "koszt zużyty")

	_check(GameState.water_capacity() == 5, "konewka 5 przed ulepszeniem")
	_check(Recipes.craft(&"can_mk2") and GameState.water_capacity() == 8, "Duża konewka: 8 porcji")
	_check(not Recipes.craft(&"can_mk2") and Recipes.problem(Recipes.get_recipe(&"can_mk2")) == "Już masz", "ulepszenie tylko raz")

	_check(Recipes.craft(&"backpack_mk2"), "Większy plecak zrobiony")
	var run := GameState.start_run({})
	_check(run.capacity == 13 and run.add_item(&"crystal", 20) == 13, "plecak 13 miejsc po ulepszeniu")
	GameState.finish_run(false)

	GameState.raid_pressure = 42
	GameState.structures = [{"id": "fence", "x": 1.0, "y": 0.0, "z": 2.0}]
	GameState.save_game()
	GameState.reset()
	_check(GameState.load_game(), "wczytano zapis")
	_check(GameState.has_upgrade(&"can_mk2") and GameState.has_upgrade(&"backpack_mk2"), "zapis pamięta ulepszenia")
	_check(GameState.raid_pressure == 42 and GameState.structures.size() == 1, "zapis pamięta Niepokój i płot")


# --- Najazd na prawdziwej farmie ---------------------------------------------

func _test_farm_raid() -> void:
	GameState.new_game()
	var farm := Farm.new()
	add_child(farm)
	farm.rng.seed = 3
	var soil := StaticBody3D.new()
	soil.add_to_group("soil")
	add_child(soil)

	var voidberry := PlantCatalog.get_plant(&"voidberry")
	GameState.add_resource(&"seed_voidberry", 5)
	var crop := farm.plant_seed(voidberry, Vector3(0, 0, 0))
	var other := farm.plant_seed(voidberry, Vector3(6, 0, 0))
	crop.stage = 2
	other.stage = 2
	farm._sync()

	# Nawóz: natychmiast +1 cykl wzrostu, nawet bez wody.
	GameState.add_resource(&"fertilizer", 1)
	var seedling := farm.plant_seed(voidberry, Vector3(-6, 0, 0))
	_check(farm.fertilize(seedling) and seedling.stage == 1, "nawóz: +1 etap od razu")
	_check(not farm.fertilize(seedling), "bez nawozu nie da się nawozić")

	# Płot: stawianie i powody odmowy.
	GameState.add_resource(&"fence_post", 2)
	_check(farm.post_problem(Vector3(0.3, 0, 0), Vector3.UP, soil, Vector3.ZERO) == "Za blisko rośliny", "słupek nie wejdzie w roślinę")
	_check(farm.post_problem(Vector3(1.2, 0, 1.2), Vector3.UP, soil, Vector3.ZERO) == "", "słupek na gruncie obok rośliny")
	var post := farm.place_post(Vector3(1.2, 0, 1.2))
	_check(post != null and GameState.structures.size() == 1, "słupek postawiony i zapisany")
	_check(farm.post_problem(Vector3(1.5, 0, 1.2), Vector3.UP, soil, Vector3.ZERO) == "Za blisko innego słupka", "słupki nie na sobie")
	farm.place_post(Vector3(-1.2, 0, 1.2))
	_check(farm.get_node("Rails").get_child_count() == 2, "bliskie słupki łączą się poprzeczkami")
	farm.remove_post(post)
	_check(farm.post_count() == 1 and GameState.get_resource(&"fence_post") == 1, "E zabiera słupek do magazynu")

	# Najazd wywołany przez Niepokój w cyklu.
	var results: Array = []
	farm.raid_resolved.connect(func(r: Dictionary) -> void: results.append(r))
	GameState.raid_pressure = 90
	GameState.advance_cycle()
	await get_tree().process_frame
	_check(results.size() == 1, "Niepokój 100 = najazd w tym cyklu")
	_check(GameState.raid_pressure == 0, "po najeździe Niepokój od zera")
	var total_lost := 0
	for plant in farm.plants():
		if plant.bitten:
			total_lost += 1
	_check(total_lost > 0 or not results[0]["destroyed"].is_empty() or results[0]["fertilizer"] > 0, "najazd zostawił skutki na farmie")
	_check(farm.get_node("RaidMarks").get_child_count() > 0, "ślady najazdu widać w bazie")
	var fertilizer_before := GameState.get_resource(&"fertilizer")
	_check(fertilizer_before == int(results[0]["fertilizer"]), "nawóz z przegonionych trafia do magazynu")

	GameState.advance_cycle()
	await get_tree().process_frame
	_check(results.size() == 1, "kolejny cykl bez najazdu (Niepokój %d)" % GameState.raid_pressure)
	_check(farm.get_node("RaidMarks").get_child_count() == 0 or _all_queued(farm.get_node("RaidMarks")), "ślady znikają w następnym cyklu")
	farm.queue_free()
	soil.queue_free()
	await get_tree().process_frame


# --- Rytuał powrotu ----------------------------------------------------------

func _test_return_ritual() -> void:
	GameState.new_game()
	GameState.farm = [{"id": "voidberry", "x": 0.0, "y": 0.0, "z": -1.0, "stage": 2, "progress": 0, "watered": false}]
	GameState.raid_pressure = 95
	GameState.start_run({})
	GameState.run.add_item(&"sample_glowmoss", 1)
	GameState.finish_run(true)
	_check(GameState.pending_cycles == 1, "powrót: 1 cykl czeka")

	var base := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(base)
	await get_tree().process_frame
	var report := base.get("_report") as ReportPanel
	var landing := base.get_node("Valley/LandingCamera") as Camera3D
	_check(landing.current, "rytuał: kamera na lądowisku")
	_check(not report.visible, "raport czeka na wylądowanie")
	await get_tree().create_timer(3.6).timeout
	_check(report.visible, "po lądowaniu: panel raportu")
	var text := _panel_text(report)
	_check(text.contains("Najazd"), "raport ma sekcję najazdu")
	_check(text.contains("Uwaga planety +10"), "raport tłumaczy wzrost Uwagi")
	_check((base.get_node("Player") as Player).camera.current, "kamera wraca do gracza")
	report.close()
	await get_tree().process_frame
	_check(not (base.get("_hud") as Hud).modal, "zamknięcie raportu oddaje sterowanie")
	base.queue_free()
	await get_tree().process_frame


# --- Pomocnicze --------------------------------------------------------------

static func _entry(id: String, x: float, z: float, stage: int) -> Dictionary:
	return {"id": id, "x": x, "y": 0.0, "z": z, "stage": stage, "progress": 0, "watered": false}


static func _post(x: float, z: float) -> Dictionary:
	return {"id": "fence", "x": x, "y": 0.0, "z": z}


static func _sum(values: Dictionary) -> int:
	var total := 0
	for key in values:
		total += int(values[key])
	return total


static func _all_queued(node: Node) -> bool:
	for child in node.get_children():
		if not child.is_queued_for_deletion():
			return false
	return true


static func _panel_text(node: Node) -> String:
	var parts: Array[String] = []
	for child in node.find_children("*", "Label", true, false):
		parts.append((child as Label).text)
	return "\n".join(parts)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		printerr("  FAIL ", label)
