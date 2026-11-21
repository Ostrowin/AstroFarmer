class_name Puffking
extends ForestCreature
## The Puffking (boss etapu 1 Grzybowego Lasu): ogromna, popękana purchawka z koroną małych
## purchawek, szeroką zębatą paszczą i wściekłymi świecącymi oczami. Śpi na środku areny,
## do której zbiega się gruba grzybnia; budzi się, gdy gracz wejdzie na arenę.
##   Faza 1: toczy się na gracza (dwa razy z rzędu, ostrzeżenie: przysiada i warczy), potem
##     wydmuchuje chmurę zarodników z otworów (otwory rozbłyskują 1 s wcześniej = słaby punkt:
##     trafienia wtedy 2x). Chmura: obrażenia co sekundę i halucynacje (Spore Mask chroni od halucynacji).
##   Faza 2 (połowa zdrowia): pęka na trzy małe purchawki (MiniPuff), które gonią gracza i wybuchają.
## Wygrana = wszystkie trzy małe purchawki zniszczone.

signal phase_changed(phase: int)
signal defeated

enum State { ASLEEP, IDLE, CROUCH, ROLL, PUFF_WINDUP, PUFF, SPLIT }

const MODEL := preload("res://art/models/forest/puffking.glb")
const MAX_HP := 600.0
const ROLL_SPEED := 8.0
const ROLL_TIME := 2.2
const CROUCH_TIME := 0.7
const ROLL_DAMAGE := 22.0
const PUFF_WINDUP := 1.0
const PUFF_TIME := 2.5
const PUFF_RADIUS := 7.5
const PUFF_DPS := 7.0
const PUFF_HALLUCINATION := 0.25
const VENT_BONUS := 2.0
const RADIUS := 3.5

var arena_center := Vector3.ZERO
var arena_radius := 18.0
var state: State = State.ASLEEP
var phase := 1
var rolls := 0
var puffs := 0
var minis: Array[MiniPuff] = []

var _t := 0.0
var _timer := 0.0
var _roll_dir := Vector3.FORWARD
var _roll_hit := false
var _rolls_left := 2
var _cloud: GPUParticles3D
var _vents: Array[ShaderMaterial] = []
var _body_model: Node3D


func _ready() -> void:
	max_health = MAX_HP
	super._ready()
	floor_snap_length = 1.0


func scan_id() -> StringName:
	return &"puffking"


func scan_name() -> String:
	return "The Puffking"


func awake() -> bool:
	return state != State.ASLEEP


## Zdrowie całej walki (z małymi purchawkami w fazie 2), 0..1 - do paska na HUD.
func fight_fraction() -> float:
	if phase == 1:
		return 0.5 + 0.5 * health / max_health
	var left := 0.0
	for m in minis:
		if is_instance_valid(m) and not m.dead:
			left += m.health / m.max_health
	return 0.5 * left / 3.0


func _build() -> void:
	var shape := SphereShape3D.new()
	shape.radius = RADIUS
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = RADIUS * 0.85
	add_child(cs)
	_model = Node3D.new()
	_model.position.y = RADIUS * 0.75
	add_child(_model)
	_body_model = MODEL.instantiate() as Node3D
	_model.add_child(_body_model)
	ForestProps.apply(_body_model, "puffking")
	for mi in _body_model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i)
			if src and src.resource_name.begins_with("PuffVent"):
				var g := (m.get_surface_override_material(i) as ShaderMaterial).duplicate() as ShaderMaterial
				m.set_surface_override_material(i, g)
				_vents.append(g)
	_cloud = _make_cloud()
	add_child(_cloud)


func trap(_seconds := 4.0) -> bool:
	return false


func stun(seconds := 3.0) -> void:
	if dead or state == State.SPLIT:
		return
	super.stun(seconds * 0.4)


func take_hit(amount: float, from := Vector3.INF) -> bool:
	if dead or state == State.SPLIT:
		return false
	if state == State.ASLEEP:
		wake()
	if state == State.PUFF_WINDUP:
		amount *= VENT_BONUS
	health = maxf(0.0, health - amount)
	_flash_t = 0.12
	_model.scale = Vector3.ONE * 1.05
	if phase == 1 and health <= max_health * 0.5:
		_split()
	return false


func wake() -> void:
	if state != State.ASLEEP:
		return
	state = State.IDLE
	_timer = 1.2
	Sfx.play(&"roar", global_position)
	_model.scale = Vector3(1.15, 0.85, 1.15)
	create_tween().tween_property(_model, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC)


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_status(delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if state == State.SPLIT:
		_check_minis()
		return
	var player := _player()
	var move := Vector3.ZERO
	var vent := 1.0
	if _flash_t <= 0.0 and state != State.ROLL:
		_model.scale = Vector3.ONE * (1.0 + sin(_t * 1.5) * 0.02)  # oddycha
	match state:
		State.ASLEEP:
			vent = 0.4
			if player and _flat(player.global_position - arena_center).length() < arena_radius * 0.85:
				wake()
		State.IDLE:
			_timer -= delta
			if player:
				_face(_flat(player.global_position - global_position), delta)
			if _timer <= 0.0 and not is_stunned():
				if _rolls_left > 0:
					state = State.CROUCH
					_timer = CROUCH_TIME
				else:
					state = State.PUFF_WINDUP
					_timer = PUFF_WINDUP
		State.CROUCH:  # przysiada i celuje
			_timer -= delta
			_model.scale = Vector3(1.08, 0.9, 1.08)
			if player:
				_face(_flat(player.global_position - global_position), delta * 2.0)
			if _timer <= 0.0:
				state = State.ROLL
				_timer = ROLL_TIME
				_roll_hit = false
				_rolls_left -= 1
				rolls += 1
				var to := Vector3.FORWARD
				if player:
					to = _flat(player.global_position - global_position)
				_roll_dir = to.normalized() if to.length() > 0.1 else Vector3.FORWARD
				Sfx.play(&"roar", global_position)
		State.ROLL:
			_timer -= delta
			move = _roll_dir * ROLL_SPEED
			_model.rotate(_roll_dir.cross(Vector3.UP).normalized(), -ROLL_SPEED / RADIUS * delta)
			if player and not _roll_hit and _flat(player.global_position - global_position).length() < RADIUS + 0.6 \
					and absf(player.global_position.y - global_position.y) < RADIUS * 1.5:
				_roll_hit = true
				if _hurt(player, ROLL_DAMAGE):
					player.knockback(global_position, 14.0)
			# Nie wyjeżdża z areny.
			var out := _flat(global_position + _roll_dir * 2.0 - arena_center).length() > arena_radius
			if _timer <= 0.0 or is_on_wall() or out:
				_model.rotation = Vector3.ZERO
				state = State.IDLE
				_timer = 1.0
		State.PUFF_WINDUP:  # otwory rozbłyskują (słaby punkt)
			_timer -= delta
			var k := 1.0 - _timer / PUFF_WINDUP
			vent = lerpf(1.5, 7.0, k)
			_model.scale = Vector3.ONE * (1.0 + 0.08 * k)
			if _timer <= 0.0:
				state = State.PUFF
				_timer = PUFF_TIME
				puffs += 1
				_cloud.restart()
				_cloud.emitting = true
				Sfx.play(&"boom", global_position)
		State.PUFF:
			_timer -= delta
			vent = 2.0
			if player and _flat(player.global_position - global_position).length() < PUFF_RADIUS:
				_hurt_dot(player, delta)
			if _timer <= 0.0:
				_cloud.emitting = false
				state = State.IDLE
				_timer = 1.4
				_rolls_left = 2
	for g in _vents:
		g.set_shader_parameter("strength_in", vent)
		g.set_shader_parameter("strength_out", vent)
	velocity.x = move.x
	velocity.z = move.z
	move_and_slide()


func _face(dir: Vector3, delta: float) -> void:
	if dir.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(delta * 2.5, 1.0))


## Chmura zarodników: ciągłe obrażenia i halucynacje (maska chroni tylko od halucynacji).
func _hurt_dot(player: Player, delta: float) -> void:
	player.take_damage(PUFF_DPS * delta, global_position, true)
	var h := get_tree().get_first_node_in_group("hallucination") as Hallucination
	if h:
		h.add(PUFF_HALLUCINATION * delta)


## Faza 2: pęka na trzy małe purchawki.
func _split() -> void:
	phase = 2
	state = State.SPLIT
	collision_layer = 0
	phase_changed.emit(2)
	Sfx.play(&"boom", global_position)
	Effects.burst(get_parent(), global_position + Vector3(0, RADIUS, 0), Color(0.85, 0.8, 0.6), 80)
	_cloud.restart()
	_cloud.emitting = true
	var tw := create_tween()
	tw.tween_property(_model, "scale", Vector3(1.4, 0.2, 1.4), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _model.visible = false)
	for i in 3:
		var m := MiniPuff.new()
		m.ground_height = ground_height
		get_parent().add_child(m)
		var a := TAU * i / 3.0
		var p := global_position + Vector3(cos(a), 0, sin(a)) * 3.0
		if ground_height.is_valid():
			p.y = float(ground_height.call(p.x, p.z)) + 0.3
		m.global_position = p
		m.velocity = Vector3(cos(a), 0.6, sin(a)) * 6.0
		minis.append(m)


func _check_minis() -> void:
	if dead:
		return
	for m in minis:
		if is_instance_valid(m) and not m.dead:
			return
	dead = true
	_cloud.emitting = false
	killed.emit(self)
	defeated.emit()
	GameState.learn(&"puffking", "kill")
	_drop()
	get_tree().create_timer(3.0).timeout.connect(queue_free)


## Nagrody: nasiona Cluster Shroom, dużo Mycelium Fiber, odblokowanie etapu 2.
func _drop() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var base := Vector3(global_position.x, _ground(global_position.x, global_position.z), global_position.z)
	var entries := [Pickup.entry_for(&"seed_cluster_shroom", 3), Pickup.entry_for(&"mycelium_fiber", 5)]
	for i in entries.size():
		var pickup := Pickup.new()
		pickup.setup(entries[i])
		parent.add_child(pickup)
		pickup.global_position = base + Vector3(1.5 * (i * 2 - 1), 0, 0)
	GameState.add_upgrade(&"forest_stage2")


func _make_cloud() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 160
	p.lifetime = 2.5
	p.one_shot = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-10, -1, -10), Vector3(20, 10, 20))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = RADIUS
	pm.direction = Vector3(0, 0.4, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.5
	pm.damping_min = 1.2
	pm.damping_max = 2.0
	pm.gravity = Vector3(0, 0.15, 0)
	pm.scale_min = 2.0
	pm.scale_max = 4.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 1.0, 0.5, 0.0))
	ramp.set_color(1, Color(0.7, 0.8, 0.4, 0.0))
	ramp.add_point(0.15, Color(0.85, 1.0, 0.5, 0.35))
	ramp.add_point(0.7, Color(0.75, 0.85, 0.45, 0.2))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_ramp = tex
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	var g := GradientTexture2D.new()
	var gg := Gradient.new()
	gg.set_color(0, Color(1, 1, 1, 1))
	gg.set_color(1, Color(1, 1, 1, 0))
	g.gradient = gg
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	mat.albedo_texture = g
	quad.material = mat
	p.draw_pass_1 = quad
	p.position.y = RADIUS * 0.8
	return p
