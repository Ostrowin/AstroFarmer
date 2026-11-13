class_name Player
extends CharacterBody3D
## Postać gracza: ruch względem kamery, skok, kamera TPP za plecami
## (SpringArm3D, więc kamera nie przenika przez ściany) i Kondycja (zdrowie).
## Sterowanie jak w Risk of Rain 2: Ctrl włącza bieg (trwa, dopóki się ruszasz
## i nie strzelasz), Shift robi dash z czasem odnowienia.

signal health_changed(health: float, max_health: float)
signal died

@export var max_health := 100.0
@export var walk_speed := 5.0
@export var sprint_speed := 8.5
@export var jump_velocity := 5.5
@export var acceleration := 12.0
@export var turn_speed := 12.0
@export var dash_speed := 17.0
@export var dash_time := 0.18
@export var dash_cooldown := 2.0
@export var mouse_sensitivity := 0.0025
@export var min_pitch_deg := -70.0
@export var max_pitch_deg := 20.0

## Wyłączane np. podczas przejścia na wyprawę.
var input_enabled := true
## Kondycja: spada od ataków i burzy na wyprawie.
var health := 100.0
## Mnożnik prędkości (ulepszenie wyprawy "Turbo-buty").
var speed_multiplier := 1.0
## Bieg włączony Ctrl; gaśnie, gdy przestajesz się ruszać albo strzelasz.
var sprinting := false
## Ile sekund do kolejnego dasha (0 = gotowy).
var dash_cooldown_left := 0.0

var _dash_left := 0.0
var _dash_direction := Vector3.ZERO
## Po strzale postać przez chwilę patrzy tam, gdzie celuje kamera (jak w RoR2).
var _aim_time := 0.0
var _animator: PlayerAnimator

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _hurt_cooldown := 0.0

## PlayerInteraction w bazie, ExpeditionInteraction na wyprawie.
@onready var interaction: Node = $Interaction
@onready var camera: Camera3D = $CameraPivot/CameraPitch/SpringArm3D/Camera3D
@onready var _visual: Node3D = $Visual
@onready var _yaw: Node3D = $CameraPivot
@onready var _pitch: Node3D = $CameraPivot/CameraPitch
@onready var _spring_arm: SpringArm3D = $CameraPivot/CameraPitch/SpringArm3D


## Latarka na hełmie: świeci tam, gdzie patrzy gracz; włącza się o zmierzchu.
const FLASHLIGHT_ENERGY := 5.0
var flashlight: SpotLight3D


func _ready() -> void:
	health = max_health
	_build_flashlight()
	_spring_arm.add_excluded_object(get_rid())
	capture_mouse()
	var model := _visual.get_node_or_null("Model")
	if model:
		_animator = PlayerAnimator.new()
		_animator.name = "Animator"
		add_child(_animator)
		if not _animator.setup(model):
			_animator.queue_free()
			_animator = null


func _build_flashlight() -> void:
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.position = Vector3(0, 1.75, -0.3)
	flashlight.rotation.x = deg_to_rad(-10.0)
	flashlight.light_color = Color(1.0, 0.95, 0.82)
	flashlight.spot_range = 24.0
	flashlight.spot_angle = 30.0
	flashlight.spot_attenuation = 0.6
	flashlight.spot_angle_attenuation = 1.6
	flashlight.shadow_enabled = true
	_visual.add_child(flashlight)
	_update_flashlight()


func _update_flashlight() -> void:
	var night := GameState.night_amount(GameState.time_of_day)
	flashlight.visible = night > 0.05
	flashlight.light_energy = FLASHLIGHT_ENERGY * night


func _process(_delta: float) -> void:
	_update_flashlight()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and is_mouse_captured():
		var motion := event as InputEventMouseMotion
		_yaw.rotate_y(-motion.relative.x * mouse_sensitivity)
		_pitch.rotation.x = clampf(
			_pitch.rotation.x - motion.relative.y * mouse_sensitivity,
			deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and not is_mouse_captured():
		capture_mouse()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_hurt_cooldown -= delta
	if not is_on_floor():
		velocity.y -= _gravity * delta

	dash_cooldown_left = maxf(0.0, dash_cooldown_left - delta)
	var can_move := input_enabled and is_mouse_captured()
	if can_move and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input := Vector2.ZERO
	if can_move:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (Basis(Vector3.UP, _yaw.rotation.y) * Vector3(input.x, 0.0, input.y)).normalized()
	if can_move and Input.is_action_just_pressed("sprint"):
		sprinting = true
	if input.length_squared() < 0.01:
		sprinting = false
	if can_move and Input.is_action_just_pressed("dash"):
		dash(direction)

	if _dash_left > 0.0:
		_dash_left -= delta
		velocity.x = _dash_direction.x * dash_speed
		velocity.z = _dash_direction.z * dash_speed
	else:
		var speed := (sprint_speed if sprinting else walk_speed) * speed_multiplier
		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		horizontal = horizontal.lerp(direction * speed, clampf(acceleration * delta, 0.0, 1.0))
		velocity.x = horizontal.x
		velocity.z = horizontal.z
	move_and_slide()

	_aim_time = maxf(0.0, _aim_time - delta)
	if _aim_time > 0.0 and _dash_left <= 0.0:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, _yaw.rotation.y, clampf(turn_speed * 1.5 * delta, 0.0, 1.0))
	elif direction.length_squared() > 0.01:
		var target_yaw := atan2(-direction.x, -direction.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))
	if _animator:
		_animator.tick(delta, is_on_floor())
		_animator.update(self)


# --- Ruch specjalny ----------------------------------------------------------

## Dash w kierunku ruchu (bez wciśniętego kierunku: tam, gdzie patrzy kamera).
func dash(direction := Vector3.ZERO) -> bool:
	if dash_cooldown_left > 0.0:
		return false
	if direction.length_squared() < 0.01:
		direction = Basis(Vector3.UP, _yaw.rotation.y) * Vector3.FORWARD
	_dash_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	_dash_left = dash_time
	dash_cooldown_left = dash_cooldown
	_visual.rotation.y = atan2(-_dash_direction.x, -_dash_direction.z)
	_visual.scale = Vector3(0.8, 0.9, 1.3)
	create_tween().tween_property(_visual, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(&"dash", global_position)
	Effects.burst(get_parent(), global_position + Vector3(0, 0.2, 0), Color(0.85, 0.85, 0.9), 10)
	return true


func is_dashing() -> bool:
	return _dash_left > 0.0


## Strzał i inne akcje bojowe przerywają bieg (jak w RoR2).
func stop_sprint() -> void:
	sprinting = false


## Animacja strzału na górze ciała + obrót w stronę celowania.
func play_shoot() -> void:
	_aim_time = 0.8
	if _animator:
		_animator.shoot()


func animation_state() -> StringName:
	return _animator.state if _animator else &""


# --- Kondycja ----------------------------------------------------------------

## Obrażenia. `silent` = ciągłe obrażenia (burza): bez odrzutu, dźwięku i przerwy.
func take_damage(amount: float, from := Vector3.INF, silent := false) -> void:
	if health <= 0.0:
		return
	if not silent:
		if _hurt_cooldown > 0.0:
			return
		_hurt_cooldown = 0.5
		Sfx.play(&"hurt", global_position)
		if from != Vector3.INF:
			var push := global_position - from
			push.y = 0.0
			velocity += push.normalized() * 7.0 + Vector3.UP * 3.0
		_visual.scale = Vector3(1.25, 0.75, 1.25)
		create_tween().tween_property(_visual, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		died.emit()


## Odrzut bez obrażeń (np. Boomshroom w bazie).
func knockback(from: Vector3, force := 8.0) -> void:
	var push := global_position - from
	push.y = 0.0
	if push.length_squared() < 0.001:
		push = Vector3.BACK
	velocity += push.normalized() * force + Vector3.UP * force * 0.5
	_visual.scale = Vector3(1.2, 0.8, 1.2)
	create_tween().tween_property(_visual, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func heal(amount: float) -> void:
	if health <= 0.0:
		return
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)


func add_max_health(amount: float) -> void:
	max_health += amount
	heal(amount)


func is_mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
