class_name RotThornback
extends ForestCreature
## Rot Thornback: Thornback zarażony grzybnią (narośla na grzbiecie, zgniły odcień).
## Idzie powoli w stronę gracza; bliżej niż 14 m zatrzymuje się, grzebie łapą (0,8 s ostrzeżenia)
## i szarżuje prosto przed siebie. Trafienie w szarży: 18 obrażeń i odrzut. Po szarży chwilę
## dyszy (dobry moment na strzały). Snapper go łapie, Boomshroom ogłusza. Wytrzymuje 7 strzałów.
## Przy śmierci narośle pękają chmurą zarodników.

enum State { STALK, WINDUP, CHARGE, RECOVER }

const BODY := preload("res://art/models/creatures/thornback.glb")
const GROWTHS := preload("res://art/models/forest/rot_growths.glb")
const WALK := 2.4
const CHARGE_SPEED := 11.0
const CHARGE_TIME := 1.1
const WINDUP_TIME := 0.8
const RECOVER_TIME := 1.6
const DAMAGE := 18.0
const ROT_TINT := Color(0.6, 0.68, 0.45)

var state: State = State.STALK
var charges := 0

var _t := 0.0
var _timer := 0.0
var _dir := Vector3.FORWARD
var _hit := false
var _anim: AnimationPlayer


func _ready() -> void:
	max_health = 70.0
	super._ready()
	floor_snap_length = 0.6


func scan_id() -> StringName:
	return &"rot_thornback"


func scan_name() -> String:
	return "Rot Thornback"


func _build() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.6
	shape.height = 1.4
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.7
	collision.rotation.x = PI / 2
	add_child(collision)
	_model = Node3D.new()
	add_child(_model)
	var body := BODY.instantiate() as Node3D
	body.scale = Vector3.ONE * 1.15
	_model.add_child(body)
	Rotling._tint_tree(body, ROT_TINT)
	_anim = body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for spot in [Vector3(0, 0.95, 0.1), Vector3(0, 0.85, -0.35), Vector3(0.0, 0.9, 0.45)]:
		var g := GROWTHS.instantiate() as Node3D
		g.position = spot
		g.scale = Vector3.ONE * 1.3
		g.rotation.y = randf() * TAU
		_model.add_child(g)
		ForestProps.apply(g, "rot_growths")
	_play(&"Walk")


func _play(anim: StringName) -> void:
	if _anim and _anim.has_animation(anim) and _anim.current_animation != anim:
		var a := _anim.get_animation(anim)
		if anim in [&"Walk", &"Run", &"Idle", &"Stunned"]:
			a.loop_mode = Animation.LOOP_LINEAR
		_anim.play(anim, 0.15)


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_status(delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if dead:
		velocity = Vector3(0, minf(velocity.y, 0.0), 0)
		move_and_slide()
		return
	var player := _player()
	var move := Vector3.ZERO
	if is_stunned():
		_play(&"Stunned")
		state = State.RECOVER
		_timer = 0.5
	elif player:
		var to := _flat(player.global_position - global_position)
		var dist := to.length()
		match state:
			State.STALK:
				_face(to, delta, 4.0)
				move = to.normalized() * WALK
				_play(&"Walk")
				# Z daleka szarża, z bliska też (krótki rozbieg) - nie stoi wtulony w gracza.
				if dist < 14.0:
					state = State.WINDUP
					_timer = WINDUP_TIME
					Sfx.play(&"roar", global_position)
			State.WINDUP:  # grzebie łapą, celuje
				_face(to, delta, 8.0)
				_play(&"Attack")
				if _model:
					_model.position.z = sin(_t * 30.0) * 0.04
				_timer -= delta
				if _timer <= 0.0:
					state = State.CHARGE
					_timer = CHARGE_TIME
					_dir = to.normalized()
					_hit = false
					charges += 1
			State.CHARGE:
				_play(&"Run")
				move = _dir * CHARGE_SPEED
				_timer -= delta
				var off := player.global_position - global_position
				if not _hit and _flat(off).length() < 1.7 and absf(off.y) < 2.0:
					_hit = true
					if _hurt(player, DAMAGE):
						player.knockback(global_position, 10.0)
				if _timer <= 0.0 or is_on_wall():
					state = State.RECOVER
					_timer = RECOVER_TIME
			State.RECOVER:  # dyszy
				_play(&"Idle")
				_timer -= delta
				if _timer <= 0.0:
					state = State.STALK
	velocity.x = move.x
	velocity.z = move.z
	move_and_slide()


func _face(dir: Vector3, delta: float, speed: float) -> void:
	if dir.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(delta * speed, 1.0))


func _death_effect() -> void:
	Effects.burst(get_parent(), global_position + Vector3(0, 0.9, 0), Color(0.65, 1.0, 0.35), 50)
	Sfx.play(&"boom", global_position)
	var player := _player()
	var h := get_tree().get_first_node_in_group("hallucination") as Hallucination
	if player and h and player.global_position.distance_to(global_position) < 3.5:
		h.add(0.2)


func _drop() -> void:
	super._drop()
	super._drop()  # duży: dwa kłębki Mycelium Fiber
