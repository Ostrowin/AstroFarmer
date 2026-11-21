class_name RotShepherd
extends ForestCreature
## Rot Shepherd (mini-boss Słonecznej Polany): wysoki, przygarbiony grzybowy pasterz z kosturem,
## płaszcz z nitek grzybni, zgniły opadający kapelusz.
## Śpi (pasie stado), dopóki gracz nie wejdzie na Polanę. Wtedy:
##   Faza 1: trzyma dystans, budzi stado i kosturem przywołuje nowe kokony z Rotlingami.
##   Faza 2 (poniżej połowy zdrowia): wbija kostur w ziemię. Najpierw unosi go (1,2 s, zarodnia
##     na kosturze jasno świeci = słaby punkt: trafienie przerywa i ogłusza, 3x obrażenia), potem
##     od kostura rozchodzi się pierścień zgnilizny: kto stoi na ziemi, gdy pierścień go mija,
##     traci zdrowie (trzeba przeskoczyć albo wyjść poza zasięg). Dalej też przywołuje stado.
## Snapper go nie trzyma, Boomshroom ogłusza krócej. Po śmierci Polana się oczyszcza.

signal phase_changed(phase: int)

enum State { DORMANT, FIGHT, CAST, RING, STUNNED }

const MODEL := preload("res://art/models/forest/rot_shepherd.glb")
const MAX_HP := 320.0
const WAKE_RADIUS := 0.9   # ułamek promienia Polany
const KEEP_DIST := 9.0
const WALK := 1.8
const SUMMON_EVERY := [7.0, 11.0]
const CAST_EVERY := 6.5
const CAST_TIME := 1.2
const RING_SPEED := 7.0
const RING_RADIUS := 14.0
const RING_DAMAGE := 15.0
const SWIPE_DAMAGE := 14.0
const STAFF_BONUS := 3.0

var glade: ForestGlade
var director: SpawnDirector
var state: State = State.DORMANT
var phase := 1
var summons := 0
var rings := 0

var _t := 0.0
var _summon_t := 3.0
var _cast_t := 3.0
var _timer := 0.0
var _swipe_cd := 0.0
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _ring_r := -1.0
var _ring_hit := false
var _ring_center := Vector3.ZERO
var _staff_glow: Array[ShaderMaterial] = []


func _ready() -> void:
	max_health = MAX_HP
	super._ready()
	floor_snap_length = 0.6


func scan_id() -> StringName:
	return &"rot_shepherd"


func scan_name() -> String:
	return "Rot Shepherd"


func awake() -> bool:
	return state != State.DORMANT


func _build() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.7
	shape.height = 3.4
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 1.7
	add_child(collision)
	_model = Node3D.new()
	add_child(_model)
	var body := MODEL.instantiate() as Node3D
	body.scale = Vector3.ONE * 1.35
	_model.add_child(body)
	ForestProps.apply(body, "rot_shepherd")
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i)
			if src and src.resource_name.begins_with("RotGlow"):
				var g := (m.get_surface_override_material(i) as ShaderMaterial).duplicate() as ShaderMaterial
				m.set_surface_override_material(i, g)
				_staff_glow.append(g)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 64
	_ring.mesh = torus
	_ring.top_level = true
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(0.55, 0.9, 0.25, 0.9)
	_ring.material_override = _ring_mat
	_ring.visible = false
	add_child(_ring)


# Mini-boss: Snapper go nie trzyma, Boomshroom ogłusza na połowę czasu.
func trap(_seconds := 4.0) -> bool:
	return false


func stun(seconds := 3.0) -> void:
	if dead:
		return
	super.stun(seconds * 0.5)
	if state == State.CAST:
		state = State.FIGHT


func take_hit(amount: float, from := Vector3.INF) -> bool:
	if dead:
		return false
	if state == State.DORMANT:
		_wake()
	if state == State.CAST:
		# Trafienie, gdy zarodnia na kosturze świeci: przerywa i ogłusza.
		amount *= STAFF_BONUS
		state = State.STUNNED
		_timer = 2.5
		Sfx.play(&"stun", global_position)
		Effects.burst(get_parent(), global_position + Vector3(0.8, 3.2, -0.8), Color(0.65, 1.0, 0.3), 30)
	var killed_now := super.take_hit(amount, from)
	if not dead and phase == 1 and health <= max_health * 0.5:
		phase = 2
		_cast_t = 1.5
		phase_changed.emit(2)
	return killed_now


func _wake() -> void:
	if state != State.DORMANT:
		return
	state = State.FIGHT
	Sfx.play(&"roar", global_position)
	if glade:
		for r in glade.herd:
			if is_instance_valid(r):
				r.dormant = false
	_summon_t = 2.0


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_status(delta)
	_update_ring(delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if dead:
		velocity = Vector3(0, minf(velocity.y, 0.0), 0)
		move_and_slide()
		return
	var player := _player()
	var move := Vector3.ZERO
	var glow := 1.2
	match state:
		State.DORMANT:
			_model.rotation.z = sin(_t * 0.8) * 0.04
			if player and glade and _flat(player.global_position - glade.center()).length() < glade.radius() * WAKE_RADIUS:
				_wake()
		State.STUNNED:
			_timer -= delta
			_model.rotation.z = sin(_t * 14.0) * 0.08
			glow = 0.3
			if _timer <= 0.0:
				state = State.FIGHT
		State.FIGHT:
			if is_stunned():
				glow = 0.3
			elif player:
				var to := _flat(player.global_position - global_position)
				var dist := to.length()
				_face(to, delta)
				# Trzyma dystans: podchodzi z daleka, cofa się z bliska (z bliska bije kosturem).
				if dist > KEEP_DIST + 2.0:
					move = to.normalized() * WALK
				elif dist < KEEP_DIST - 3.0:
					move = -to.normalized() * WALK * 0.8
				_swipe_cd -= delta
				if dist < 2.6 and _swipe_cd <= 0.0:
					_swipe_cd = 1.8
					if _hurt(player, SWIPE_DAMAGE):
						player.knockback(global_position, 9.0)
					_model.rotation.x = 0.35
					create_tween().tween_property(_model, "rotation:x", 0.0, 0.4)
				_summon_t -= delta
				if _summon_t <= 0.0:
					_summon()
					_summon_t = SUMMON_EVERY[phase - 1]
				if phase == 2:
					_cast_t -= delta
					if _cast_t <= 0.0:
						state = State.CAST
						_timer = CAST_TIME
		State.CAST:  # unosi kostur, zarodnia rozbłyska
			_timer -= delta
			var k := 1.0 - _timer / CAST_TIME
			glow = lerpf(1.5, 7.0, k)
			_model.rotation.x = -0.25 * k
			if _timer <= 0.0:
				state = State.FIGHT
				_cast_t = CAST_EVERY
				_model.rotation.x = 0.3
				create_tween().tween_property(_model, "rotation:x", 0.0, 0.5)
				_slam_ring()
	for g in _staff_glow:
		g.set_shader_parameter("strength_in", glow)
		g.set_shader_parameter("strength_out", glow)
	velocity.x = move.x
	velocity.z = move.z
	move_and_slide()


func _face(dir: Vector3, delta: float) -> void:
	if dir.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(delta * 3.0, 1.0))


## Kostur przywołuje kokon z Rotlingami (najwyżej 5 żywych w stadzie naraz).
func _summon() -> void:
	if director == null:
		return
	var alive := 0
	for c in director.alive:
		if is_instance_valid(c) and c is Rotling:
			alive += 1
	if glade:
		for r in glade.herd:
			if is_instance_valid(r) and not r.dead:
				alive += 1
	if alive >= 5:
		return
	summons += 1
	var a := randf() * TAU
	var p := global_position + Vector3(cos(a), 0, sin(a)) * 3.0
	if ground_height.is_valid():
		p.y = float(ground_height.call(p.x, p.z))
	director.spawn_pack("rotling", 2 if phase == 1 else 1, p)
	Sfx.play(&"plant", global_position)


func _slam_ring() -> void:
	rings += 1
	Sfx.play(&"boom", global_position)
	_ring_center = global_position + Vector3(0, 0.15, 0)
	_ring_r = 0.6
	_ring_hit = false
	Effects.burst(get_parent(), global_position + Vector3(0, 0.4, 0), Color(0.5, 0.35, 0.15), 30)


func _update_ring(delta: float) -> void:
	if _ring_r < 0.0:
		_ring.visible = false
		return
	_ring_r += RING_SPEED * delta
	_ring.visible = true
	_ring.global_position = _ring_center
	_ring.scale = Vector3(_ring_r, 1.0, _ring_r)
	_ring_mat.albedo_color.a = 0.9 * (1.0 - _ring_r / RING_RADIUS)
	var player := _player()
	if player and not _ring_hit and not phantom:
		var d := _flat(player.global_position - _ring_center).length()
		if absf(d - _ring_r) < 0.8 and player.is_on_floor() and absf(player.global_position.y - _ring_center.y) < 1.6:
			_ring_hit = true
			player.take_damage(RING_DAMAGE, _ring_center)
	if _ring_r >= RING_RADIUS:
		_ring_r = -1.0
		_ring.visible = false


func _death_effect() -> void:
	Effects.burst(get_parent(), global_position + Vector3(0, 2.0, 0), Color(0.65, 1.0, 0.35), 70)
	Sfx.play(&"boom", global_position)


## Nagrody: nasiona kwiatów Polany, towarzysz Lantern Moth (na stałe), włókna.
func _drop() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var base := Vector3(global_position.x, _ground(global_position.x, global_position.z), global_position.z)
	var entries := [Pickup.entry_for(&"seed_glade_bloom", 3), Pickup.entry_for(&"mycelium_fiber", 3)]
	for i in entries.size():
		var pickup := Pickup.new()
		pickup.setup(entries[i])
		parent.add_child(pickup)
		pickup.global_position = base + Vector3(1.2 * (i * 2 - 1), 0, 0.8)
	GameState.learn(&"rot_shepherd", "kill")
	if not GameState.has_upgrade(&"lantern_moth"):
		GameState.add_upgrade(&"lantern_moth")
