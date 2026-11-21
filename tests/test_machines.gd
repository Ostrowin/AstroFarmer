extends Node
## Maszyny farmy: dron nawadniający z dokiem i traktor z siewnikiem.
## Uruchom:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_machines.tscn

const TEST_SAVE := "user://test_machines_save.json"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _failures := 0
var _farm: Farm


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.save_path = TEST_SAVE
	GameState.new_game()
	GameState.raid_pressure = -100000
	_build_world()
	await _test_dock()
	await _test_drone_watering()
	await _test_drone_refill()
	_test_dock_removal()
	await _test_tractor_driving()
	_test_seeder()
	await _test_riding()
	await _test_mushroom_log()
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	GameState.save_path = GameState.SAVE_PATH
	_finish()


## Płaska gleba 100×100 m i staw (woda, nie gleba) w punkcie (8, 0, 0).
func _build_world() -> void:
	var soil := StaticBody3D.new()
	soil.add_to_group("soil")
	var ground := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	ground.shape = box
	ground.position.y = -0.5
	soil.add_child(ground)
	add_child(soil)
	var pond := StaticBody3D.new()
	pond.add_to_group("water")
	var water := CollisionShape3D.new()
	var disc := CylinderShape3D.new()
	disc.radius = 2.0
	disc.height = 0.2
	water.shape = disc
	pond.add_child(water)
	add_child(pond)
	pond.global_position = Vector3(8, 0, 0)
	_farm = Farm.new()
	add_child(_farm)
	await get_tree().physics_frame


func _test_dock() -> void:
	GameState.add_resource(&"crystal", 3)
	_check(Recipes.craft(&"drone") and GameState.get_resource(&"drone_dock") == 1, "warsztat robi drona z doku")
	var spot := Vector3(0.5, 0, 0.5)
	_check(_farm.dock_problem(spot, Vector3.UP, _soil(), Vector3.ZERO) == "", "dok można postawić na glebie")
	var dock := _farm.place_dock(spot)
	_check(dock != null and _farm.dock_count() == 1 and GameState.get_resource(&"drone_dock") == 0, "dok postawiony, magazyn pusty")
	_check(dock.drone != null and dock.drone.water == WateringDrone.TANK, "dok ma drona z pełnym zbiornikiem")
	_check(_farm.dock_problem(spot, Vector3.UP, _soil(), Vector3.ZERO) == "No drone docks", "bez doku w magazynie: odmowa")
	GameState.add_resource(&"seed_voidberry", 1)
	_check(_farm.placement_problem(PlantCatalog.get_plant(&"voidberry"), spot, Vector3.UP, _soil(), Vector3.ZERO) == "Occupied", "pole doku jest zajęte")
	var saved := GameState.structures.filter(func(e: Dictionary) -> bool: return e["id"] == "drone_dock")
	_check(saved.size() == 1, "dok w zapisie budowli")
	GameState.from_dict(GameState.to_dict())
	_farm.load_from_state()
	await get_tree().physics_frame
	_check(_farm.dock_count() == 1 and _farm.docks()[0].drone != null, "dok i dron wracają po wczytaniu")


## Mushroom Log (od Sporekinów): stawianie, grzyb co cykl (max 3), zbiór, zapis, Mushroom Stew.
func _test_mushroom_log() -> void:
	Engine.time_scale = 1.0
	var spot := Vector3(-6.5, 0, -6.5)
	_check(_farm.log_problem(spot, Vector3.UP, _soil(), spot) == "No mushroom logs", "bez kłody w magazynie: odmowa")
	GameState.add_resource(&"mushroom_log", 1)
	_check(_farm.log_problem(spot, Vector3.UP, _soil(), spot) == "", "kłodę można postawić na glebie")
	var log := _farm.place_log(spot)
	_check(log != null and log.mushrooms == 0 and GameState.get_resource(&"mushroom_log") == 0, "kłoda postawiona")
	for i in 4:
		GameState.advance_cycle()
	_check(log.mushrooms == MushroomLog.MAX, "grzyby rosną co cykl, najwyżej %d" % MushroomLog.MAX)
	var saved := GameState.structures.filter(func(e: Dictionary) -> bool: return e["id"] == "mushroom_log")
	_check(saved.size() == 1 and int(saved[0]["mushrooms"]) == MushroomLog.MAX, "kłoda i grzyby w zapisie")
	GameState.from_dict(GameState.to_dict())
	_farm.load_from_state()
	await get_tree().physics_frame
	var logs := _farm.logs()
	_check(logs.size() == 1 and logs[0].mushrooms == MushroomLog.MAX, "kłoda wraca po wczytaniu z grzybami")
	var before := GameState.get_resource(&"mushroom")
	_check(_farm.use_log(logs[0]) == MushroomLog.MAX and GameState.get_resource(&"mushroom") == before + MushroomLog.MAX, "zbiór daje grzyby")
	_check(_farm.use_log(logs[0]) == -1 and GameState.get_resource(&"mushroom_log") == 1 and _farm.logs().is_empty(), "pusta kłoda wraca do magazynu")
	var stew := Meals.get_meal(&"stew")
	_check(Meals.can_cook(stew, {&"mushroom": 2}), "z grzybów da się ugotować Mushroom Stew")


func _test_drone_watering() -> void:
	Engine.time_scale = 6.0
	GameState.add_resource(&"seed_voidberry", 1)
	var plant := _farm.plant_seed(PlantCatalog.get_plant(&"voidberry"), Vector3(4.5, 0, 2.5))
	var can := GameState.get_resource(&"water")
	_check(plant != null and plant.is_thirsty(), "nowa roślina jest spragniona")
	var drone := _farm.docks()[0].drone
	await _wait_until(func() -> bool: return not plant.is_thirsty(), 12.0)
	_check(not plant.is_thirsty(), "dron podlał roślinę")
	_check(drone.water == WateringDrone.TANK - 1, "podlanie zużyło wodę drona")
	_check(GameState.get_resource(&"water") == can, "konewka gracza nietknięta")
	await _wait_until(func() -> bool: return drone.state == WateringDrone.State.DOCKED, 12.0)
	_check(drone.state == WateringDrone.State.DOCKED, "bez pracy dron wraca na dok")
	GameState.add_resource(&"seed_voidberry", 1)
	var far := _farm.plant_seed(PlantCatalog.get_plant(&"voidberry"), Vector3(30.5, 0, 0.5))
	await _wait_frames(60)
	_check(far != null and far.is_thirsty() and drone.state == WateringDrone.State.DOCKED, "roślina poza zasięgiem zostaje dla gracza")


func _test_drone_refill() -> void:
	var drone := _farm.docks()[0].drone
	drone.water = 0
	GameState.add_resource(&"seed_voidberry", 1)
	var plant := _farm.plant_seed(PlantCatalog.get_plant(&"voidberry"), Vector3(-2.5, 0, 1.5))
	var visited_pond := false
	var deadline := Time.get_ticks_msec() + 20000
	while plant.is_thirsty() and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if drone.state == WateringDrone.State.REFILL:
			visited_pond = true
	_check(visited_pond, "z pustym zbiornikiem dron leci do stawu")
	_check(not plant.is_thirsty() and drone.water == WateringDrone.TANK - 1, "po tankowaniu podlewa dalej")


func _test_dock_removal() -> void:
	var dock := _farm.docks()[0]
	var drone := dock.drone
	_farm.remove_dock(dock)
	_check(_farm.dock_count() == 0 and GameState.get_resource(&"drone_dock") == 1, "zdjęty dok wraca do magazynu")
	_check(drone.is_queued_for_deletion(), "dron znika z dokiem")


func _test_tractor_driving() -> void:
	Engine.time_scale = 1.0
	var tractor := _new_tractor(Vector3(0, 0, -15))
	await get_tree().physics_frame
	var start := tractor.global_position
	for i in 120:
		tractor.drive(1.0, 0.0, 1.0 / 60.0)
	_check(tractor.global_position.z < start.z - 3.0 and absf(tractor.global_position.x - start.x) < 0.1, "gaz: traktor jedzie prosto do przodu (-Z)")
	_check(tractor.speed > 3.0 and tractor.speed <= Tractor.MAX_SPEED, "prędkość rośnie do limitu")
	var yaw := tractor.rotation.y
	for i in 60:
		tractor.drive(1.0, 1.0, 1.0 / 60.0)
	_check(tractor.rotation.y > yaw + 0.2, "A skręca w lewo")
	for i in 240:
		tractor.drive(-1.0, 0.0, 1.0 / 60.0)
	_check(tractor.speed < 0.0 and tractor.speed >= -Tractor.REVERSE_SPEED, "S hamuje, potem wsteczny")
	tractor.save_state()
	var saved := tractor.global_position
	GameState.from_dict(GameState.to_dict())
	tractor.global_position = Vector3.ZERO
	tractor.load_state()
	_check(tractor.global_position.distance_to(Vector3(saved.x, 0, saved.z)) < 0.01, "pozycja traktora w zapisie")
	tractor.queue_free()


func _test_seeder() -> void:
	var tractor := _new_tractor(Vector3(0.5, 0, -10.5))
	var cells := tractor.seeder_cells()
	_check(cells.size() == 3 and cells[0] != cells[1] and cells[1] != cells[2], "siewnik obejmuje 3 pola")
	_check(cells[0].y == cells[1].y and absi(cells[2].x - cells[0].x) == 2, "pola w jednym rzędzie za traktorem")
	var voidberry := PlantCatalog.get_plant(&"voidberry")
	GameState.resources[voidberry.seed_item()] = 3
	tractor.seed_plant = &"voidberry"
	var before := _farm.plant_count()
	var planted := 0
	for cell in cells:
		if tractor.work_cell(cell) == "plant":
			planted += 1
	_check(planted == 3 and _farm.plant_count() == before + 3, "siewnik sadzi 3 pola naraz")
	_check(GameState.get_resource(voidberry.seed_item()) == 0, "siewnik zużywa nasiona")
	var warnings: Array[String] = []
	tractor.notify.connect(func(text: String) -> void: warnings.append(text))
	var empty_cell := cells[0] + Vector2i(0, 3)
	_check(tractor.work_cell(empty_cell) == "" and tractor.work_cell(empty_cell + Vector2i(1, 0)) == "", "bez nasion nic nie sadzi")
	_check(warnings.size() == 1, "brak nasion zgłoszony raz")
	GameState.resources[voidberry.seed_item()] = 5
	_check(tractor.work_cell(Farm.cell_of(Vector3(8, 0, 0))) == "", "siewnik nie sadzi w stawie")
	var plant := _farm.occupant(cells[1]) as Plant
	for i in 20:
		if plant.is_ripe():
			break
		plant.water()
		GameState.advance_cycle()
	_check(plant.is_ripe(), "posadzona roślina dojrzewa")
	var crops := GameState.get_resource(voidberry.harvest_item)
	_check(tractor.work_cell(cells[1]) == "harvest" and _farm.occupant(cells[1]) == null, "siewnik zbiera dojrzałą uprawę")
	_check(GameState.get_resource(voidberry.harvest_item) > crops, "plon trafia do magazynu")
	_check(tractor.work_cell(cells[0]) == "", "niedojrzała uprawa zostaje")
	tractor.queue_free()


func _test_riding() -> void:
	var tractor := _new_tractor(Vector3(-10, 0, 10))
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.global_position = Vector3(-12, 0, 10)
	await get_tree().physics_frame
	tractor.enter(player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(player.vehicle == tractor and tractor.driver == player, "gracz wsiada do traktora")
	_check(player.global_position.distance_to(tractor.seat_position()) < 0.05, "gracz siedzi w fotelu")
	_check(Sfx.music_path() == Tractor.music_path(), "po wejściu gra muzyka traktora")
	_check(is_equal_approx(Sfx.music_volume(), Tractor.MUSIC_DB), "muzyka traktora od razu głośno")
	for i in 10:
		tractor.change_volume(1)
	_check(is_equal_approx(Sfx.music_volume(), Tractor.MUSIC_MAX_DB), "+ podgłaśnia do limitu")
	for i in 30:
		tractor.change_volume(-1)
	_check(is_equal_approx(Sfx.music_volume(), Tractor.MUSIC_MIN_DB) and tractor.change_volume(1) > 0, "- ścisza do limitu")
	var animator := player.get_node_or_null("Animator") as PlayerAnimator
	if animator:
		var skeleton := player.find_child("Skeleton3D", true, false) as Skeleton3D
		var thigh := skeleton.find_bone(&"thigh.L")
		var knee := skeleton.get_bone_global_pose(skeleton.find_bone(&"shin.L")).origin
		var hip := skeleton.get_bone_global_pose(thigh).origin
		_check(animator.seated and knee.z - hip.z > 0.25 and absf(knee.y - hip.y) < 0.2, "poza siedząca: uda poziomo do przodu")
	tractor.exit()
	await get_tree().physics_frame
	_check(player.vehicle == null and tractor.driver == null, "E wysiada")
	tractor.enter(player)
	_check(is_equal_approx(Sfx.music_volume(), Tractor.MUSIC_DB), "przy kolejnym wejściu znowu głośno")
	tractor.exit()
	await get_tree().physics_frame
	_check(Vector2(player.global_position.x - tractor.global_position.x, player.global_position.z - tractor.global_position.z).length() > 1.2, "gracz staje obok traktora")
	if animator:
		_check(not animator.seated, "po wyjściu zwykłe animacje")
	player.queue_free()
	tractor.queue_free()


# --- Pomocnicze --------------------------------------------------------------

func _new_tractor(at: Vector3) -> Tractor:
	var tractor := Tractor.new()
	tractor.farm = _farm
	add_child(tractor)
	tractor.global_position = at
	return tractor


func _soil() -> Node:
	return get_tree().get_first_node_in_group("soil")


func _wait_until(condition: Callable, seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame


func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


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
