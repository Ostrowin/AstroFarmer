class_name HammerCap
extends StaticBody3D
## Hammer Cap: grzyb-młot wyrastający ze ściany kanionu (model art/models/forest/hammer_cap.glb).
## Korzeń wrośnięty w skałę, trzon wychodzi ze ściany i zagina się w górę, na końcu ciężki kapelusz.
## W rytmie: ramię odchyla się do ściany (spód kapelusza rozjarza się na bursztynowo = ostrzeżenie),
## potem uderza kapeluszem w dno kanionu jak młot. Od miejsca uderzenia idzie fala: trafia gracza
## stojącego na ziemi (skok ją przeskakuje); pod samym kapeluszem boli mocniej.
## Pistolet przerywa zamach, Boomshroom ogłusza na dłużej. Nie da się go zabić (na razie).
## Węzeł stoi na ścianie: oś Z w stronę środka kanionu, Y w górę.

enum State { REST, RAISE, SLAM, HOLD, RETURN, STUNNED }

@export var period := 3.8
@export var raise_time := 0.9
@export var wave_radius := 7.0
@export var wave_speed := 11.0
@export var wave_damage := 12.0
@export var slam_damage := 20.0
@export var slam_radius := 2.0
## Uderza tylko, gdy gracz jest bliżej (dalej drzemie i lekko się kołysze).
@export var active_range := 40.0
## Przesunięcie rytmu (s), żeby grzyby w kanionie nie biły naraz.
@export var phase := 0.0

## Wysokość ziemi w świecie: (x, z) -> y. Puste = 3 m pod punktem montażu.
var ground_height: Callable

const MODEL := preload("res://art/models/forest/hammer_cap.glb")
const PULL_BACK := -0.32
const SLAM_TIME := 0.16
const HOLD_TIME := 0.35
const RETURN_TIME := 0.9
## Punkty kapelusza w układzie ramienia (Godot: Z = od ściany, Y = w górę).
const STEM_TOP := Vector3(0, 2.9, 2.3)
const CAP_TOP := Vector3(0, 3.95, 2.25)
const CAP_RIM := 1.62

var state: State = State.REST
var waves_sent := 0
var impact_point := Vector3.ZERO
var slam_angle := 1.7

var _arm: Node3D
var _glow_mat: ShaderMaterial
var _angle := 0.0
var _clock := 0.0
var _timer := 0.0
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _wave_r := -1.0
var _wave_hit := false
var _stars: Label3D
var _time := 0.0


func _ready() -> void:
	add_to_group("creature")
	add_to_group("hammer_cap")
	collision_layer = 1 | 4
	collision_mask = 0
	_clock = phase
	_time = phase
	_build()
	_compute_slam()


func get_scan_info() -> Dictionary:
	return {"id": &"hammer_cap", "name": "Hammer Cap"}


## Trafienie z pistoletu: przerywa zamach (nie w trakcie samego uderzenia). Nie zadaje obrażeń.
func take_hit(_amount: float, _from := Vector3.INF) -> bool:
	if state != State.SLAM:
		stun(1.5)
	return false


func stun(seconds := 3.0) -> void:
	state = State.STUNNED
	_timer = seconds
	_stars.visible = true
	Sfx.play(&"stun", global_position)


func is_dead() -> bool:
	return false


func _physics_process(delta: float) -> void:
	_time += delta
	_update_wave(delta)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := player != null and _flat(player.global_position - impact_point).length() < active_range
	var glow := 0.4
	match state:
		State.STUNNED:
			_timer -= delta
			_angle = lerpf(_angle, 0.5 + sin(_time * 9.0) * 0.04, minf(delta * 6.0, 1.0))
			glow = 0.15
			if _timer <= 0.0:
				_stars.visible = false
				state = State.RETURN
				_timer = RETURN_TIME
		State.REST:
			_angle = sin(_time * 1.1) * 0.035
			if near:
				_clock += delta
				if _clock >= period - raise_time:
					state = State.RAISE
					_timer = raise_time
		State.RAISE:
			_timer -= delta
			var k := 1.0 - _timer / raise_time
			_angle = lerpf(0.0, PULL_BACK, ease(k, 0.5)) + sin(k * 70.0) * 0.012 * k
			glow = lerpf(0.4, 4.0, k)
			if _timer <= 0.0:
				state = State.SLAM
				_timer = SLAM_TIME
		State.SLAM:
			_timer -= delta
			var k := 1.0 - maxf(_timer, 0.0) / SLAM_TIME
			_angle = lerpf(PULL_BACK, slam_angle, k * k)
			glow = 4.0
			if _timer <= 0.0:
				_angle = slam_angle
				_slam(player)
				state = State.HOLD
				_timer = HOLD_TIME
		State.HOLD:
			_timer -= delta
			glow = lerpf(0.4, 2.5, _timer / HOLD_TIME)
			if _timer <= 0.0:
				state = State.RETURN
				_timer = RETURN_TIME
		State.RETURN:
			_timer -= delta
			var k := 1.0 - maxf(_timer, 0.0) / RETURN_TIME
			_angle = lerpf(_angle, 0.0, ease(k, 0.4))
			if _timer <= 0.0:
				state = State.REST
				_clock = 0.0
	_arm.transform.basis = Basis(Vector3.RIGHT, _angle)
	if _glow_mat:
		_glow_mat.set_shader_parameter("strength_in", glow)
		_glow_mat.set_shader_parameter("strength_out", glow * 0.5)


func _slam(player: Node3D) -> void:
	Sfx.play(&"boom", impact_point)
	Effects.burst(get_parent(), impact_point + Vector3(0, 0.3, 0), Color(0.75, 0.6, 0.45), 24)
	_wave_r = 0.6
	_wave_hit = false
	waves_sent += 1
	_ring.global_position = impact_point + Vector3(0, 0.15, 0)
	if player and player.has_method("take_damage") and _on_ground(player):
		if _flat(player.global_position - impact_point).length() < slam_radius:
			player.call("take_damage", slam_damage, impact_point)
			_wave_hit = true


## Fala: pierścień rośnie od miejsca uderzenia; trafia gracza raz, gdy przechodzi przez jego miejsce.
func _update_wave(delta: float) -> void:
	if _wave_r < 0.0:
		_ring.visible = false
		return
	_wave_r += wave_speed * delta
	var k := _wave_r / wave_radius
	_ring.visible = true
	_ring.scale = Vector3(_wave_r, 1.0, _wave_r)
	_ring_mat.albedo_color.a = 0.85 * (1.0 - k)
	if not _wave_hit:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player and player.has_method("take_damage"):
			var d := _flat(player.global_position - impact_point).length()
			if absf(d - _wave_r) < 0.7 and _on_ground(player):
				player.call("take_damage", wave_damage, impact_point)
				_wave_hit = true
				GameState.learn(&"hammer_cap", "wave")
	if _wave_r >= wave_radius:
		_wave_r = -1.0
		_ring.visible = false


## Gracz "na ziemi": stoi na podłożu, niedaleko poziomu miejsca uderzenia.
func _on_ground(player: Node3D) -> bool:
	var body := player as CharacterBody3D
	if body and not body.is_on_floor():
		return false
	return absf(player.global_position.y - impact_point.y) < 1.5


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Kąt uderzenia: obraca ramię, aż kapelusz (wierzch albo brzeg) dotknie ziemi.
func _compute_slam() -> void:
	var axis := (CAP_TOP - STEM_TOP).normalized()
	var side := axis.cross(Vector3.RIGHT).normalized()
	var center := STEM_TOP + axis * 0.25
	var samples: Array[Vector3] = [CAP_TOP]
	for i in 8:
		var a := TAU * i / 8.0
		samples.append(center + (Vector3.RIGHT * cos(a) + side * sin(a)) * CAP_RIM)
	slam_angle = 2.1
	for deg in range(0, 170, 2):
		var b := Basis(Vector3.RIGHT, deg_to_rad(deg))
		var hit := false
		for sp in samples:
			var w := global_transform * (b * sp)
			if w.y <= _ground(w.x, w.z) + 0.05:
				hit = true
				break
		if hit:
			slam_angle = deg_to_rad(deg)
			break
	var top := global_transform * (Basis(Vector3.RIGHT, slam_angle) * CAP_TOP)
	impact_point = Vector3(top.x, _ground(top.x, top.z), top.z)


func _ground(x: float, z: float) -> float:
	if ground_height.is_valid():
		return float(ground_height.call(x, z))
	return global_position.y - 3.0


# --- Model ----------------------------------------------------------------------

func _build() -> void:
	var model := MODEL.instantiate() as Node3D
	add_child(model)
	ForestProps.apply(model, "hammer_cap")
	_arm = model.find_child("Arm", true, false) as Node3D
	if _arm == null:
		_arm = model
	var arm_mesh := _arm as MeshInstance3D
	if arm_mesh:
		for i in arm_mesh.mesh.get_surface_count():
			var src := arm_mesh.mesh.surface_get_material(i)
			if src and src.resource_name.begins_with("HammerGlow"):
				_glow_mat = (arm_mesh.get_surface_override_material(i) as ShaderMaterial).duplicate()
				arm_mesh.set_surface_override_material(i, _glow_mat)

	# Kolizja (nieruchoma, w pozie spoczynku): korzeń, trzon, kapelusz.
	for spec: Array in [
		[_sphere(0.8), Vector3(0, 0, 0.3)],
		[_box(Vector3(0.9, 0.9, 2.0)), Vector3(0, 0.3, 1.1)],
		[_cylinder(0.45, 2.6), Vector3(0, 1.6, 2.2)],
		[_cylinder(1.6, 1.1), Vector3(0, 3.4, 2.3)],
	]:
		var collision := CollisionShape3D.new()
		collision.shape = spec[0]
		collision.position = spec[1]
		add_child(collision)

	_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.9
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 48
	_ring.mesh = ring_mesh
	_ring.top_level = true
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(1.0, 0.7, 0.3, 0.85)
	_ring.material_override = _ring_mat
	_ring.visible = false
	add_child(_ring)

	_stars = Label3D.new()
	_stars.text = "* * *"
	_stars.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_stars.modulate = Color(1, 0.9, 0.4)
	_stars.font_size = 64
	_stars.position = Vector3(0, 5.0, 2.5)
	_stars.visible = false
	add_child(_stars)


static func _sphere(r: float) -> SphereShape3D:
	var s := SphereShape3D.new()
	s.radius = r
	return s


static func _box(size: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s


static func _cylinder(r: float, h: float) -> CylinderShape3D:
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	return s
