extends Node
## Siatka, sterowanie jak w RoR2 (bieg, dash), pistolet z obrażeniami,
## zdrowie i śmierć stworzeń, druga ręka (PPM) i plecak.
## Uruchom:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_controls.tscn

const TEST_SAVE := "user://test_controls_save.json"
const EXPEDITION := preload("res://scenes/levels/expedition_meadow.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.save_path = TEST_SAVE
	await _test_grid()
	await _test_plant_models()
	_test_migrations()
	_test_clock()
	await _test_expedition()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	GameState.save_path = GameState.SAVE_PATH
	if _failures == 0:
		print("TESTY OK")
	else:
		printerr("TESTY: %d błędów" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# --- Siatka ------------------------------------------------------------------

func _test_grid() -> void:
	_check(Farm.cell_of(Vector3(0.2, 0, 0.9)) == Vector2i(0, 0) and Farm.cell_of(Vector3(-0.1, 0, 1.1)) == Vector2i(-1, 1), "punkt -> pole siatki")
	_check(Farm.snap(Vector3(2.7, 0.1, -0.4)) == Vector3(2.5, 0.1, -0.5), "przyciąganie do środka pola")

	GameState.new_game()
	GameState.raid_pressure = -100000
	# Stary zapis sprzed siatki: dwie rośliny w tym samym polu.
	GameState.farm = [
		{"id": "voidberry", "x": 0.3, "y": 0.0, "z": 0.3, "stage": 1, "progress": 0, "watered": false},
		{"id": "voidberry", "x": 0.6, "y": 0.0, "z": 0.4, "stage": 1, "progress": 0, "watered": false},
	]
	var farm := Farm.new()
	add_child(farm)
	farm.load_from_state()
	await get_tree().process_frame
	var cells := farm.plants().map(func(p: Plant) -> Vector2i: return Farm.cell_of(p.global_position))
	_check(cells.size() == 2 and cells[0] != cells[1], "stary zapis: rośliny rozsunięte na osobne pola")
	_check(farm.plants()[0].global_position == Vector3(0.5, 0, 0.5), "stary zapis: roślina na środku pola")
	farm.queue_free()
	await get_tree().process_frame


func _test_plant_models() -> void:
	for id in PlantVisuals.MODELS:
		var data := PlantCatalog.get_plant(id)
		var stages_ok := true
		for stage in data.stages:
			var model := PlantVisuals.build(data, stage)
			stages_ok = stages_ok and model.get_node_or_null("Stage") != null and model.get_child_count() == 1
			model.free()
		_check(stages_ok, "%s: model z Blendera dla każdego etapu" % id)
	var snapper := PlantVisuals.build(PlantCatalog.get_plant(&"snapper"), 2)
	var jaw := snapper.find_child("JawTop", true, false) as Node3D
	_check(jaw != null and is_equal_approx(jaw.rotation.x, PlantVisuals.JAW_OPEN), "Snapper: paszcza otwarta")
	snapper.free()
	var bloom_data := PlantCatalog.get_plant(&"crystal_bloom")
	var golden := PlantVisuals.build(bloom_data, 2, &"golden")
	var meshes := golden.find_children("*", "MeshInstance3D", true, false)
	_check(not meshes.is_empty() and (meshes[0] as MeshInstance3D).get_surface_override_material(0) != null, "mutacja złota przemalowuje materiały")
	golden.free()
	var plant := Plant.new()
	plant.setup(bloom_data, 2)
	add_child(plant)
	await get_tree().process_frame
	var tracker := Outline.Tracker.new()
	tracker.set_target(plant)
	var outlined := plant.find_children("*", "MeshInstance3D", true, false).filter(func(m: MeshInstance3D) -> bool: return m.material_overlay != null)
	var soil_clean := plant.find_children("*", "MeshInstance3D", true, false).filter(func(m: MeshInstance3D) -> bool: return m.has_meta("no_outline") and m.material_overlay != null).is_empty()
	_check(not outlined.is_empty() and soil_clean, "obwódka na roślinie (bez krążka gleby)")
	tracker.set_target(null)
	_check(plant.find_children("*", "MeshInstance3D", true, false).all(func(m: MeshInstance3D) -> bool: return m.material_overlay == null), "obwódka znika")
	_check(not plant.get("_glow").is_empty(), "kryształy Crystal Blooma pulsują")
	_check(plant.get("_stage_node") != null, "roślina kołysze się na wietrze")
	plant.queue_free()
	await get_tree().process_frame


func _test_migrations() -> void:
	GameState.from_dict({"upgrades": ["stunner_mk2"], "research": {"thornback": ["scan", "stun"]}})
	_check(GameState.has_upgrade(&"pistol_mk2"), "stary Ogłuszacz Mk2 = Pistolet Mk2")
	_check(GameState.knows(&"thornback", "hit"), "stary fakt 'ogłuszenie' = 'trafienie'")
	GameState.new_game()
	GameState.add_resource(&"crystal", 3)
	_check(not Recipes.craft(&"pistol_mk2"), "Pistolet Mk2 wymaga kolców Thornbacka")
	GameState.add_resource(&"thorn", 2)
	_check(Recipes.craft(&"pistol_mk2") and GameState.has_upgrade(&"pistol_mk2"), "Pistolet Mk2 z kryształów i kolców")


# --- Wyprawa -----------------------------------------------------------------

func _test_expedition() -> void:
	GameState.new_game()
	GameState.add_resource(&"seed_snapper", 2)
	GameState.add_resource(&"seed_boomshroom", 1)
	var run := GameState.start_run({&"seed_snapper": 2, &"seed_boomshroom": 1})
	_check(run.offhand == &"seed_snapper", "druga ręka: pierwszy rzucany przedmiot z plecaka")
	_check(run.cycle_offhand() == &"seed_boomshroom" and run.cycle_offhand() == &"seed_snapper", "R przełącza rzucane")

	var expedition := EXPEDITION.instantiate()
	expedition.set("return_scene", "")
	add_child(expedition)
	await _frames(3)
	var level := expedition.get_node("Level")
	var player := expedition.get_node("Player") as Player
	var interaction := player.interaction as ExpeditionInteraction

	# Model z animacjami.
	_check(player.get_node_or_null("Visual/Model") != null, "gracz ma model z Blendera")
	_check(player.animation_state() == &"Idle", "animacja na start: Idle")
	var tree := player.get_node("Visual/Model/AnimationTree") as AnimationTree
	_check(tree != null and tree.active, "AnimationTree działa")

	# Pora doby na wyprawie: noc ciemna, latarka na hełmie; w dzień latarka zgaszona.
	var day_night := expedition.get("day_night") as DayNight
	_check(day_night != null, "wyprawa ma porę doby")
	GameState.time_of_day = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	var sun := expedition.get_node("Sun") as DirectionalLight3D
	_check(player.flashlight.visible and player.flashlight.light_energy > 4.0, "noc: latarka na hełmie świeci")
	player.toggle_flashlight()
	await get_tree().process_frame
	_check(not player.flashlight.visible and not GameState.flashlight_on, "F gasi latarkę")
	player.toggle_flashlight()
	await get_tree().process_frame
	_check(player.flashlight.visible, "F zapala latarkę")
	var env := (expedition.get_node("WorldEnvironment") as WorldEnvironment).environment
	_check(sun.light_energy < 0.05 and env.ambient_light_sky_contribution < 0.01, "noc: prawie czarno (księżyc %.3f)" % sun.light_energy)
	GameState.time_of_day = 0.5
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not player.flashlight.visible and sun.light_energy > 0.5, "dzień: latarka zgaszona, jasno")

	# Dash i bieg.
	var start := player.global_position
	_check(player.dash(Vector3.FORWARD), "dash działa")
	_check(not player.dash(Vector3.FORWARD), "dash ma czas odnowienia")
	# Sygnał physics_frame przychodzi przed _physics_process gracza, więc czekamy 2 kroki.
	await _frames(2)
	_check(player.animation_state() == &"Dash", "animacja dasha")
	player.play_shoot()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(bool(tree.get("parameters/shoot/active")), "strzał gra na górze ciała")
	await get_tree().create_timer(0.25).timeout
	_check(start.distance_to(player.global_position) > 2.0, "dash przesuwa gracza (%.1f m)" % start.distance_to(player.global_position))
	player.sprinting = true
	player.stop_sprint()
	_check(not player.sprinting, "strzał przerywa bieg")

	# Pistolet: obrażenia, budzenie, ucieczka, śmierć i łup.
	var creature: Creature = level.get_children().filter(func(n: Node) -> bool: return n is Creature)[0]
	var anim := creature.get("_anim") as AnimationPlayer
	_check(anim != null and anim.current_animation == &"Sleep", "Thornback z Blendera: śpi (animacja Sleep)")
	interaction.set("_target", {"collider": creature, "position": creature.global_position + Vector3(0, 0.5, 0)})
	player.global_position = creature.global_position + Vector3(0, 0, 8)
	interaction.call("_fire")
	_check(creature.health == creature.max_health - ExpeditionInteraction.PISTOL_DAMAGE, "pistolet zadaje 10 obrażeń")
	_check(creature.state == Creature.State.CHASE, "postrzelony Thornback budzi się i atakuje")
	_check(anim.current_animation == &"Run", "Thornback biegnie (animacja Run)")
	_check(GameState.knows(&"thornback", "hit"), "baza danych: fakt o trafieniu")
	creature.take_hit(55.0)
	_check(creature.state == Creature.State.FLEE, "ranny Thornback ucieka")
	var awakening_before := run.awakening
	var pickups_before := _count(level, "Pickup")
	_check(creature.take_hit(20.0), "śmiertelny strzał")
	await _frames(3)
	_check(creature.is_dead() and not creature.is_in_group("creature"), "martwy Thornback nie jest już celem pułapek")
	_check(_count(level, "Pickup") == pickups_before + 1, "Thornback zostawia kolce")
	_check(run.awakening >= awakening_before + Creature.FLEE_HEALTH * 0 + 7.9, "zabicie drapieżnika budzi planetę (+8)")
	_check(not creature.trap(4.0), "martwego nie da się złapać")

	# Małe stworzenia.
	var critters := level.get_children().filter(func(n: Node) -> bool: return n is Critter)
	var bug: Critter = critters.filter(func(c: Critter) -> bool: return c.kind == Critter.Kind.POLLENBUG)[0]
	var chrupik: Critter = critters.filter(func(c: Critter) -> bool: return c.kind == Critter.Kind.CHRUPIK)[0]
	pickups_before = _count(level, "Pickup")
	bug.take_hit(4.0)
	await _frames(3)
	_check(bug.is_stunned() and _count(level, "Pickup") == pickups_before + 1, "trafiony Pyłkowiec spada i gubi pyłek")
	_check(not chrupik.take_hit(5.0) and chrupik.get("_panic") > 0.0, "trafiony Chrupik ucieka w panice")
	pickups_before = _count(level, "Pickup")
	_check(chrupik.take_hit(50.0), "Chrupik ginie")
	await _frames(3)
	var fertilizer := level.get_children().filter(func(n: Node) -> bool: return n is Pickup and (n as Pickup).item_id == &"fertilizer")
	_check(fertilizer.size() == 1, "martwy Chrupik zostawia nawóz")

	# PPM: rzut z drugiej ręki.
	var ground := player.global_position + Vector3(0, 0, -4)
	interaction.set("_target", {"collider": level.get_node("Ground"), "position": Vector3(ground.x, 0, ground.z)})
	var traps_before := _count(expedition, "TrapPlant")
	interaction.call("_throw")
	await _frames(1)
	_check(_count(expedition, "TrapPlant") == traps_before + 1 and run.count(&"seed_snapper") == 1, "PPM rzuca Snappera z drugiej ręki")

	# Plecak: druga ręka i wyrzucanie.
	run.add_item(&"crystal", 2)
	var panel := InventoryPanel.new()
	expedition.get_node("HUD").add_child(panel)
	panel.drop_requested.connect(func(id: StringName, amount: int) -> void: interaction.drop_item(id, amount))
	panel.open(run)
	await get_tree().process_frame
	var slots := panel.find_children("*", "InventorySlot", true, false).filter(func(s: InventorySlot) -> bool: return s.kind == "item" and s.item_id != &"")
	_check(slots.size() == 3, "plecak pokazuje 3 rodzaje przedmiotów (%d)" % slots.size())
	panel.handle_drop("offhand", &"seed_boomshroom", 1)
	_check(run.offhand == &"seed_boomshroom", "przeciągnięcie na rękę PPM zmienia rzucany przedmiot")
	panel.handle_drop("offhand", &"crystal", 2)
	_check(run.offhand == &"seed_boomshroom", "kryształu nie da się włożyć do ręki")
	var used := run.used_space()
	panel.handle_drop("trash", &"crystal", 1)
	await _frames(2)
	_check(run.used_space() == used - 1 and run.count(&"crystal") == 1, "wyrzucono 1 kryształ")
	var dropped: Array = expedition.get_children().filter(func(n: Node) -> bool: return n is Pickup and (n as Pickup).dropped)
	_check(dropped.size() == 1 and (dropped[0] as Pickup).item_id == &"crystal", "wyrzucony kryształ leży na ziemi")
	panel.close()

	# Ponowne podniesienie wyrzuconego nie podnosi Przebudzenia.
	var pickup := dropped[0] as Pickup
	player.global_position = pickup.global_position + Vector3(0, 0.3, 1.0)
	interaction.set("_target", {"collider": pickup, "position": pickup.global_position})
	var awake := run.awakening
	interaction.call("_interact")
	_check(run.count(&"crystal") == 2 and run.awakening - awake < 0.5, "podniesione z powrotem, bez wzrostu Przebudzenia")

	await _test_night(level, player)

	expedition.queue_free()
	await _frames(2)
	GameState.finish_run(false)


# --- Noc na wyprawie ----------------------------------------------------------

func _test_night(level: Node, player: Player) -> void:
	var night_pickups := level.get_children().filter(func(n: Node) -> bool: return n is Pickup and (n as Pickup).night_only)
	var moths := level.get_children().filter(func(n: Node) -> bool: return n is Critter and (n as Critter).kind == Critter.Kind.LUMIMOTH)
	var drifters := level.get_children().filter(func(n: Node) -> bool: return n is Critter and (n as Critter).kind == Critter.Kind.DRIFTER)
	var bugs := level.get_children().filter(func(n: Node) -> bool: return n is Critter and (n as Critter).kind == Critter.Kind.POLLENBUG and (n as Critter).health > 0.0)
	_check(not moths.is_empty() and not drifters.is_empty(), "na łące są ćmy i meduzowce")
	GameState.time_of_day = 0.5
	await _frames(2)
	await get_tree().process_frame
	_check(night_pickups.all(func(p: Pickup) -> bool: return not p.visible and p.collision_layer == 0), "dzień: nocnych znajdziek nie widać")
	_check(moths.all(func(c: Critter) -> bool: return not c.visible), "dzień: ćmy śpią")
	GameState.time_of_day = 0.0
	await _frames(2)
	await get_tree().process_frame
	_check(night_pickups.all(func(p: Pickup) -> bool: return p.visible and p.collision_layer == 4), "noc: nocne znajdźki świecą i da się je podnieść")
	_check(moths.all(func(c: Critter) -> bool: return c.visible and c.is_in_group("critter")), "noc: ćmy latają")
	_check(bugs.all(func(c: Critter) -> bool: return not c.visible), "noc: Pyłkowce śpią")

	# Ćma leci do latarki.
	var moth := moths[0] as Critter
	moth.global_position = player.global_position + Vector3(8, 2, 0)
	var before := moth.global_position.distance_to(player.global_position)
	await get_tree().create_timer(1.0).timeout
	_check(moth.global_position.distance_to(player.global_position) < before - 1.0, "ćma leci do latarki")
	var pickups_before := _count(level, "Pickup")
	moth.take_hit(5.0)
	await _frames(3)
	_check(moth.is_stunned() and _count(level, "Pickup") == pickups_before + 1, "trafiona ćma spada i gubi Lumen Dust")

	# Meduzowiec parzy z bliska.
	var drifter := drifters[0] as Critter
	var health := player.health
	drifter.global_position = player.global_position + Vector3(0.5, 2.0, 0)
	await _frames(3)
	_check(player.health < health and GameState.knows(&"drifter", "sting"), "meduzowiec parzy z bliska")

	# Lepsza latarka z warsztatu.
	for id in [&"lumen_dust", &"glow_spores"]:
		GameState.add_resource(id, 2)
	GameState.add_resource(&"starfall_shard", 1)
	_check(Recipes.craft(&"lamp_mk2"), "Bright Lamp z nocnych materiałów")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(player.flashlight.spot_range > 30.0, "Bright Lamp świeci dalej")
	_check(Codex.ENTRIES.has(&"moonpetal") and Codex.ENTRIES.has(&"lumimoth") and Codex.ENTRIES.has(&"drifter"), "baza danych zna nocne gatunki")
	# Bioluminescencja: świeci nocą, gaśnie w dzień, ślady stóp za graczem.
	var bio := level.get_node_or_null("Bioluminescence") as Bioluminescence
	_check(bio != null and bio.get_node("Grass").multimesh.instance_count > 1000, "łąka: świecąca trawa")
	GameState.time_of_day = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	_check(bio.night > 0.9, "noc: trawa, mech i świetliki świecą")
	var start := player.global_position
	for i in 6:
		player.global_position = start + Vector3(0, 0, -0.7 * (i + 1))
		await get_tree().process_frame
		await get_tree().physics_frame
	_check(bio.visible_steps() >= 3, "noc: świecące ślady stóp (%d)" % bio.visible_steps())
	GameState.time_of_day = 0.5
	await get_tree().process_frame
	await get_tree().process_frame
	_check(bio.night < 0.01, "dzień: bioluminescencja gaśnie")
	var moon := PlantCatalog.get_plant(&"moonpetal")
	_check(moon != null and moon.night_glow and PlantVisuals.MODELS.has(&"moonpetal"), "Moonpetal: roślina z modelem, świeci nocą")


# --- Zegar doby ---------------------------------------------------------------

func _test_clock() -> void:
	_check(GameState.clock_text(0.5) == "12:00" and GameState.clock_text(0.75) == "18:00", "zegar: 12:00 i 18:00")
	_check(GameState.night_amount(0.0) == 1.0 and GameState.night_amount(0.5) == 0.0, "noc o północy, dzień w południe")
	var dusk := GameState.night_amount(0.75)
	_check(dusk > 0.0 and dusk < 1.0, "zmierzch: płynne przejście")
	_check(DayNight.palette(0.0, DayNight.DAWN)["energy"] < 0.05 and DayNight.NIGHT_AMBIENT.get_luminance() < 0.01, "noc prawie czarna")
	GameState.time_of_day = 0.99
	GameState.advance_time(GameState.DAY_SECONDS * 0.02)
	_check(GameState.time_of_day < 0.02, "doba zawija się po północy")
	GameState.time_of_day = 0.9
	var data := GameState.to_dict()
	GameState.from_dict(data)
	_check(is_equal_approx(GameState.time_of_day, 0.9), "pora doby w zapisie gry")


# --- Pomocnicze --------------------------------------------------------------

static func _count(parent: Node, class_label: String) -> int:
	var total := 0
	for child in parent.get_children():
		if (class_label == "Pickup" and child is Pickup and not child.is_queued_for_deletion()) or (class_label == "TrapPlant" and child is TrapPlant):
			total += 1
	return total


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		printerr("  FAIL ", label)
