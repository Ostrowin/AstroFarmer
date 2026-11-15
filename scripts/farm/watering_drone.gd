class_name WateringDrone
extends Node3D
## Dron nawadniający: startuje z doku, leci do spragnionej rośliny w zasięgu,
## podlewa ją mgiełką (woda ze zbiornika drona, nie z konewki), a z pustym
## zbiornikiem leci do stawu zatankować. Gdy nie ma pracy, wraca na dok.
## Stan drona nie jest zapisywany: po wczytaniu stoi na doku z pełnym zbiornikiem.

enum State { DOCKED, TO_PLANT, WATERING, TO_POND, REFILL, RETURN }

const MODEL := preload("res://art/models/machines/drone.glb")
## Pojemność zbiornika (1 = jedno podlanie).
const TANK := 6
## Zasięg pracy wokół doku (metry, w poziomie).
const RANGE := 14.0
const SPEED := 4.5
const CRUISE_HEIGHT := 2.6
const SPRAY_HEIGHT := 1.9
const WATER_TIME := 1.2
const REFILL_TIME := 1.6
## Co ile sekund dron na doku szuka pracy.
const SCAN_INTERVAL := 1.0
const WATER_COLOR := Color(0.55, 0.85, 1.0)

## Rośliny, do których leci już jakiś dron (instance id -> true).
static var _claimed := {}

var farm: Farm
var dock: DroneDock
var state := State.DOCKED
var water := TANK

var _target: Plant
var _timer := 0.0
var _rotor_speed := 0.0
var _velocity := Vector3.ZERO
var _model: Node3D
var _rotors: Array[Node3D] = []
var _rotor_axes: Array[Vector3] = []
var _tank_water: Node3D
var _spray: Node3D
var _drops: CPUParticles3D
var _bob := randf() * TAU


func _ready() -> void:
	top_level = true
	_model = MODEL.instantiate()
	add_child(_model)
	for i in 4:
		var rotor := _model.find_child("Rotor%d" % i, true, false) as Node3D
		if rotor:
			_rotors.append(rotor)
			_rotor_axes.append((rotor.global_basis.inverse() * global_basis.y).normalized())
	_tank_water = _model.find_child("TankWater", true, false) as Node3D
	_build_spray()
	if dock:
		global_position = dock.landing_point()
	_update_tank()


func _exit_tree() -> void:
	_release()


func _physics_process(delta: float) -> void:
	if dock == null or farm == null:
		return
	match state:
		State.DOCKED:
			_timer -= delta
			global_position = dock.landing_point()
			if _timer <= 0.0:
				_timer = SCAN_INTERVAL
				_next_job()
		State.TO_PLANT:
			if not _target_valid():
				_release()
				_next_job()
			elif _fly_to(_target.global_position + Vector3(0, SPRAY_HEIGHT, 0), delta):
				state = State.WATERING
				_timer = WATER_TIME
				_set_spraying(true)
		State.WATERING:
			_hover(delta)
			_timer -= delta
			if _timer <= 0.0:
				_set_spraying(false)
				if _target_valid() and farm.drone_water(_target):
					water -= 1
					_update_tank()
					Sfx.play(&"water", _target.global_position)
					Effects.burst(farm, _target.global_position + Vector3(0, 0.4, 0), WATER_COLOR, 10)
				_release()
				_next_job()
		State.TO_POND:
			var pond := _pond_point()
			if pond == Vector3.INF:
				state = State.RETURN
			elif _fly_to(pond, delta):
				state = State.REFILL
				_timer = REFILL_TIME
		State.REFILL:
			_hover(delta)
			_timer -= delta
			if _timer <= 0.0:
				water = TANK
				_update_tank()
				Sfx.play(&"fill", global_position)
				Effects.burst(farm, global_position - Vector3(0, 1.0, 0), WATER_COLOR, 12)
				_next_job()
		State.RETURN:
			if _fly_to(dock.landing_point(), delta, true):
				state = State.DOCKED
				_velocity = Vector3.ZERO
				_timer = SCAN_INTERVAL
	_animate(delta)


func state_text() -> String:
	match state:
		State.DOCKED:
			return "idle"
		State.TO_PLANT, State.WATERING:
			return "watering"
		State.TO_POND, State.REFILL:
			return "refilling"
	return "returning"


# --- Decyzje -----------------------------------------------------------------

func _next_job() -> void:
	var plant := _find_thirsty()
	if plant == null:
		if state != State.DOCKED:
			state = State.RETURN
		return
	if water <= 0:
		state = State.TO_POND
		return
	_target = plant
	_claimed[plant.get_instance_id()] = true
	state = State.TO_PLANT


## Najbliższa spragniona roślina w zasięgu doku, do której nie leci inny dron.
## Nasiona-zagadki (Misty Water) zostają dla gracza.
func _find_thirsty() -> Plant:
	var best: Plant = null
	var best_distance := INF
	for plant in farm.plants():
		if not is_instance_valid(plant) or not plant.is_thirsty() or plant.needs_sprout_item():
			continue
		if _claimed.has(plant.get_instance_id()):
			continue
		if _flat(plant.global_position, dock.global_position) > RANGE:
			continue
		var distance := _flat(plant.global_position, global_position)
		if distance < best_distance:
			best_distance = distance
			best = plant
	return best


func _target_valid() -> bool:
	return is_instance_valid(_target) and _target.is_inside_tree() and _target.is_thirsty()


func _release() -> void:
	if is_instance_valid(_target):
		_claimed.erase(_target.get_instance_id())
	_target = null


## Punkt nad najbliższym stawem (grupa "water"), od strony doku.
func _pond_point() -> Vector3:
	var best := Vector3.INF
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("water"):
		var body := node as Node3D
		if body == null:
			continue
		var distance := _flat(body.global_position, global_position)
		if distance < best_distance:
			best_distance = distance
			best = body.global_position + Vector3(0, 1.3, 0)
	return best


# --- Lot ---------------------------------------------------------------------

## Leci do punktu na wysokości przelotowej, na końcu zniża się. True = na miejscu.
func _fly_to(point: Vector3, delta: float, landing := false) -> bool:
	var flat := Vector3(point.x - global_position.x, 0, point.z - global_position.z)
	var far := flat.length() > 0.6
	var height := maxf(point.y, CRUISE_HEIGHT) if far else point.y
	var goal := Vector3(point.x, height, point.z)
	var to_goal := goal - global_position
	var speed := SPEED if far else SPEED * 0.5
	var wanted := to_goal.limit_length(speed) if to_goal.length() > 0.05 else Vector3.ZERO
	if not far and not landing:
		wanted = to_goal * 3.0
	_velocity = _velocity.lerp(wanted, clampf(4.0 * delta, 0.0, 1.0))
	global_position += _velocity * delta
	if flat.length_squared() > 0.04:
		var yaw := atan2(-flat.x, -flat.z)
		rotation.y = lerp_angle(rotation.y, yaw, clampf(5.0 * delta, 0.0, 1.0))
	return not far and to_goal.length() < 0.12


func _hover(delta: float) -> void:
	_velocity = _velocity.lerp(Vector3.ZERO, clampf(5.0 * delta, 0.0, 1.0))
	global_position += _velocity * delta


func _animate(delta: float) -> void:
	var flying := state != State.DOCKED
	_rotor_speed = move_toward(_rotor_speed, 40.0 if flying else 0.0, delta * (60.0 if flying else 25.0))
	for i in _rotors.size():
		_rotors[i].rotate_object_local(_rotor_axes[i], _rotor_speed * delta * (1.0 if i % 2 == 0 else -1.0))
	# Przechył w stronę lotu i lekkie kołysanie w zawisie.
	var local_velocity := global_basis.inverse() * _velocity
	var tilt := Vector3(clampf(-local_velocity.z * 0.06, -0.3, 0.3), 0, clampf(local_velocity.x * 0.06, -0.3, 0.3))
	_model.rotation.x = lerp_angle(_model.rotation.x, -tilt.x, clampf(6.0 * delta, 0.0, 1.0))
	_model.rotation.z = lerp_angle(_model.rotation.z, -tilt.z, clampf(6.0 * delta, 0.0, 1.0))
	if flying:
		_bob += delta * 3.0
		_model.position.y = sin(_bob) * 0.05
	else:
		_model.position.y = move_toward(_model.position.y, 0.0, delta)


# --- Wygląd ------------------------------------------------------------------

func _update_tank() -> void:
	if _tank_water:
		_tank_water.scale = Vector3(1, maxf(float(water) / TANK, 0.02), 1)


func _build_spray() -> void:
	_spray = Node3D.new()
	add_child(_spray)
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.03
	mesh.bottom_radius = 0.45
	mesh.height = SPRAY_HEIGHT - 0.5
	mesh.radial_segments = 16
	mesh.cap_top = false
	mesh.cap_bottom = false
	cone.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(WATER_COLOR, 0.22)
	cone.material_override = material
	cone.position.y = -0.5 - mesh.height * 0.5
	_spray.add_child(cone)
	_drops = CPUParticles3D.new()
	_drops.amount = 40
	_drops.lifetime = 0.5
	_drops.direction = Vector3.DOWN
	_drops.spread = 20.0
	_drops.initial_velocity_min = 2.5
	_drops.initial_velocity_max = 3.5
	_drops.gravity = Vector3(0, -9.8, 0)
	var drop := SphereMesh.new()
	drop.radius = 0.025
	drop.height = 0.05
	drop.radial_segments = 4
	drop.rings = 2
	_drops.mesh = drop
	_drops.material_override = PlantVisuals.material(WATER_COLOR, 0.6)
	_drops.position.y = -0.5
	_drops.emitting = false
	_spray.add_child(_drops)
	_spray.visible = false


func _set_spraying(on: bool) -> void:
	_spray.visible = on
	_drops.emitting = on


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
