class_name MiniPuff
extends ForestCreature
## Mała purchawka z fazy 2 The Puffkinga (jest ich 3): gryzie zębatą paszczą, toczy się za graczem
## i wybucha przy dotyku (zapowiedź Cluster Shroom). Zestrzelona też wybucha: wybuch rani gracza
## w pobliżu i inne purchawki (można je zwabić na siebie nawzajem).

signal exploded(puff: MiniPuff)

const MODEL := preload("res://art/models/forest/mini_puff.glb")
const SPEED := 4.6
const BLAST_RADIUS := 2.8
const BLAST_DAMAGE := 18.0
const BLAST_TO_PUFFS := 45.0

var _t := 0.0
var _blown := false


func _ready() -> void:
	max_health = 70.0
	super._ready()
	floor_snap_length = 0.6


func scan_id() -> StringName:
	return &"puffking"


func scan_name() -> String:
	return "Puffling"


func _build() -> void:
	var shape := SphereShape3D.new()
	shape.radius = 0.9
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.9
	add_child(cs)
	_model = MODEL.instantiate() as Node3D
	_model.position.y = 0.75
	add_child(_model)
	ForestProps.apply(_model, "puffking")


func trap(_seconds := 4.0) -> bool:
	return false


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_status(delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if dead:
		return
	var player := _player()
	var move := Vector3.ZERO
	if player and not is_stunned():
		var to := _flat(player.global_position - global_position)
		if to.length() > 0.05:
			rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(delta * 6.0, 1.0))
		move = to.normalized() * SPEED
		if to.length() < 1.6 and absf(player.global_position.y - global_position.y) < 2.0:
			explode()
			return
	velocity.x = move.x
	velocity.z = move.z
	move_and_slide()
	if _model:
		# Toczy się i podskakuje.
		_model.rotation.x = sin(_t * 10.0) * 0.12 * clampf(move.length() / SPEED, 0.0, 1.0)  # kołysze się (paszcza zawsze z przodu)
		_model.position.y = 0.75 + absf(sin(_t * 9.0)) * 0.15


## Wybuch: rani gracza i inne purchawki w zasięgu.
func explode() -> void:
	if _blown:
		return
	_blown = true
	if not dead:
		dead = true
		collision_layer = 0
		killed.emit(self)
	Sfx.play(&"boom", global_position)
	Effects.burst(get_parent(), global_position + Vector3(0, 0.8, 0), Color(0.85, 1.0, 0.4), 40)
	var player := _player()
	if player and player.global_position.distance_to(global_position) < BLAST_RADIUS and not phantom:
		player.take_damage(BLAST_DAMAGE, global_position)
		player.knockback(global_position, 8.0)
	for node in get_tree().get_nodes_in_group("forest_creature"):
		var other := node as MiniPuff
		if other and other != self and not other.dead and other.global_position.distance_to(global_position) < BLAST_RADIUS + 0.5:
			other.take_hit(BLAST_TO_PUFFS, global_position)
	exploded.emit(self)
	queue_free()


func _die() -> void:
	explode()
