class_name Rotling
extends ForestCreature
## Rotling: zwierzę (Muncher) zarażone grzybnią, z naroślami grzybów na grzbiecie.
## Biegnie prosto na gracza (wolniej niż sprint), z bliska podskakuje i gryzie.
## Przy śmierci pęka chmurą zarodników. Snapper go łapie, Boomshroom ogłusza.

const BODY := preload("res://art/models/creatures/muncher.glb")
const GROWTHS := preload("res://art/models/forest/rot_growths.glb")
const SPEED := 4.2
const BITE_DAMAGE := 10.0
const BITE_RANGE := 1.5
const WINDUP := 0.35
const COOLDOWN := 1.2
const ROT_TINT := Color(0.62, 0.72, 0.48)

var bites := 0
## Uśpione stado (Rot Shepherd): pasie się wokół `home` i nie goni gracza, dopóki go nie obudzi.
var dormant := false
var home := Vector3.ZERO

var _t := 0.0
var _windup := -1.0
var _cooldown := 0.0


func _ready() -> void:
	max_health = 30.0
	super._ready()
	floor_snap_length = 0.6


func scan_id() -> StringName:
	return &"rotling"


func scan_name() -> String:
	return "Rotling"


func _build() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.5
	add_child(collision)
	_model = Node3D.new()
	add_child(_model)
	var body := BODY.instantiate() as Node3D
	body.scale = Vector3.ONE * 1.25
	_model.add_child(body)
	_tint_tree(body, ROT_TINT)
	var top := _top(self, body)
	var growths := GROWTHS.instantiate() as Node3D
	growths.position = Vector3(0, top - 0.05, 0)
	_model.add_child(growths)
	ForestProps.apply(growths, "rot_growths")


## Zgniły odcień: kopie materiałów modelu przyciemnione na zielonkawo-brunatno.
static func _tint_tree(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if src:
				var m := src.duplicate() as BaseMaterial3D
				m.albedo_color = m.albedo_color * tint
				mi.set_surface_override_material(i, m)
	for child in node.get_children():
		_tint_tree(child, tint)


## Wysokość grzbietu modelu (w układzie stworzenia), żeby narośla siedziały na plecach.
static func _top(owner_node: Node3D, node: Node) -> float:
	var top := 0.6
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var aabb := m.get_aabb()
		for corner in [aabb.position, aabb.end]:
			top = maxf(top, owner_node.to_local(m.global_transform * corner).y)
	return top


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_status(delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var player := _player()
	var move := Vector3.ZERO
	_cooldown -= delta
	if dormant:
		# Pasie się: powoli krąży wokół domu.
		var goal := home + Vector3(cos(_t * 0.3 + home.x), 0, sin(_t * 0.3 + home.z)) * 2.0
		var to_goal := _flat(goal - global_position)
		if to_goal.length() > 0.3:
			move = to_goal.normalized() * 1.0
			rotation.y = lerp_angle(rotation.y, atan2(to_goal.x, to_goal.z), minf(delta * 3.0, 1.0))
		velocity.x = move.x
		velocity.z = move.z
		move_and_slide()
		_animate(move.length() * 3.0)
		return
	if player and not is_stunned():
		var to := _flat(player.global_position - global_position)
		var dist := to.length()
		if dist > 0.05:
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(delta * 8.0, 1.0))
		if _windup >= 0.0:
			_windup -= delta
			if _windup < 0.0:
				if dist < BITE_RANGE + 0.4 and absf(player.global_position.y - global_position.y) < 1.6:
					_hurt(player, BITE_DAMAGE)
					bites += 1
					Sfx.play(&"bite", global_position)
				_cooldown = COOLDOWN
		elif dist < BITE_RANGE and _cooldown <= 0.0:
			_windup = WINDUP
			if is_on_floor():
				velocity.y = 3.0
		elif dist > BITE_RANGE * 0.8:
			move = to.normalized() * SPEED
	velocity.x = move.x
	velocity.z = move.z
	move_and_slide()
	_animate(move.length())


func _animate(speed: float) -> void:
	if _model == null or _flash_t > 0.0:
		return
	var hop := absf(sin(_t * 11.0)) * 0.12 * clampf(speed / SPEED, 0.0, 1.0)
	_model.position.y = hop
	if is_stunned():
		_model.rotation.z = sin(_t * 20.0) * 0.15
	else:
		_model.rotation.z = 0.0


func _death_effect() -> void:
	# Pęka chmurą zarodników.
	Effects.burst(get_parent(), global_position + Vector3(0, 0.6, 0), Color(0.65, 1.0, 0.35), 34)
	Sfx.play(&"boom", global_position)
