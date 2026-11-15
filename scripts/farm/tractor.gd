class_name Tractor
extends CharacterBody3D
## Traktor w bazie: E wsiada, WASD jedzie (W/S gaz i wsteczny, A/D skręt), E wysiada.
## Z tyłu siewnik na 3 pola: opuszczony (LMB) zbiera dojrzałe uprawy i sadzi
## nasiona wybrane na pasku w wolne pola gleby, pasem 3 pól za traktorem.
## Po wejściu zawsze gra muzyka traktora od początku; po wyjściu wraca muzyka bazy.

signal entered
signal exited
signal notify(text: String)
## Zmiana głośności muzyki (+/-), tekst do pokazania graczowi.
signal volume_changed(text: String)

const MODEL := preload("res://art/models/machines/tractor.glb")
## Lokalny utwór (Rednex, tylko na dysku autora, w .gitignore); bez niego własny hoedown.
const MUSIC := "res://audio/music/cotton_eye_joe.mp3"
const MUSIC_FALLBACK := "res://audio/music/hoedown_circuit.ogg"
## Na start bardzo głośno (muzyka bazy gra na -12 dB). +/- zmienia o krok, w granicach.
const MUSIC_DB := 0.0
const MUSIC_STEP_DB := 3.0
const MUSIC_MIN_DB := -30.0
const MUSIC_MAX_DB := 6.0

const MAX_SPEED := 6.0
const REVERSE_SPEED := 2.5
const ACCELERATION := 3.5
const BRAKING := 9.0
const ROLL_DRAG := 2.5
const WHEELBASE := 1.55
const MAX_STEER := deg_to_rad(32.0)
const STEER_RATE := 2.2
const REAR_WHEEL_RADIUS := 0.62
const FRONT_WHEEL_RADIUS := 0.36
## Miejsce gracza (stopy) względem traktora, gdy model nie ma węzła SeatPoint.
const SEAT := Vector3(0, 0.3, 0.58)
## Linia sadzenia za traktorem (lokalne +Z) i 3 pasy po 1 m.
const SEEDER_BACK := 2.3
const LANES := [-1.0, 0.0, 1.0]
const SEEDER_LIFT := 0.25
const DEFAULT_POSITION := Vector3(7, 0, -2)
const DEFAULT_YAW := 0.0

var farm: Farm
var driver: Player
var seeder_down := false
## Gatunek do sadzenia (&"" = siewnik tylko zbiera). Ustawia pasek narzędzi gracza.
var seed_plant: StringName = &""
var speed := 0.0
var steer := 0.0
## Głośność muzyki traktora (dB); przy każdym wejściu wraca do MUSIC_DB.
var music_db := MUSIC_DB

var _model: Node3D
var _seat: Node3D
var _rear: Array[Node3D] = []
var _front: Array[Node3D] = []
var _axles: Array[Node3D] = []
var _axle_rest: Array[Basis] = []
var _spin_axis := Vector3.RIGHT
var _steer_axis := Vector3.UP
var _seeder: Node3D
var _seeder_rest := Vector3.ZERO
var _beacon: Node3D
var _exhaust: Node3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _last_cells := {}
var _fx_timer := 0.0
var _puff_timer := 0.0
var _blink := 0.0
var _plant_sound_cooldown := 0.0
var _warned_no_seeds := false


func _ready() -> void:
	add_to_group("tractor")
	collision_layer = 1
	collision_mask = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.95, 2.3, 2.6)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, 1.17, -0.12)
	add_child(collision)
	_model = MODEL.instantiate()
	add_child(_model)
	_seat = _model.find_child("SeatPoint", true, false) as Node3D
	for side in ["L", "R"]:
		var rear := _model.find_child("WheelR" + side, true, false) as Node3D
		var front := _model.find_child("WheelF" + side, true, false) as Node3D
		var axle := _model.find_child("FrontAxle" + side, true, false) as Node3D
		if rear:
			_rear.append(rear)
		if front:
			_front.append(front)
		if axle:
			_axles.append(axle)
			_axle_rest.append(axle.basis)
	# Osie obrotu w układzie węzłów modelu (model ma własny obrót z eksportu).
	if not _rear.is_empty():
		_spin_axis = (_rear[0].global_basis.inverse() * global_basis.x).normalized()
	if not _axles.is_empty():
		_steer_axis = (_axles[0].global_basis.inverse() * global_basis.y).normalized()
	_seeder = _model.find_child("Seeder", true, false) as Node3D
	if _seeder:
		_seeder_rest = _seeder.position
		_seeder.position = _seeder_rest + Vector3(0, SEEDER_LIFT, 0)
	_beacon = _model.find_child("Beacon", true, false) as Node3D
	_exhaust = _model.find_child("ExhaustTip", true, false) as Node3D


# --- Wsiadanie ---------------------------------------------------------------

func can_enter(player: Player) -> bool:
	return driver == null and player != null


func enter(player: Player) -> void:
	if not can_enter(player):
		return
	driver = player
	speed = 0.0
	_last_cells.clear()
	_warned_no_seeds = false
	player.enter_vehicle(self)
	Sfx.play(&"craft", global_position)
	music_db = MUSIC_DB
	Sfx.play_music(music_path(), music_db, 0.0)
	entered.emit()


func exit() -> void:
	if driver == null:
		return
	var player := driver
	driver = null
	speed = 0.0
	velocity = Vector3.ZERO
	player.exit_vehicle(exit_point())
	save_state()
	exited.emit()


static func music_path() -> String:
	return MUSIC if ResourceLoader.exists(MUSIC) else MUSIC_FALLBACK


## Gdzie postawić gracza po wyjściu: z lewej, z prawej albo z przodu, byle nie w przeszkodzie.
func exit_point() -> Vector3:
	var from := global_position + Vector3(0, 1.0, 0)
	for offset in [Vector3(-1.7, 0, 0), Vector3(1.7, 0, 0), Vector3(0, 0, -2.4), Vector3(0, 0, 3.5)]:
		var spot := to_global(offset)
		var query := PhysicsRayQueryParameters3D.create(from, spot + Vector3(0, 1.0, 0), 1, [get_rid()])
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return Vector3(spot.x, global_position.y, spot.z)
	return to_global(Vector3(-1.7, 0, 0))


func seat_position() -> Vector3:
	return _seat.global_position if _seat else to_global(SEAT)


## +1 głośniej, -1 ciszej. Zwraca nową głośność w procentach (100% = 0 dB).
func change_volume(direction: int) -> int:
	music_db = clampf(music_db + MUSIC_STEP_DB * signf(direction), MUSIC_MIN_DB, MUSIC_MAX_DB)
	Sfx.set_music_volume(music_db)
	var percent := roundi(db_to_linear(music_db) * 100.0)
	volume_changed.emit("Music %d%%" % percent)
	return percent


func toggle_seeder() -> void:
	seeder_down = not seeder_down
	_last_cells.clear()
	_warned_no_seeds = false
	Sfx.play(&"plant" if seeder_down else &"pickup", global_position)


# --- Zapis -------------------------------------------------------------------

func save_state() -> void:
	GameState.machines["tractor"] = {"x": global_position.x, "z": global_position.z, "yaw": rotation.y}


func load_state() -> void:
	var data: Dictionary = GameState.machines.get("tractor", {})
	global_position = Vector3(float(data.get("x", DEFAULT_POSITION.x)), DEFAULT_POSITION.y, float(data.get("z", DEFAULT_POSITION.z)))
	rotation = Vector3(0, float(data.get("yaw", DEFAULT_YAW)), 0)
	speed = 0.0
	velocity = Vector3.ZERO


# --- Jazda -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var steer_input := 0.0
	if driver and driver.input_enabled and driver.is_mouse_captured():
		throttle = Input.get_axis("move_back", "move_forward")
		steer_input = Input.get_axis("move_right", "move_left")
	drive(throttle, steer_input, delta)
	if driver:
		driver.global_position = seat_position()
	_work(delta)
	_animate(delta)


## Jeden krok jazdy (testy wołają wprost). throttle: -1..1, steer_input: -1 (prawo)..1 (lewo).
func drive(throttle: float, steer_input: float, delta: float) -> void:
	if throttle > 0.0:
		speed = move_toward(speed, MAX_SPEED * throttle, (BRAKING if speed < 0.0 else ACCELERATION) * delta)
	elif throttle < 0.0:
		speed = move_toward(speed, -REVERSE_SPEED * -throttle, (BRAKING if speed > 0.0 else ACCELERATION) * delta)
	else:
		speed = move_toward(speed, 0.0, ROLL_DRAG * delta)
	steer = move_toward(steer, steer_input * MAX_STEER, STEER_RATE * delta)
	if absf(speed) > 0.01:
		rotate_y(speed / WHEELBASE * tan(steer) * delta)
	var forward := -global_basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	# Uderzenie w przeszkodę wytraca prędkość.
	var real := get_real_velocity()
	var along := Vector2(real.x, real.z).dot(Vector2(forward.x, forward.z))
	if absf(along) < absf(speed) - 0.5:
		speed = along


# --- Siewnik -----------------------------------------------------------------

## Pola pod siewnikiem (3 pasy za traktorem).
func seeder_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for lane: float in LANES:
		cells.append(Farm.cell_of(to_global(Vector3(lane, 0, SEEDER_BACK))))
	return cells


func _work(delta: float) -> void:
	_plant_sound_cooldown -= delta
	if not seeder_down or farm == null or absf(speed) < 0.3:
		return
	var cells := seeder_cells()
	for i in cells.size():
		var cell := cells[i]
		if _last_cells.get(i) == cell:
			continue
		_last_cells[i] = cell
		work_cell(cell)
	_fx_timer -= delta
	if _fx_timer <= 0.0:
		_fx_timer = 0.2
		Effects.burst(farm, to_global(Vector3(randf_range(-1.2, 1.2), 0.1, SEEDER_BACK + 0.2)), Color(0.55, 0.42, 0.3), 4)


## Zbiera dojrzałą uprawę albo sadzi w wolnym polu. Zwraca "harvest", "plant" albo "".
func work_cell(cell: Vector2i) -> String:
	var taken := farm.occupant(cell)
	if taken is Plant:
		var plant := taken as Plant
		if not plant.is_ripe():
			return ""
		var pos := plant.global_position
		var color := plant.data.accent_color
		var gained := farm.harvest(plant)
		if gained.is_empty():
			return ""
		Sfx.play(&"harvest", pos)
		Effects.burst(farm, pos + Vector3(0, 0.5, 0), color)
		if driver:
			Effects.fly_to(farm, pos + Vector3(0, 0.5, 0), driver, color)
		notify.emit(PlayerInteraction.describe_gain(gained))
		return "harvest"
	if taken != null or seed_plant == &"":
		return ""
	var data := PlantCatalog.get_plant(seed_plant)
	if data == null:
		return ""
	if GameState.get_resource(data.seed_item()) <= 0:
		if not _warned_no_seeds:
			_warned_no_seeds = true
			notify.emit("No %s seeds" % data.display_name)
		return ""
	var exclude: Array[RID] = [get_rid()]
	if farm.plant_at_cell(data, cell, exclude) == null:
		return ""
	var at := Farm.cell_center(cell)
	if _plant_sound_cooldown <= 0.0:
		_plant_sound_cooldown = 0.12
		Sfx.play(&"plant", at)
	Effects.burst(farm, at + Vector3(0, 0.1, 0), Color(0.55, 0.42, 0.3), 6)
	return "plant"


# --- Wygląd ------------------------------------------------------------------

func _animate(delta: float) -> void:
	for wheel in _rear:
		wheel.rotate_object_local(_spin_axis, -speed / REAR_WHEEL_RADIUS * delta)
	for wheel in _front:
		wheel.rotate_object_local(_spin_axis, -speed / FRONT_WHEEL_RADIUS * delta)
	for i in _axles.size():
		_axles[i].basis = _axle_rest[i] * Basis(_steer_axis, steer)
	if _seeder:
		var goal := _seeder_rest + Vector3(0, 0.0 if seeder_down else SEEDER_LIFT, 0)
		_seeder.position = _seeder.position.lerp(goal, clampf(6.0 * delta, 0.0, 1.0))
	var running := driver != null
	if _beacon:
		_blink += delta
		_beacon.visible = not running or fmod(_blink, 0.6) < 0.35
	if running and _exhaust:
		_puff_timer -= delta
		if _puff_timer <= 0.0:
			_puff_timer = 0.5 - absf(speed) * 0.05
			Effects.burst(get_parent(), _exhaust.global_position, Color(0.35, 0.35, 0.38), 3)
