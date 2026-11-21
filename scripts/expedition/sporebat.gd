class_name Sporebat
extends ForestCreature
## Sporebat: nietoperz-grzyb (ciało = kapelusz ze świecącymi blaszkami, błoniaste skrzydła).
## Od reżysera przylatuje stadem: krąży nad graczem, potem pojedynczo zapowiada nurkowanie
## (zawisa i piszczy, blaszki rozbłyskują) i nurkuje w miejsce, gdzie gracz stał. Po ataku
## odlatuje w górę i znowu krąży. Słaby (jeden strzał), unik dashem w bok.
## Ogłuszony albo złapany spada na ziemię i chwilę leży.

enum State { CIRCLE, WARN, DIVE, RECOVER, DOWN }

const MODEL := preload("res://art/models/forest/sporebat.glb")
const DIVE_DAMAGE := 8.0
const DIVE_SPEED := 15.0
const FLY_SPEED := 7.5
const WARN_TIME := 0.5

var state: State = State.CIRCLE
var dives := 0

var _t := 0.0
var _timer := 0.0
var _orbit := 0.0
var _orbit_r := 7.0
var _height := 5.0
var _dive_target := Vector3.ZERO
var _wing_l: Node3D
var _wing_r: Node3D
var _glow: Array[ShaderMaterial] = []


func _ready() -> void:
	max_health = 10.0
	super._ready()
	collision_mask = 0  # lata swobodnie, bez zderzeń z terenem
	_orbit = randf() * TAU
	_orbit_r = randf_range(5.5, 9.0)
	_height = randf_range(3.5, 6.0)
	_timer = randf_range(1.5, 4.5)


func scan_id() -> StringName:
	return &"sporebat"


func scan_name() -> String:
	return "Sporebat"


func _build() -> void:
	var shape := SphereShape3D.new()
	shape.radius = 0.4
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	_model = MODEL.instantiate() as Node3D
	add_child(_model)
	ForestProps.apply(_model, "sporebat")
	_wing_l = _model.find_child("WingL", true, false) as Node3D
	_wing_r = _model.find_child("WingR", true, false) as Node3D
	var body := _model.find_child("Body", true, false) as MeshInstance3D
	if body:
		for i in body.mesh.get_surface_count():
			var src := body.mesh.surface_get_material(i)
			if src and src.resource_name.begins_with("BatGlow"):
				var m := (body.get_surface_override_material(i) as ShaderMaterial).duplicate() as ShaderMaterial
				body.set_surface_override_material(i, m)
				_glow.append(m)


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_status(delta)
	if dead:
		return
	var player := _player()
	if player == null:
		return
	if is_stunned() and state != State.DOWN:
		state = State.DOWN
	var flap := 9.0
	var glow := 1.0
	match state:
		State.CIRCLE:
			_orbit += delta * FLY_SPEED / _orbit_r
			var goal := player.global_position + Vector3(cos(_orbit) * _orbit_r, _height + sin(_t * 1.7) * 0.6, sin(_orbit) * _orbit_r)
			_move_toward(goal, FLY_SPEED * 1.4, delta)
			_timer -= delta
			if _timer <= 0.0 and _flat(global_position - player.global_position).length() < 14.0:
				state = State.WARN
				_timer = WARN_TIME
				Sfx.play(&"bite", global_position)
		State.WARN:  # zawisa, trzepocze szybciej, blaszki rozbłyskują
			_timer -= delta
			flap = 18.0
			glow = 4.0
			_look_at_flat(player.global_position)
			if _timer <= 0.0:
				state = State.DIVE
				_dive_target = player.global_position + Vector3(0, 0.9, 0)
		State.DIVE:
			flap = 2.0
			var to := _dive_target - global_position
			if to.length() < 0.6:
				_end_dive()
			else:
				global_position += to.normalized() * minf(DIVE_SPEED * delta, to.length())
				_look_at_dir(to)
			if (player.global_position + Vector3(0, 0.9, 0)).distance_to(global_position) < 1.0:
				_hurt(player, DIVE_DAMAGE)
				_end_dive()
		State.RECOVER:
			_timer -= delta
			_move_toward(global_position + Vector3(0, 6, 0) + _flat(global_position - player.global_position).normalized() * 4.0, FLY_SPEED, delta)
			if _timer <= 0.0:
				state = State.CIRCLE
				_timer = randf_range(2.5, 5.5)
		State.DOWN:  # spada i leży, póki ogłuszony
			flap = 0.0
			var floor_y := _ground(global_position.x, global_position.z) + 0.25
			if global_position.y > floor_y:
				global_position.y = maxf(floor_y, global_position.y - 9.0 * delta)
			if not is_stunned():
				state = State.RECOVER
				_timer = 1.2
	_animate(flap, glow, delta)


func _end_dive() -> void:
	dives += 1
	state = State.RECOVER
	_timer = 1.4


func _move_toward(goal: Vector3, speed: float, delta: float) -> void:
	var to := goal - global_position
	var step := minf(speed * delta, to.length())
	if step > 0.001:
		global_position += to.normalized() * step
		_look_at_dir(to)


func _look_at_dir(dir: Vector3) -> void:
	var flat := _flat(dir)
	if flat.length() > 0.05:
		# Przód modelu = +Z (Blender -Y): obrót tak, żeby +Z patrzyło w kierunku lotu.
		rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), 0.2)


func _look_at_flat(target: Vector3) -> void:
	_look_at_dir(target - global_position)


func _animate(flap: float, glow: float, _delta: float) -> void:
	var a := sin(_t * flap) * 0.75 if flap > 0.0 else -0.9
	if _wing_l:
		_wing_l.rotation.z = -a
	if _wing_r:
		_wing_r.rotation.z = a
	if _model:
		_model.position.y = sin(_t * flap) * 0.04
	for m in _glow:
		m.set_shader_parameter("strength_in", glow)
		m.set_shader_parameter("strength_out", glow)
