extends SceneTree
## Szybki test GameState bez otwierania edytora.
## Uruchom:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_game_state.gd

const GameStateScript := preload("res://scripts/autoload/game_state.gd")
const TEST_SAVE := "user://test_save.json"

var _failures := 0


func _initialize() -> void:
	var state: Node = GameStateScript.new()
	state.reset()

	state.advance_cycle()
	state.advance_cycle()
	_check(state.cycle == 2, "cykle się sumują")

	_check(state.add_discovery(&"voidberry"), "nowe odkrycie zwraca true")
	_check(not state.add_discovery(&"voidberry"), "powtórne odkrycie zwraca false")

	state.add_resource(&"crystal", 5)
	_check(state.spend_resource(&"crystal", 3), "wydanie zasobu")
	_check(not state.spend_resource(&"crystal", 3), "brak zasobu blokuje wydanie")
	_check(state.get_resource(&"crystal") == 2, "zostały 2 kryształy")

	state.change_balance(&"zielona_dolina", 250)
	_check(state.get_balance(&"zielona_dolina") == 100, "Równowaga przycięta do 100")
	state.change_balance(&"zielona_dolina", -130)
	_check(state.get_balance(&"zielona_dolina") == -30, "Równowaga spada")

	state.change_planet_attention(-10)
	_check(state.planet_attention == 0, "Uwaga planety nie spada poniżej 0")
	state.change_planet_attention(40)
	state.farm = [{"id": "voidberry", "x": 1.5, "y": 0.0, "z": -2.0, "stage": 1, "progress": 0, "watered": true}]

	_check(state.save_game(TEST_SAVE) == OK, "zapis gry")
	var loaded: Node = GameStateScript.new()
	loaded.reset()
	_check(loaded.load_game(TEST_SAVE), "wczytanie gry")
	_check(loaded.cycle == 2, "wczytany cykl")
	_check(loaded.has_discovery(&"voidberry"), "wczytane odkrycie")
	_check(loaded.get_resource(&"crystal") == 2, "wczytane zasoby")
	_check(loaded.get_balance(&"zielona_dolina") == -30, "wczytana Równowaga")
	_check(loaded.planet_attention == 40, "wczytana Uwaga planety")
	_check(loaded.farm.size() == 1 and int(loaded.farm[0]["stage"]) == 1, "wczytana farma")

	var fresh: Node = GameStateScript.new()
	fresh.new_game()
	_check(fresh.get_resource(&"seed_voidberry") == 2, "nowa gra: nasiona startowe")
	_check(fresh.get_resource(&"water") == fresh.WATER_CAPACITY, "nowa gra: pełna konewka")

	# Wyprawy: wyposażenie, plecak, sukces i porażka.
	var run: RunState = fresh.start_run({&"seed_snapper": 5, &"seed_voidberry": 1})
	_check(run.count(&"seed_snapper") == 1, "wyprawa: zabrano tyle Snapperów, ile było")
	_check(fresh.get_resource(&"seed_snapper") == 0, "wyprawa: wyposażenie zdjęte z magazynu")
	_check(run.add_item(&"crystal", 20) == RunState.BACKPACK_CAPACITY - 2, "plecak ma limit")
	_check(run.free_space() == 0, "plecak pełny")
	var reached: Array[int] = []
	run.threshold_reached.connect(func(t: int) -> void: reached.append(t))
	run.add_awakening(60.0)
	_check(reached == [25, 50], "progi Przebudzenia 25 i 50")
	var report: Dictionary = fresh.finish_run(true)
	_check(report["success"] and fresh.get_resource(&"crystal") == 8, "sukces: plecak trafia do magazynu")
	_check(fresh.get_resource(&"seed_snapper") == 1, "sukces: niezużyte wyposażenie wraca")
	_check(fresh.pending_cycles == 1 and fresh.run == null, "po wyprawie: cykl do rozliczenia")

	fresh.start_run({&"seed_voidberry": 1})
	fresh.run.discoveries.append(&"thornback")
	var lost: Dictionary = fresh.finish_run(false, "test")
	_check(not lost["success"] and lost["lost"].get(&"seed_voidberry", 0) == 1, "porażka: plecak przepada")
	_check(fresh.get_resource(&"seed_voidberry") == 1, "porażka: magazyn bez zwrotu")
	_check(lost["discoveries"].size() == 1, "porażka: odkrycia w raporcie")
	fresh.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	state.free()
	loaded.free()

	if _failures == 0:
		print("TESTY OK")
	else:
		printerr("TESTY: %d błędów" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		printerr("  FAIL ", label)
