extends Node
## Scenariusz wyprawy na prawdziwej scenie: świat, drapieżnik, ogłuszenie,
## pułapka Snappera, burza przy Przebudzeniu 100, porażka i udana ewakuacja.
## Uruchom:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_expedition.tscn

const EXPEDITION := preload("res://scenes/levels/expedition_meadow.tscn")
const TEST_SAVE := "user://test_expedition_save.json"

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.save_path = TEST_SAVE

	# --- Wyprawa 1: porażka -------------------------------------------------
	GameState.new_game()
	GameState.add_resource(&"seed_snapper", 2)
	GameState.start_run({&"seed_snapper": 2})
	var exp1 := _spawn_expedition()
	await _frames(3)

	var level := exp1.get_node("Level")
	var pickups := level.get_children().filter(func(n: Node) -> bool: return n is Pickup and not (n as Pickup).night_only)
	var night_pickups := level.get_children().filter(func(n: Node) -> bool: return n is Pickup and (n as Pickup).night_only)
	var bushes := level.get_children().filter(func(n: Node) -> bool: return n is WildBush)
	var creatures := level.get_children().filter(func(n: Node) -> bool: return n is Creature)
	_check(pickups.size() == 12, "11 znajdziek + 1 ulepszenie (jest %d)" % pickups.size())
	_check(night_pickups.size() == 5, "5 nocnych znajdziek (jest %d)" % night_pickups.size())
	_check(bushes.size() == 4, "4 dzikie krzewy")
	_check(creatures.size() == 1, "1 drapieżnik")
	var creature := creatures[0] as Creature
	_check(creature.state == Creature.State.SLEEP, "drapieżnik śpi przy Przebudzeniu < 50")

	GameState.run.add_awakening(50.0)
	await _frames(2)
	_check(creature.state == Creature.State.WANDER, "Przebudzenie 50: drapieżnik patroluje")

	creature.stun(0.5)
	_check(creature.state == Creature.State.STUNNED, "ogłuszacz: drapieżnik ogłuszony")
	await get_tree().create_timer(0.7).timeout
	_check(creature.state == Creature.State.FLEE, "po ogłuszeniu ucieka")

	var trap := TrapPlant.new()
	level.add_child(trap)
	trap.global_position = creature.global_position
	await get_tree().create_timer(TrapPlant.GROW_TIME + 0.4).timeout
	_check(creature.state == Creature.State.TRAPPED, "Snapper łapie drapieżnika")

	var player := exp1.get_node("Player") as Player
	GameState.run.add_awakening(50.0)
	await _frames(2)
	var health_before := player.health
	await get_tree().create_timer(1.0).timeout
	_check(player.health < health_before, "burza przy 100 zabiera Kondycję")

	var report1: Array = []
	exp1.finished.connect(func(r: Dictionary) -> void: report1.append(r))
	player.take_damage(500.0)
	await get_tree().create_timer(1.5).timeout
	_check(report1.size() == 1 and not report1[0]["success"], "Kondycja 0 = porażka")
	_check(report1.size() == 1 and report1[0]["lost"].get(&"seed_snapper", 0) == 2, "porażka: wyposażenie przepada")
	_check(GameState.pending_cycles == 1, "porażka też zużywa cykl")
	exp1.queue_free()
	await _frames(2)

	# --- Wyprawa 2: udana ewakuacja -----------------------------------------
	GameState.add_resource(&"voidberry", 1)
	GameState.start_run({&"voidberry": 1})
	GameState.run.add_item(&"crystal", 2)
	var exp2 := _spawn_expedition()
	await _frames(3)
	var creature2: Creature = exp2.get_node("Level").get_children().filter(func(n: Node) -> bool: return n is Creature)[0]
	var boom := BoomPlant.new()
	exp2.get_node("Level").add_child(boom)
	boom.global_position = creature2.global_position + Vector3(1.5, 0, 0)
	await get_tree().create_timer(BoomPlant.GROW_TIME + 0.3).timeout
	_check(creature2.state == Creature.State.STUNNED, "rzucony Boomshroom ogłusza drapieżnika w zasięgu")
	var report2: Array = []
	exp2.finished.connect(func(r: Dictionary) -> void: report2.append(r))
	exp2.call("_start_evac")
	await get_tree().create_timer(6.2).timeout
	_check(report2.size() == 1 and report2[0]["success"], "ewakuacja po 5 s na lądowisku = sukces")
	_check(GameState.get_resource(&"crystal") == 2 and GameState.get_resource(&"voidberry") == 1, "sukces: łup i wyposażenie w magazynie")
	exp2.queue_free()
	await _frames(2)

	# --- Powrót do bazy: cykle z wypraw rozliczone, rośliny urosły ----------
	GameState.farm = [{"id": "voidberry", "x": 0.0, "y": 0.0, "z": -1.0, "stage": 0, "progress": 0, "watered": true}]
	_check(GameState.pending_cycles == 2 and GameState.cycle == 0, "przed powrotem: 2 cykle czekają")
	var base := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(base)
	await _frames(2)
	_check(GameState.cycle == 2 and GameState.pending_cycles == 0, "baza rozlicza cykle z wypraw")
	_check(int(GameState.farm[0]["stage"]) == 1, "podlana roślina urosła raz, bez wody stoi")
	_check(GameState.last_run_report.is_empty(), "raport pokazany i wyczyszczony")
	base.queue_free()
	await _frames(1)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	GameState.save_path = GameState.SAVE_PATH
	if _failures == 0:
		print("TESTY OK")
	else:
		printerr("TESTY: %d błędów" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


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
