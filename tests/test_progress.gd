extends Node
## M3 (część 2): baza danych, kuchnia ekspedycyjna, mutacje, Mgielnik,
## Pyłkowiec i Chrupik, poziom 2 łąki.
## Uruchom:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_progress.tscn

const TEST_SAVE := "user://test_progress_save.json"
const EXPEDITION := preload("res://scenes/levels/expedition_meadow.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.save_path = TEST_SAVE
	_test_codex()
	_test_meals()
	await _test_mutations_and_mistbloom()
	await _test_expedition_life()
	await _test_level_2()
	await _test_codex_panel()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	GameState.save_path = GameState.SAVE_PATH
	if _failures == 0:
		print("TESTY OK")
	else:
		printerr("TESTY: %d błędów" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# --- Baza danych -------------------------------------------------------------

func _test_codex() -> void:
	GameState.new_game()
	_check(Codex.completion(GameState.research) == 0, "nowa gra: baza danych 0%")
	var unlocked: Array = []
	GameState.level_unlocked.connect(func(_b: StringName, level: int) -> void: unlocked.append(level))

	_check(GameState.learn(&"voidberry", "scan") != "", "skan odkrywa pierwszy fakt")
	_check(GameState.learn(&"voidberry", "scan") == "", "ten sam fakt drugi raz nic nie daje")
	_check(GameState.learn(&"voidberry", "nonsense") == "", "akcja bez faktu nic nie daje")
	GameState.learn(&"voidberry", "harvest")
	_check(Codex.known_count(GameState.research, &"voidberry") == 2, "Voidberry: 2/3 fakty")
	_check(GameState.has_discovery(&"voidberry"), "fakt = odkrycie wpisu")

	for id in [&"snapper", &"boomshroom", &"crystal_bloom", &"thornback"]:
		GameState.learn(id, "scan")
	_check(GameState.max_level() == 1 and unlocked.is_empty(), "5 wpisów: poziom 2 jeszcze zamknięty")
	GameState.learn(&"chrupik", "raid")
	_check(GameState.max_level() == 2 and unlocked == [2], "6 wpisów odblokowuje poziom 2 łąki")
	_check(Codex.completion(GameState.research, 1) > 0, "kompletność rośnie")

	GameState.add_resource(&"crystal", 2)
	Recipes.craft(&"fence")
	_check(GameState.knows(&"crystal_vein", "craft"), "warsztat odkrywa fakt o kryształach")

	GameState.save_game()
	GameState.reset()
	GameState.load_game()
	_check(GameState.knows(&"voidberry", "harvest") and GameState.max_level() == 2, "zapis pamięta bazę danych i poziom 2")

	# Stary zapis: same odkrycia ze skanera, bez bazy danych.
	GameState.from_dict({"discoveries": ["thornback", "glowmoss"]})
	_check(GameState.knows(&"thornback", "scan") and GameState.knows(&"glowmoss", "scan"), "stare odkrycia trafiają do bazy danych")


# --- Kuchnia ------------------------------------------------------------------

func _test_meals() -> void:
	GameState.new_game()
	_check(not Meals.can_cook(Meals.get_meal(&"salad"), GameState.resources), "bez owoców nie ma sałatki")
	GameState.add_resource(&"voidberry", 4)
	var run := GameState.start_run({&"voidberry": 1}, {"meal": &"salad"})
	_check(run.meal == &"salad" and GameState.get_resource(&"voidberry") == 0, "sałatka: 3 owoce zużyte, 1 w plecaku")
	GameState.finish_run(true)
	var second := GameState.start_run({}, {"meal": &"salad"})
	_check(second.meal == &"", "za mało owoców = wyprawa bez dania")
	GameState.finish_run(true)
	var locked := GameState.start_run({}, {"level": 2})
	_check(locked.level == 1, "zamknięty poziom 2 = wyprawa na poziom 1")
	GameState.finish_run(true)
	_check(is_equal_approx(Meals.awakening_rate(&"tea"), 0.75) and is_equal_approx(Meals.awakening_rate(&"brew"), 0.5), "herbatka i napar spowalniają Przebudzenie")


# --- Mutacje i Mgielnik ------------------------------------------------------

func _test_mutations_and_mistbloom() -> void:
	GameState.new_game()
	GameState.raid_pressure = -100000
	var farm := Farm.new()
	add_child(farm)
	var voidberry := PlantCatalog.get_plant(&"voidberry")
	GameState.add_resource(&"seed_voidberry", 4)

	var golden := farm.plant_seed(voidberry, Vector3(0, 0, 0))
	golden.stage = voidberry.last_stage()
	golden.mutation = &"golden"
	var plain := farm.plant_seed(voidberry, Vector3(3, 0, 0))
	plain.stage = voidberry.last_stage()
	farm._sync()
	_check(golden.display_name() == "Golden Voidberry", "mutacja w nazwie")
	_check(GameState.farm[0]["mutation"] == "golden", "mutacja zapisana")
	farm.load_from_state()
	await get_tree().process_frame
	var reloaded := farm.plants()[0]
	_check(reloaded.mutation == &"golden", "mutacja wczytana z zapisu")
	var gained := farm.harvest(reloaded)
	_check(int(gained.get(&"voidberry", 0)) >= voidberry.harvest_amount.x + 1, "Złota: +1 plonu (%d)" % gained.get(&"voidberry", 0))
	var giant := PlantVisuals.build(voidberry, 2, &"giant")
	_check(giant.get_child_count() == 1 and (giant.get_child(0) as Node3D).scale.x > 1.3, "Olbrzymia jest większa")
	giant.free()

	# Mutacje losują się przy dojrzewaniu; nawóz zwiększa szansę.
	var mutated := 0
	for i in 60:
		var test_plant := Plant.new()
		test_plant.setup(voidberry, 1, 0, true)
		test_plant.fertilized = true
		add_child(test_plant)
		test_plant.advance_cycle()
		if test_plant.mutation != &"":
			mutated += 1
		test_plant.free()
	_check(mutated > 3 and mutated < 40, "dojrzewanie z nawozem czasem daje mutację (%d/60)" % mutated)

	# Mgielnik: kiełkuje tylko po wodzie z Mglistego źródła.
	var mistbloom := PlantCatalog.get_plant(&"mistbloom")
	GameState.add_resource(mistbloom.seed_item(), 1)
	var soil := StaticBody3D.new()
	soil.add_to_group("soil")
	add_child(soil)
	var mist := farm.plant_seed(mistbloom, Vector3(-3, 0, 0))
	_check(mist.needs_sprout_item(), "Mgielnik śpi w łupinie")
	var water_before := GameState.get_resource(&"water")
	_check(farm.water_plant(mist) == "Needs Misty Water", "zwykła woda go nie budzi")
	_check(GameState.get_resource(&"water") == water_before, "konewka nie traci wody na Mgielnika")
	GameState.add_resource(&"fertilizer", 1)
	_check(not farm.fertilize(mist), "nawóz nie budzi Mgielnika")
	GameState.add_resource(&"water_misty", 1)
	_check(farm.water_plant(mist) == "" and GameState.get_resource(&"water_misty") == 0, "woda z Mglistego źródła zużyta")
	_check(GameState.knows(&"misty_spring", "sprout"), "baza danych: fakt o budzeniu Mgielnika")
	GameState.advance_cycle()
	_check(mist.stage == 1 and not mist.needs_sprout_item(), "Mgielnik wykiełkował")
	_check(farm.water_plant(mist) == "", "dalej rośnie na zwykłej wodzie")
	GameState.advance_cycle()
	_check(mist.is_ripe() and GameState.knows(&"mistbloom", "grow"), "dojrzały Mgielnik + fakt w bazie danych")
	var fruit := farm.harvest(mist)
	_check(int(fruit.get(&"mist_fruit", 0)) >= 1, "Mgielny owoc zebrany")
	_check(Meals.can_cook(Meals.get_meal(&"brew"), GameState.resources), "z owocu można zrobić Mgielny napar")
	farm.queue_free()
	soil.queue_free()
	await get_tree().process_frame


# --- Pyłkowiec, Chrupik, danie na wyprawie -----------------------------------

func _test_expedition_life() -> void:
	GameState.new_game()
	GameState.add_resource(&"voidberry", 3)
	GameState.start_run({}, {"meal": &"salad"})
	var expedition := _spawn_expedition()
	await _frames(3)
	var level := expedition.get_node("Level")
	var critters := level.get_children().filter(func(n: Node) -> bool: return n is Critter)
	var bugs := critters.filter(func(c: Critter) -> bool: return c.kind == Critter.Kind.POLLENBUG)
	var chrupiki := critters.filter(func(c: Critter) -> bool: return c.kind == Critter.Kind.CHRUPIK)
	_check(bugs.size() == 3 and chrupiki.size() == 3, "na łące: 3 Pyłkowce i stadko 3 Chrupików")
	_check(level.get_children().filter(func(n: Node) -> bool: return n is MistySpring).is_empty(), "poziom 1: bez Mglistego źródła")
	var player := expedition.get_node("Player") as Player
	_check(is_equal_approx(player.max_health, 125.0), "Sałatka: +25 maks. Kondycji")

	var bug := bugs[0] as Critter
	var pickups_before := level.get_children().filter(func(n: Node) -> bool: return n is Pickup).size()
	bug.stun(2.0)
	await _frames(3)
	var pickups := level.get_children().filter(func(n: Node) -> bool: return n is Pickup)
	_check(pickups.size() == pickups_before + 1, "ogłuszony Pyłkowiec gubi pyłek")
	_check((pickups.back() as Pickup).item_id == &"pollen", "to kulka pyłku")
	bug.stun(2.0)
	await _frames(3)
	_check(level.get_children().filter(func(n: Node) -> bool: return n is Pickup).size() == pickups_before + 1, "pyłek tylko raz")

	# Chrupiki objadają krzewy, gdy łąka się budzi (Przebudzenie 25+).
	var bushes := level.get_children().filter(func(n: Node) -> bool: return n is WildBush)
	var eaten_before := bushes.filter(func(b: WildBush) -> bool: return b.eaten).size()
	GameState.run.add_awakening(30.0)
	await get_tree().create_timer(6.0).timeout
	var eaten_after := bushes.filter(func(b: WildBush) -> bool: return b.eaten).size()
	_check(eaten_after > eaten_before, "Chrupiki objadły dziki krzew (%d -> %d)" % [eaten_before, eaten_after])
	expedition.queue_free()
	await _frames(2)
	GameState.finish_run(false)

	GameState.add_resource(&"crystal", 1)
	GameState.add_resource(&"voidberry", 1)
	GameState.start_run({}, {"meal": &"tea"})
	var calm := _spawn_expedition()
	await _frames(3)
	_check(is_equal_approx(float(calm.get("_awakening_rate")), 0.75), "Herbatka: Przebudzenie o 25% wolniej")
	calm.queue_free()
	await _frames(2)
	GameState.finish_run(false)


func _test_level_2() -> void:
	GameState.new_game()
	GameState.unlock_biome_level(GameState.START_BIOME, 2)
	var run := GameState.start_run({}, {"level": 2})
	_check(run.level == 2, "poziom 2 wybrany")
	var expedition := _spawn_expedition()
	await _frames(3)
	var level := expedition.get_node("Level")
	var springs := level.get_children().filter(func(n: Node) -> bool: return n is MistySpring)
	_check(springs.size() == 1, "poziom 2: Mgliste źródło")
	var seeds := level.get_children().filter(func(n: Node) -> bool: return n is Pickup and (n as Pickup).item_id == &"seed_mistbloom")
	_check(seeds.size() >= 1, "poziom 2: nasiono Mgielnika")
	_check(run.awakening >= 10.0, "poziom 2: Przebudzenie od 10")
	_check(level.get_children().filter(func(n: Node) -> bool: return n is Pickup).size() >= 15, "poziom 2: więcej znajdziek")
	expedition.queue_free()
	await _frames(2)
	GameState.finish_run(false)


func _test_codex_panel() -> void:
	GameState.new_game()
	GameState.learn(&"voidberry", "scan")
	var panel := CodexPanel.new()
	add_child(panel)
	panel.open()
	await get_tree().process_frame
	var labels := panel.find_children("*", "Label", true, false)
	var text := "\n".join(labels.map(func(l: Label) -> String: return l.text))
	_check(text.contains("Voidberry") and text.contains("???"), "panel bazy danych: znane i nieznane wpisy")
	_check(text.contains("Meadow II"), "panel pokazuje postęp do poziomu 2")
	panel.queue_free()
	await get_tree().process_frame


# --- Pomocnicze --------------------------------------------------------------

func _spawn_expedition() -> Node:
	var expedition := EXPEDITION.instantiate()
	expedition.set("return_scene", "")
	add_child(expedition)
	return expedition


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		printerr("  FAIL ", label)
