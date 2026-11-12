class_name Critter
extends CharacterBody3D
## Małe, niegroźne stworzenia łąki.
##   Pyłkowiec: latający zapylacz, krąży przy krzewach, ucieka przed graczem.
##     Ogłuszony spada i gubi kulkę pyłku (składnik Pyłkowych ciastek).
##   Chrupik: roślinożerca w stadku. Od Przebudzenia 25 objada dzikie krzewy
##     (konkurencja o jedzenie). Ucieka przed graczem, ogłuszony siedzi.

enum Kind { POLLENBUG, CHRUPIK }

const FLEE_RANGE := {Kind.POLLENBUG: 3.0, Kind.CHRUPIK: 4.5}
const SPEED := {Kind.POLLENBUG: 2.2, Kind.CHRUPIK: 2.0}
const FLEE_SPEED := {Kind.POLLENBUG: 5.5, Kind.CHRUPIK: 5.0}
const ROAM_RADIUS := {Kind.POLLENBUG: 4.0, Kind.CHRUPIK: 5.0}
const GRAZE_AWAKENING := 25.0
const GRAZE_RANGE := 14.0
const EAT_SECONDS := 2.0

var kind: Kind = Kind.CHRUPIK
## Środek terenu stworzenia; ustawiane przed dodaniem do sceny.
var home := Vector3.ZERO
var stunned_time := 0.0
## Pyłkowiec gubi pyłek tylko raz.
var has_pollen := true

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _target := Vector3.ZERO
var _retarget := 0.0
var _time := 0.0
var _eat_timer := 0.0
var _bush: WildBush
var _model: Node3D
var _wings: Array[Node3D] = []
var _stars: Label3D


func _ready() -> void:
	add_to_group("critter")
	collision_layer = 4
	collision_mask = 1
	if home == Vector3.ZERO:
		home = global_position
	var shape := SphereShape3D.new()
	shape.radius = 0.25 if kind == Kind.POLLENBUG else 0.35
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = shape.radius
	add_child(collision)
	_build_model()
	_time = randf() * TAU
	_pick_target()


func get_scan_info() -> Dictionary:
	if kind == Kind.POLLENBUG:
		return {"id": &"pollenbug", "name": "Pyłkowiec (zapylacz)"}
	return {"id": &"chrupik", "name": "Chrupik (roślinożerca)"}


func stun(seconds := 3.0) -> void:
	stunned_time = seconds
	_stars.visible = true
	_bush = null
	if kind == Kind.POLLENBUG and has_pollen:
		has_pollen = false
		_drop_pollen.call_deferred()


func is_stunned() -> bool:
	return stunned_time > 0.0


func _physics_process(delta: float) -> void:
	_time += delta
	if stunned_time > 0.0:
		stunned_time -= delta
		_stars.visible = stunned_time > 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		if kind == Kind.POLLENBUG:
			velocity.y = -3.0 if global_position.y > 0.3 else 0.0
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
	if player and away.length() < FLEE_RANGE[kind]:
		desired = away.normalized()
		speed = FLEE_SPEED[kind]
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
	if kind == Kind.POLLENBUG:
		var hover := 1.7 + sin(_time * 1.7) * 0.35
		velocity.y = (hover - global_position.y) * 3.0
	else:
		velocity.y -= _gravity * delta
	move_and_slide()
	if desired.length_squared() > 0.01:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-desired.x, -desired.z), clampf(delta * 8.0, 0.0, 1.0))
	_animate(delta, false)


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
		"scan_name": "Pyłkowiec", "color": Color(1.0, 0.85, 0.25)})
	get_parent().add_child(pickup)
	pickup.global_position = Vector3(global_position.x + 0.4, 0.0, global_position.z)


func _animate(_delta: float, stunned: bool) -> void:
	if kind == Kind.POLLENBUG:
		var flap := 0.2 if stunned else sin(_time * 40.0) * 0.6
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
	if kind == Kind.POLLENBUG:
		_build_pollenbug()
	else:
		_build_chrupik()
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
