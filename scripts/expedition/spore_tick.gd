class_name SporeTick
extends ForestCreature
## Spore Tick: kleszcz z odwłokiem pełnym świecących woreczków zarodników.
## Chodzi także po stromych ścianach (kanion, doły, uskoki) i z 6 m skacze na gracza.
## Trafienie: małe obrażenia + duża dawka zarodników (halucynacje; Spore Mask chroni).
## Słaby (2 strzały), najłatwiej zestrzelić go w locie. Przy śmierci pęka fioletowym puffem.

const MODEL := preload("res://art/models/forest/spore_tick.glb")
const SPEED := 3.6
const LEAP_RANGE := 6.0
const LEAP_SPEED := 10.0
const BITE_DAMAGE := 6.0
const COOLDOWN := 1.6

var leaps := 0
var hits := 0

var _t := 0.0
var _cooldown := 1.0
var _airborne := false
var _leap_hit := false


func _ready() -> void:
	max_health = 15.0
	super._ready()
	floor_max_angle = deg_to_rad(80.0)  # wspina się po ścianach
	floor_snap_length = 0.8


func scan_id() -> StringName:
	return &"spore_tick"


func scan_name() -> String:
	return "Spore Tick"


func _build() -> void:
	var shape := SphereShape3D.new()
	shape.radius = 0.4
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.4
	add_child(collision)
	_model = MODEL.instantiate() as Node3D
	add_child(_model)
	ForestProps.apply(_model, "spore_tick")


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_status(delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if dead:
		velocity = Vector3(0, minf(velocity.y, 0.0), 0)
		move_and_slide()
		return
	_cooldown -= delta
	var player := _player()
	var move := Vector3.ZERO
	if _airborne:
		if not _leap_hit and player and player.global_position.distance_to(global_position) < 1.1:
			_leap_hit = true
			if _hurt(player, BITE_DAMAGE):
				hits += 1
				GameState.learn(&"spore_tick", "bite")
				_dose()
		if is_on_floor() and velocity.y <= 0.0:
			_airborne = false
			_cooldown = COOLDOWN
		move_and_slide()
		return
	if player and not is_stunned():
		var to := player.global_position - global_position
		var flat := _flat(to)
		if flat.length() > 0.05:
			rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), minf(delta * 10.0, 1.0))
		if flat.length() < LEAP_RANGE and _cooldown <= 0.0 and is_on_floor():
			# Skok po łuku w miejsce gracza.
			var dir := flat.normalized()
			velocity = dir * LEAP_SPEED * clampf(flat.length() / LEAP_RANGE, 0.5, 1.0) + Vector3(0, 5.0 + maxf(to.y, 0.0) * 1.2, 0)
			_airborne = true
			_leap_hit = false
			leaps += 1
			Sfx.play(&"bite", global_position)
			move_and_slide()
			return
		move = flat.normalized() * SPEED
	velocity.x = move.x
	velocity.z = move.z
	move_and_slide()
	# Chód: drobny podryg.
	if _model and _flash_t <= 0.0:
		_model.position.y = absf(sin(_t * 18.0)) * 0.04 * clampf(move.length() / SPEED, 0.0, 1.0)


## Dawka zarodników dla gracza (halucynacje).
func _dose(amount := 0.25) -> void:
	var h := get_tree().get_first_node_in_group("hallucination") as Hallucination
	if h:
		h.add(amount)


func _death_effect() -> void:
	Effects.burst(get_parent(), global_position + Vector3(0, 0.4, 0), Color(0.75, 0.4, 1.0), 26)
	var player := _player()
	if player and player.global_position.distance_to(global_position) < 2.5:
		_dose(0.12)
