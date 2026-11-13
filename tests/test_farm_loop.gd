extends Node
## Test pętli M1 na prawdziwej scenie: sadzenie → podlewanie → cykle → zbiór.
## Uruchom:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_farm_loop.tscn
## (scena, nie --script: w trybie --script autoloady nie są widoczne przy kompilacji)

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var state: Node = get_node_or_null("/root/GameState")
	_check(state != null, "autoload GameState dostępny")
	if state == null:
		_finish()
		return
	state.new_game()
	# Najazdy testuje test_base_defense; tutaj wyłączone, żeby nie ruszały upraw.
	state.raid_pressure = -100000

	var farm := Farm.new()
	add_child(farm)
	var soil := StaticBody3D.new()
	soil.add_to_group("soil")
	add_child(soil)
	var rock := StaticBody3D.new()
	rock.add_to_group("obstacle")
	add_child(rock)

	var voidberry := PlantCatalog.get_plant(&"voidberry")
	var crystal := PlantCatalog.get_plant(&"crystal_bloom")
	var here := Vector3.ZERO
	var spot := Vector3(1, 0, 0)

	# Reguły sadzenia i powody odmowy.
	_check(farm.placement_problem(voidberry, spot, Vector3.UP, soil, here) == "", "można sadzić na glebie")
	_check(farm.placement_problem(voidberry, spot, Vector3.UP, rock, here) == "Can't plant here", "skała to nie gleba")
	_check(farm.placement_problem(voidberry, spot, Vector3(0.7, 0.7, 0), soil, here) == "Too steep", "za stromo")
	_check(farm.placement_problem(voidberry, Vector3(9, 0, 0), Vector3.UP, soil, here) == "Too far", "za daleko")

	var plant := farm.plant_seed(voidberry, spot)
	_check(plant != null, "posadzono Voidberry")
	_check(state.get_resource(&"seed_voidberry") == 1, "zużyto 1 nasiono")
	_check(farm.placement_problem(voidberry, spot + Vector3(0.3, 0, 0), Vector3.UP, soil, here) == "Occupied", "siatka: pole zajęte")
	_check(plant.global_position.x == 1.5 and plant.global_position.z == 0.5, "roślina na środku pola siatki")
	_check(farm.placement_problem(voidberry, spot + Vector3(1.0, 0, 0), Vector3.UP, soil, here) == "", "sąsiednie pole wolne")
	_check(state.farm.size() == 1, "farma zapisana w GameState")

	# Bez wody nie rośnie.
	state.advance_cycle()
	_check(plant.stage == 0, "bez wody nie rośnie")
	_check(plant.is_thirsty(), "roślina spragniona")

	# Z wodą rośnie aż do dojrzałości.
	_check(plant.water(), "podlano")
	state.advance_cycle()
	_check(plant.stage == 1, "etap 2 po podlaniu")
	plant.water()
	state.advance_cycle()
	_check(plant.is_ripe(), "dojrzała po 2 podlanych cyklach")
	_check(not plant.is_thirsty(), "dojrzała nie potrzebuje wody")

	# Zbiór daje owoce i nasiona.
	var gained := farm.harvest(plant)
	_check(gained.get(&"voidberry", 0) >= 2, "zebrano owoce Voidberry")
	_check(gained.get(&"seed_voidberry", 0) >= 1, "zebrano nasiona")
	_check(farm.plant_count() == 0, "roślina usunięta po zbiorze")

	# Crystal Bloom: bez wody, ale 2 cykle na etap.
	var bloom := farm.plant_seed(crystal, Vector3(-2, 0, 0))
	state.advance_cycle()
	_check(bloom.stage == 0 and bloom.progress == 1, "Crystal Bloom rośnie wolno")
	state.advance_cycle()
	_check(bloom.stage == 1, "Crystal Bloom etap 2 po 2 cyklach bez wody")

	# Zapis i odtworzenie farmy.
	var saved: Array = state.farm.duplicate(true)
	farm.load_from_state()
	await get_tree().process_frame
	_check(farm.plant_count() == 1, "farma odtworzona z zapisu")
	_check(saved.size() == 1 and int(saved[0]["stage"]) == 1, "zapisany etap rośliny")

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("TESTY OK")
	else:
		printerr("TESTY: %d błędów" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		printerr("  FAIL ", label)
