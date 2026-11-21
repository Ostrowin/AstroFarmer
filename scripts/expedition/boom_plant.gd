class_name BoomPlant
extends Node3D
## Rzucone nasiono Boomshrooma: wyrasta w ~1 s i od razu robi PUFF.
## Ogłusza wszystkie stworzenia w promieniu i odrzuca gracza, jeśli stoi za blisko.

const GROW_TIME := 1.0
const RADIUS := 4.0
const STUN_SECONDS := 3.0
const PLAYER_RADIUS := 2.0
const SIZE := 1.0
## Cluster Shroom: po wybuchu rozrzuca 3 mniejsze bomby (wybuchają po chwili dookoła).
const CLUSTER_SPREAD := 3.2

var cluster := false
var scale_factor := 1.0

var _model: Node3D
var _data: PlantData


func _ready() -> void:
	_data = PlantCatalog.get_plant(&"cluster_shroom" if cluster else &"boomshroom")
	_model = PlantVisuals.build(_data, _data.last_stage())
	_model.scale = Vector3.ONE * 0.05
	add_child(_model)
	Sfx.play(&"plant", global_position)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_model, "scale", Vector3.ONE * SIZE * scale_factor, GROW_TIME * (0.5 if scale_factor < 1.0 else 1.0))
	tween.tween_callback(_puff)


## Ile stworzeń ogłuszyło (testy).
var stunned := 0


func _puff() -> void:
	if cluster:
		for i in 3:
			var small := BoomPlant.new()
			small.scale_factor = 0.55
			get_parent().add_child(small)
			var a := TAU * i / 3.0 + randf() * 0.5
			small.global_position = global_position + Vector3(cos(a), 0, sin(a)) * CLUSTER_SPREAD
	Sfx.play(&"boom", global_position)
	Effects.burst(get_parent(), global_position + Vector3(0, 0.8, 0), _data.accent_color.lightened(0.3), 40)
	for node in get_tree().get_nodes_in_group("creature"):
		var creature := node as Creature
		if creature and _flat_distance(creature.global_position) <= RADIUS * scale_factor:
			creature.stun(STUN_SECONDS)
			stunned += 1
	for node in get_tree().get_nodes_in_group("forest_creature"):
		var fc := node as ForestCreature
		if fc and not fc.dead and _flat_distance(fc.global_position) <= RADIUS * scale_factor:
			fc.stun(STUN_SECONDS)
			stunned += 1
	for node in get_tree().get_nodes_in_group("hammer_cap"):
		var hammer := node as HammerCap
		if hammer and _flat_distance(hammer.global_position) <= RADIUS * scale_factor:
			hammer.stun(STUN_SECONDS)
			stunned += 1
	for node in get_tree().get_nodes_in_group("critter"):
		var critter := node as Critter
		if critter and _flat_distance(critter.global_position) <= RADIUS * scale_factor:
			critter.stun(STUN_SECONDS)
			stunned += 1
	if stunned > 0:
		GameState.learn(&"boomshroom", "boom")
	if cluster:
		GameState.learn(&"cluster_shroom", "boom")
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and _flat_distance(player.global_position) <= PLAYER_RADIUS:
		player.knockback(global_position, 9.0)
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3(SIZE * 1.4, SIZE * 0.5, SIZE * 1.4), 0.08)
	tween.tween_property(_model, "scale", Vector3.ZERO, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()
