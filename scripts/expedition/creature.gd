class_name Creature
extends CharacterBody3D
## Thornback: drapieżnik z kolcami na grzbiecie.
## Przebudzenie < 50: śpi w legowisku, atakuje tylko, gdy podejdziesz za blisko.
## Przebudzenie 50+: patroluje okolicę. 100: poluje na gracza wszędzie.
## Ogłuszacz i Snapper go zatrzymują; potem ucieka (nie ginie).

enum State { SLEEP, WANDER, CHASE, WINDUP, STUNNED, TRAPPED, FLEE }

@export var walk_speed := 2.4
@export var run_speed := 5.4
@export var attack_damage := 15.0
@export var attack_range := 1.8
@export var wake_range := 3.5

## Środek terytorium; ustawiane przed dodaniem do sceny.
var den_position := Vector3.ZERO
var state: State = State.SLEEP

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _timer := 0.0
var _attack_cooldown := 0.0
var _wander_target := Vector3.ZERO
var _time := 0.0
var _model: Node3D
var _body: Node3D
var _eye_material: StandardMaterial3D
var _zzz: Label3D
var _stars: Label3D


func _ready() -> void:
	add_to_group("creature")
	collision_layer = 4
	collision_mask = 1
	if den_position == Vector3.ZERO:
		den_position = global_position
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.55
	add_child(collision)
	_build_model()
	_set_state(State.SLEEP)


func get_scan_info() -> Dictionary:
	return {"id": &"thornback", "name": "Thornback (drapieżnik)"}


func state_name() -> String:
	return State.keys()[state]


# --- Reakcje na gracza -------------------------------------------------------

func stun(seconds := 3.0) -> void:
	_set_state(State.STUNNED)
	_timer = seconds
	Sfx.play(&"stun", global_position)


## Zwraca false, jeśli już jest złapany.
func trap(seconds := 4.0) -> bool:
	if state == State.TRAPPED:
		return false
	_set_state(State.TRAPPED)
	_timer = seconds
	return true


# --- Zachowanie --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_time += delta
	_timer -= delta
	_attack_cooldown -= delta
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var awakening := GameState.run.awakening if GameState.run else 0.0
	var player := get_tree().get_first_node_in_group("player") as Player
	var distance := INF
	if player:
		distance = _flat(player.global_position - global_position).length()

	var move := Vector3.ZERO
	var speed := 0.0
	match state:
		State.SLEEP:
			if awakening >= 50.0:
				_set_state(State.WANDER)
			elif distance < wake_range:
				_alert()
		State.WANDER:
			if _flat(_wander_target - global_position).length() < 0.8 or _timer <= 0.0:
				_pick_wander_target(awakening)
			move = _flat(_wander_target - global_position)
			speed = walk_speed
			if distance < _detect_range(awakening):
				_alert()
		State.CHASE:
			move = _flat(player.global_position - global_position) if player else Vector3.ZERO
			speed = run_speed * (1.2 if awakening >= 100.0 else 1.0)
			if distance < attack_range and _attack_cooldown <= 0.0:
				_set_state(State.WINDUP)
				_timer = 0.35
			elif distance > 18.0 and awakening < 100.0:
				_set_state(State.WANDER)
		State.WINDUP:
			if _timer <= 0.0:
				if player and distance < attack_range + 0.6:
					player.take_damage(attack_damage, global_position)
					Sfx.play(&"bite", global_position)
				_attack_cooldown = 1.3
				_set_state(State.CHASE)
		State.STUNNED, State.TRAPPED:
			if _timer <= 0.0:
				_set_state(State.FLEE)
				_timer = 3.0
		State.FLEE:
			move = _flat(global_position - player.global_position) if player else Vector3.ZERO
			speed = run_speed * 0.8
			if _timer <= 0.0:
				_set_state(State.WANDER)

	var target_velocity := move.normalized() * speed
	velocity.x = lerpf(velocity.x, target_velocity.x, clampf(delta * 8.0, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, target_velocity.z, clampf(delta * 8.0, 0.0, 1.0))
	move_and_slide()
	_animate(delta, move, speed)


func _alert() -> void:
	_set_state(State.CHASE)
	Sfx.play(&"roar", global_position)


func _detect_range(awakening: float) -> float:
	if awakening >= 100.0:
		return 999.0
	return 10.0 if awakening >= 50.0 else 5.0


func _pick_wander_target(awakening: float) -> void:
	var radius := 18.0 if awakening >= 50.0 else 6.0
	var angle := randf() * TAU
	_wander_target = den_position + Vector3(cos(angle), 0, sin(angle)) * randf_range(radius * 0.3, radius)
	_timer = 7.0


func _set_state(new_state: State) -> void:
	state = new_state
	if _model == null:
		return
	_zzz.visible = state == State.SLEEP
	_stars.visible = state == State.STUNNED or state == State.TRAPPED
	var eye := Color(1, 0.25, 0.2)
	match state:
		State.SLEEP:
			eye = Color(0.3, 0.25, 0.4)
		State.WANDER, State.FLEE:
			eye = Color(1, 0.8, 0.3)
		State.STUNNED, State.TRAPPED:
			eye = Color(1, 1, 0.5)
	_eye_material.albedo_color = eye
	_eye_material.emission = eye


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- Wygląd ------------------------------------------------------------------

func _animate(delta: float, move: Vector3, speed: float) -> void:
	if move.length_squared() > 0.01:
		var target_yaw := atan2(-move.x, -move.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, clampf(delta * 8.0, 0.0, 1.0))
	var moving := speed > 0.1 and move.length_squared() > 0.01
	match state:
		State.SLEEP:
			_body.position.y = sin(_time * 1.5) * 0.03
			_body.scale = Vector3(1, 0.92 + sin(_time * 1.5) * 0.04, 1)
		State.WINDUP:
			_body.scale = Vector3(1.1, 0.85, 1.1)
		State.STUNNED, State.TRAPPED:
			_body.rotation.z = sin(_time * 12.0) * 0.12
			_stars.rotation.y += delta * 4.0
		_:
			_body.rotation.z = 0.0
			_body.scale = Vector3.ONE
			_body.position.y = absf(sin(_time * (14.0 if speed > walk_speed else 8.0))) * (0.12 if moving else 0.0)
	_zzz.position.y = 1.5 + fmod(_time * 0.4, 0.5)


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	_body = Node3D.new()
	_model.add_child(_body)
	var fur := Color(0.36, 0.22, 0.48)
	var spine := Color(1.0, 0.55, 0.2)
	_eye_material = StandardMaterial3D.new()
	_eye_material.emission_enabled = true
	_eye_material.emission_energy_multiplier = 1.5

	# Tułów (wydłużona kula) i głowa z oczami; model patrzy w -Z.
	var torso := _add(_body, _sphere(0.5, 0.8), Vector3(0, 0.62, 0), fur)
	torso.scale = Vector3(1.0, 1.0, 1.5)
	_add(_body, _sphere(0.36, 0.62), Vector3(0, 0.8, -0.78), fur.lightened(0.08))
	_add(_body, _sphere(0.2, 0.22), Vector3(0, 0.68, -1.05), fur.lightened(0.25))
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = _sphere(0.08, 0.16)
		eye.position = Vector3(0.15 * side, 0.93, -1.02)
		eye.material_override = _eye_material
		_body.add_child(eye)
		_add(_body, _cone(0.08, 0.22, 4), Vector3(0.2 * side, 1.12, -0.7), spine, Vector3(0, 0, -0.4 * side))
	# Kolce na grzbiecie.
	for i in 5:
		var z := -0.45 + i * 0.25
		_add(_body, _cone(0.1, 0.38 - absf(i - 2) * 0.05, 4), Vector3(0, 1.05 - absf(i - 2) * 0.04, z), spine, Vector3(0.25, 0, 0))
	# Nogi i ogon.
	for x in [-0.3, 0.3]:
		for z in [-0.45, 0.45]:
			_add(_body, _cylinder(0.08, 0.45), Vector3(x, 0.22, z), fur.darkened(0.25))
	_add(_body, _cone(0.12, 0.6, 5), Vector3(0, 0.7, 0.95), fur, Vector3(-1.2, 0, 0))

	_zzz = Label3D.new()
	_zzz.text = "z Z z"
	_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_zzz.font_size = 56
	_zzz.pixel_size = 0.008
	_zzz.modulate = Color(0.7, 0.85, 1.0)
	_zzz.outline_size = 10
	_zzz.position = Vector3(0, 1.5, -0.6)
	add_child(_zzz)

	_stars = Label3D.new()
	_stars.text = "* * *"
	_stars.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_stars.font_size = 72
	_stars.pixel_size = 0.008
	_stars.modulate = Color(1, 0.95, 0.4)
	_stars.outline_size = 10
	_stars.position = Vector3(0, 1.45, -0.7)
	add_child(_stars)


func _add(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
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
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 0.8
	mesh.height = height
	mesh.radial_segments = 6
	return mesh


static func _cone(radius: float, height: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return mesh
