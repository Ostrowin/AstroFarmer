class_name Critter
extends CharacterBody3D
## Małe, niegroźne stworzenia łąki.
##   Pyłkowiec: latający zapylacz, krąży przy krzewach, ucieka przed graczem.
##     Ogłuszony spada i gubi kulkę pyłku (składnik Pyłkowych ciastek).
##   Chrupik: roślinożerca w stadku. Od Przebudzenia 25 objada dzikie krzewy
##     (konkurencja o jedzenie). Ucieka przed graczem, ogłuszony siedzi.
## Pistolet: trafiony Pyłkowiec spada i gubi pyłek, Chrupik ucieka w panice.
## Przy 0 zdrowia giną: Pyłkowiec zostawia pyłek (jeśli go jeszcze miał),
## Chrupik nawóz.
## Nocne (widoczne tylko po zmroku; Pyłkowce wtedy śpią i znikają):
##   Świetlik-ćma: leci do latarki na hełmie i krąży wokół gracza.
##     Trafiona spada i gubi Lumen Dust.
##   Meduzowiec: dryfuje nisko nad łąką, macki parzą z bliska. Zestrzelony
##     pęka i zostawia Lumen Dust.

signal killed(critter: Critter)

enum Kind { POLLENBUG, CHRUPIK, LUMIMOTH, DRIFTER }

const FLEE_RANGE := {Kind.POLLENBUG: 3.0, Kind.CHRUPIK: 4.5, Kind.LUMIMOTH: 0.0, Kind.DRIFTER: 0.0}
const SPEED := {Kind.POLLENBUG: 2.2, Kind.CHRUPIK: 2.0, Kind.LUMIMOTH: 3.2, Kind.DRIFTER: 0.7}
const FLEE_SPEED := {Kind.POLLENBUG: 5.5, Kind.CHRUPIK: 5.0, Kind.LUMIMOTH: 3.2, Kind.DRIFTER: 0.7}
const ROAM_RADIUS := {Kind.POLLENBUG: 4.0, Kind.CHRUPIK: 5.0, Kind.LUMIMOTH: 5.0, Kind.DRIFTER: 6.0}
const HOVER := {Kind.POLLENBUG: 1.7, Kind.LUMIMOTH: 2.2, Kind.DRIFTER: 2.6}
## Ćma widzi latarkę z tej odległości i krąży wokół gracza w tym promieniu.
const MOTH_SIGHT := 16.0
const MOTH_ORBIT := 1.6
## Meduzowiec parzy gracza bliżej niż STING_RANGE, raz na STING_COOLDOWN s.
const STING_RANGE := 1.4
const STING_DAMAGE := 8.0
const STING_COOLDOWN := 1.5
const GRAZE_AWAKENING := 25.0
const GRAZE_RANGE := 14.0
const EAT_SECONDS := 2.0
const MAX_HEALTH := {Kind.POLLENBUG: 10.0, Kind.CHRUPIK: 20.0, Kind.LUMIMOTH: 10.0, Kind.DRIFTER: 30.0}
const PANIC_SECONDS := 3.0
## Modele z Blendera; brak pliku = model z brył.
const MODELS := {
	Kind.POLLENBUG: preload("res://art/models/creatures/pollenbug.glb"),
	Kind.CHRUPIK: preload("res://art/models/creatures/muncher.glb"),
	Kind.LUMIMOTH: preload("res://art/models/creatures/lumimoth.glb"),
	Kind.DRIFTER: preload("res://art/models/creatures/drifter.glb"),
}

var kind: Kind = Kind.CHRUPIK
## Środek terenu stworzenia; ustawiane przed dodaniem do sceny.
var home := Vector3.ZERO
var stunned_time := 0.0
## Pyłkowiec gubi pyłek tylko raz.
var has_pollen := true
var health := 10.0
var _panic := 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _target := Vector3.ZERO
var _retarget := 0.0
var _time := 0.0
var _eat_timer := 0.0
var _bush: WildBush
var _model: Node3D
var _wings: Array[Node3D] = []
var _stars: Label3D
var _sting_cooldown := 0.0
var _bell: Node3D
var _tentacles: Node3D
var _active := true


func _ready() -> void:
	add_to_group("critter")
	collision_layer = 4
	collision_mask = 1
	if home == Vector3.ZERO:
		home = global_position
	var shape := SphereShape3D.new()
	shape.radius = {Kind.POLLENBUG: 0.25, Kind.CHRUPIK: 0.35, Kind.LUMIMOTH: 0.35, Kind.DRIFTER: 0.55}[kind]
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = shape.radius
	add_child(collision)
	health = MAX_HEALTH[kind]
	_build_model()
	_time = randf() * TAU
	_pick_target()


func get_scan_info() -> Dictionary:
	match kind:
		Kind.POLLENBUG:
			return {"id": &"pollenbug", "name": "Pollenbug"}
		Kind.LUMIMOTH:
			return {"id": &"lumimoth", "name": "Lumimoth"}
		Kind.DRIFTER:
			return {"id": &"drifter", "name": "Drifter"}
	return {"id": &"chrupik", "name": "Muncher"}


## Latające stworzenia (unoszą się, ogłuszone opadają).
func is_flying() -> bool:
	return kind != Kind.CHRUPIK


## Nocne stworzenia działają tylko po zmroku, Pyłkowce tylko w dzień.
func is_night_creature() -> bool:
	return kind == Kind.LUMIMOTH or kind == Kind.DRIFTER


func _should_be_active() -> bool:
	var night := GameState.night_amount(GameState.time_of_day) > 0.5
	if is_night_creature():
		return night
	if kind == Kind.POLLENBUG:
		return not night
	return true


func _set_active(active: bool) -> void:
	_active = active
	visible = active
	collision_layer = 4 if active else 0
	if active:
		add_to_group("critter")
	else:
		remove_from_group("critter")


func stun(seconds := 3.0) -> void:
	stunned_time = seconds
	_stars.visible = true
	_bush = null
	if kind == Kind.POLLENBUG and has_pollen:
		has_pollen = false
		_drop_pollen.call_deferred()
	elif kind == Kind.LUMIMOTH and has_pollen:
		has_pollen = false
		_drop_dust.call_deferred()


func is_stunned() -> bool:
	return stunned_time > 0.0


## Trafienie z pistoletu. Zwraca true, jeśli stworzenie zginęło.
func take_hit(amount: float, _from := Vector3.INF) -> bool:
	if health <= 0.0:
		return false
	health -= amount
	if health <= 0.0:
		_die()
		return true
	if kind == Kind.POLLENBUG or kind == Kind.LUMIMOTH:
		stun(1.5)
	elif kind == Kind.DRIFTER:
		pass
	else:
		_panic = PANIC_SECONDS
		_bush = null
	_model.scale = Vector3(1.3, 0.7, 1.3)
	create_tween().tween_property(_model, "scale", Vector3.ONE, 0.25)
	return false


func _die() -> void:
	remove_from_group("critter")
	collision_layer = 0
	set_physics_process(false)
	Sfx.play(&"death", global_position, 0.2)
	var color: Color = {Kind.POLLENBUG: Color(1.0, 0.82, 0.25), Kind.CHRUPIK: Color(0.55, 0.62, 0.35),
		Kind.LUMIMOTH: Color(0.45, 0.85, 1.0), Kind.DRIFTER: Color(0.7, 0.55, 1.0)}[kind]
	Effects.burst(get_parent(), global_position + Vector3(0, 0.3, 0), color, 20)
	if kind == Kind.POLLENBUG and has_pollen:
		has_pollen = false
		_drop_pollen.call_deferred()
	elif kind == Kind.CHRUPIK:
		_drop_fertilizer.call_deferred()
	elif kind == Kind.DRIFTER or (kind == Kind.LUMIMOTH and has_pollen):
		has_pollen = false
		_drop_dust.call_deferred()
	killed.emit(self)
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(queue_free)


func _drop_fertilizer() -> void:
	var pickup := Pickup.new()
	pickup.setup({"kind": "sample", "item": &"fertilizer", "amount": 1, "color": RaidMarks.FERTILIZER_COLOR.lightened(0.3)})
	get_parent().add_child(pickup)
	pickup.global_position = Vector3(global_position.x, 0.0, global_position.z)


func _drop_dust() -> void:
	var pickup := Pickup.new()
	pickup.setup(Pickup.entry_for(&"lumen_dust"))
	get_parent().add_child(pickup)
	pickup.global_position = Vector3(global_position.x + 0.3, 0.0, global_position.z)


func _physics_process(delta: float) -> void:
	_time += delta
	var should := _should_be_active()
	if should != _active and health > 0.0:
		_set_active(should)
	if not _active:
		return
	if stunned_time > 0.0:
		stunned_time -= delta
		_stars.visible = stunned_time > 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		if kind == Kind.POLLENBUG or kind == Kind.LUMIMOTH:
			velocity.y = -3.0 if global_position.y > 0.3 else 0.0
		elif kind == Kind.DRIFTER:
			velocity.y = (1.2 - global_position.y) * 2.0
		else:
			velocity.y -= _gravity * delta
		move_and_slide()
		_animate(delta, true)
		return

	var desired := Vector3.ZERO
	var speed: float = SPEED[kind]
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var away := Vector3.ZERO
	if player:
		away = global_position - player.global_position
		away.y = 0.0
	_panic = maxf(0.0, _panic - delta)
	_sting_cooldown = maxf(0.0, _sting_cooldown - delta)
	if kind == Kind.DRIFTER and player:
		_try_sting(player as Player, away)
	if kind == Kind.LUMIMOTH and player and _sees_light(player as Player, away):
		# Krąży wokół głowy gracza (do światła latarki).
		var orbit := player.global_position + Vector3(cos(_time * 1.6), 0, sin(_time * 1.6)) * MOTH_ORBIT
		var to_orbit := orbit - global_position
		to_orbit.y = 0.0
		desired = to_orbit.normalized() if to_orbit.length() > 0.2 else Vector3.ZERO
		speed = SPEED[kind] * clampf(to_orbit.length(), 0.5, 1.6)
	elif player and (away.length() < FLEE_RANGE[kind] or _panic > 0.0):
		desired = away.normalized()
		speed = FLEE_SPEED[kind] * (1.3 if _panic > 0.0 else 1.0)
		_bush = null
	else:
		if kind == Kind.CHRUPIK:
			_update_grazing(delta)
		_retarget -= delta
		var goal := _bush.global_position if _bush else _target
		var to_goal := goal - global_position
		to_goal.y = 0.0
		if _retarget <= 0.0 or (to_goal.length() < 0.5 and _bush == null):
			_pick_target()
		if to_goal.length() > (1.0 if _bush else 0.3):
			desired = to_goal.normalized()

	velocity.x = desired.x * speed
	velocity.z = desired.z * speed
	if is_flying():
		var hover: float = HOVER[kind] + sin(_time * (0.8 if kind == Kind.DRIFTER else 1.7)) * 0.35
		velocity.y = (hover - global_position.y) * 3.0
	else:
		velocity.y -= _gravity * delta
	move_and_slide()
	if desired.length_squared() > 0.01:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-desired.x, -desired.z), clampf(delta * 8.0, 0.0, 1.0))
	_animate(delta, false)


func _sees_light(player: Player, away: Vector3) -> bool:
	return player.flashlight != null and player.flashlight.visible and away.length() < MOTH_SIGHT


func _try_sting(player: Player, away: Vector3) -> void:
	if _sting_cooldown > 0.0 or away.length() > STING_RANGE:
		return
	_sting_cooldown = STING_COOLDOWN
	player.take_damage(STING_DAMAGE, global_position)
	GameState.learn(&"drifter", "sting")


## Chrupik: gdy łąka się budzi, idzie do najbliższego dzikiego krzewu i go objada.
func _update_grazing(delta: float) -> void:
	var run := GameState.run
	if run == null or run.awakening < GRAZE_AWAKENING:
		_bush = null
		return
	if _bush == null or _bush.eaten or not is_instance_valid(_bush):
		_bush = _nearest_bush()
		_eat_timer = EAT_SECONDS
		return
	var offset := _bush.global_position - global_position
	if Vector2(offset.x, offset.z).length() < 1.3:
		_eat_timer -= delta
		if _eat_timer <= 0.0:
			if _bush.eat():
				Sfx.play(&"eat", global_position)
			_bush = null


func _nearest_bush() -> WildBush:
	var best: WildBush = null
	var best_distance := GRAZE_RANGE
	for node in get_parent().get_children():
		var bush := node as WildBush
		if bush == null or bush.eaten:
			continue
		var distance := bush.global_position.distance_to(global_position)
		if distance < best_distance:
			best = bush
			best_distance = distance
	return best


func _pick_target() -> void:
	var radius: float = ROAM_RADIUS[kind]
	var angle := randf() * TAU
	_target = home + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(radius * 0.3, radius)
	_retarget = randf_range(2.0, 4.0)


func _drop_pollen() -> void:
	var pickup := Pickup.new()
	pickup.setup({"kind": "sample", "item": &"pollen", "amount": 1, "scan": &"pollenbug",
		"scan_name": "Pollenbug", "color": Color(1.0, 0.85, 0.25)})
	get_parent().add_child(pickup)
	pickup.global_position = Vector3(global_position.x + 0.4, 0.0, global_position.z)


func _animate(_delta: float, stunned: bool) -> void:
	if kind == Kind.DRIFTER:
		# Dzwon pulsuje, macki falują.
		var pulse := sin(_time * 2.0)
		if _bell:
			_bell.scale = Vector3(1.0 + pulse * 0.06, 1.0 - pulse * 0.1, 1.0 + pulse * 0.06)
		if _tentacles:
			_tentacles.rotation = Vector3(sin(_time * 1.3) * 0.08, _time * 0.2, cos(_time * 1.1) * 0.08)
		return
	if kind == Kind.POLLENBUG or kind == Kind.LUMIMOTH:
		var flap := 0.2 if stunned else sin(_time * (40.0 if kind == Kind.POLLENBUG else 14.0)) * 0.6
		for i in _wings.size():
			_wings[i].rotation.z = flap * (1.0 if i == 0 else -1.0)
		return
	# Chrupik podskakuje, gdy się rusza.
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3
	_model.position.y = absf(sin(_time * 12.0)) * 0.12 if moving and not stunned else 0.0


# --- Model -------------------------------------------------------------------

func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var scene: PackedScene = MODELS.get(kind)
	if scene:
		var model := scene.instantiate() as Node3D
		_model.add_child(model)
		for wing_name in ["WingL", "WingR"]:
			var wing := model.find_child(wing_name, true, false) as Node3D
			if wing:
				_wings.append(wing)
		_bell = model.find_child("Bell", true, false) as Node3D
		_tentacles = model.find_child("Tentacles", true, false) as Node3D
		_build_stars()
		return
	if kind == Kind.POLLENBUG:
		_build_pollenbug()
	else:
		_build_chrupik()
	_build_stars()


func _build_stars() -> void:
	_stars = Label3D.new()
	_stars.text = "* * *"
	_stars.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_stars.font_size = 48
	_stars.modulate = Color(1, 0.95, 0.4)
	_stars.position.y = 0.9
	_stars.visible = false
	add_child(_stars)


func _build_pollenbug() -> void:
	var yellow := Color(1.0, 0.82, 0.25)
	_mesh(_model, _sphere(0.18, 0.3), Vector3(0, 0.2, 0), yellow)
	_mesh(_model, _sphere(0.185, 0.08), Vector3(0, 0.2, 0.02), Color(0.25, 0.15, 0.2))
	_mesh(_model, _sphere(0.11, 0.2), Vector3(0, 0.25, -0.17), yellow.lightened(0.2))
	for side in [-1.0, 1.0]:
		_mesh(_model, _sphere(0.035, 0.07), Vector3(0.05 * side, 0.29, -0.26), Color(0.1, 0.05, 0.1))
		var wing := Node3D.new()
		wing.position = Vector3(0.1 * side, 0.32, 0)
		_model.add_child(wing)
		var wing_mesh := _mesh(wing, _sphere(0.16, 0.03), Vector3(0.12 * side, 0, 0), Color(0.85, 0.95, 1.0, 0.6))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.95, 1.0, 0.55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wing_mesh.material_override = mat
		_wings.append(wing)


func _build_chrupik() -> void:
	var fur := Color(0.55, 0.62, 0.35)
	_mesh(_model, _sphere(0.35, 0.6), Vector3(0, 0.32, 0), fur)
	_mesh(_model, _sphere(0.22, 0.3), Vector3(0, 0.3, -0.25), fur.lightened(0.15))
	for side in [-1.0, 1.0]:
		_mesh(_model, _sphere(0.07, 0.1), Vector3(0.12 * side, 0.45, -0.38), Color(1, 1, 0.95))
		_mesh(_model, _sphere(0.035, 0.05), Vector3(0.12 * side, 0.46, -0.44), Color(0.1, 0.05, 0.1))
		_mesh(_model, _sphere(0.08, 0.16), Vector3(0.2 * side, 0.62, -0.05), fur.darkened(0.15), Vector3(0, 0, -0.5 * side))
	# Wielkie siekacze: urocze i trochę straszne.
	var tooth := BoxMesh.new()
	tooth.size = Vector3(0.07, 0.11, 0.03)
	for side in [-1.0, 1.0]:
		_mesh(_model, tooth, Vector3(0.04 * side, 0.2, -0.46), Color(1, 0.98, 0.9))


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rot
	instance.material_override = PlantVisuals.material(color)
	parent.add_child(instance)
	return instance


static func _sphere(radius: float, height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 5
	return mesh
