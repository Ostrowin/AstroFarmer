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
	_test_migrations()
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

	# Dash i bieg.
	var start := player.global_position
	_check(player.dash(Vector3.FORWARD), "dash działa")
	_check(not player.dash(Vector3.FORWARD), "dash ma czas odnowienia")
	await get_tree().create_timer(0.25).timeout
	_check(start.distance_to(player.global_position) > 2.0, "dash przesuwa gracza (%.1f m)" % start.distance_to(player.global_position))
	player.sprinting = true
	player.stop_sprint()
	_check(not player.sprinting, "strzał przerywa bieg")

	# Pistolet: obrażenia, budzenie, ucieczka, śmierć i łup.
	var creature: Creature = level.get_children().filter(func(n: Node) -> bool: return n is Creature)[0]
	interaction.set("_target", {"collider": creature, "position": creature.global_position + Vector3(0, 0.5, 0)})
	player.global_position = creature.global_position + Vector3(0, 0, 8)
	interaction.call("_fire")
	_check(creature.health == creature.max_health - ExpeditionInteraction.PISTOL_DAMAGE, "pistolet zadaje 10 obrażeń")
	_check(creature.state == Creature.State.CHASE, "postrzelony Thornback budzi się i atakuje")
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

	expedition.queue_free()
	await _frames(2)
	GameState.finish_run(false)


# --- Pomocnicze --------------------------------------------------------------

static func _count(parent: Node, class_label: String) -> int:
	var total := 0
	for child in parent.get_children():
		if (class_label == "Pickup" and child is Pickup) or (class_label == "TrapPlant" and child is TrapPlant):
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
