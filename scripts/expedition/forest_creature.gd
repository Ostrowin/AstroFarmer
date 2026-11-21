class_name ForestCreature
extends CharacterBody3D
## Wspólna baza stworzeń Grzybowego Lasu (Sporebat, Rotling, ...), zwykle wypuszczanych przez reżysera
## (SpawnDirector) z kokonów z grzybni. Trafienie z pistoletu zadaje obrażenia, Boomshroom ogłusza,
## Snapper łapie. Martwe zostawia Mycelium Fiber.

signal killed(creature: ForestCreature)

@export var max_health := 20.0

## Wysokość ziemi w świecie: (x, z) -> y (ustawia reżyser). Puste = y stworzenia.
var ground_height: Callable
var health := 20.0
var dead := false
## Koszt w punktach reżysera (zwrot połowy, gdy stworzenie wraca do grzybni).
var director_cost := 0.0
## Fantom z halucynacji: nie zadaje obrażeń, rozwiewa się po strzale, nic nie zostawia.
var phantom := false

var _stun := 0.0
var _trap := 0.0
var _flash_t := 0.0
var _model: Node3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group("forest_creature")
	collision_layer = 4
	collision_mask = 1
	health = max_health
	_build()


## Nadpisywane: wygląd i kolizja.
func _build() -> void:
	pass


func scan_id() -> StringName:
	return &"forest_creature"


func scan_name() -> String:
	return "Creature"


func get_scan_info() -> Dictionary:
	return {"id": scan_id(), "name": scan_name()}


func is_dead() -> bool:
	return dead


func is_stunned() -> bool:
	return _stun > 0.0 or _trap > 0.0


## Trafienie z pistoletu. Zwraca true, jeśli śmiertelne.
func take_hit(amount: float, _from := Vector3.INF) -> bool:
	if dead:
		return false
	if phantom:
		dead = true
		Hallucination._vanish(self)
		return false
	health = maxf(0.0, health - amount)
	_flash_t = 0.12
	if _model:
		_model.scale = Vector3.ONE * 1.15
	if health <= 0.0:
		_die()
		return true
	_on_hit()
	return false


func stun(seconds := 3.0) -> void:
	if dead:
		return
	_stun = maxf(_stun, seconds)
	Sfx.play(&"stun", global_position)


func trap(seconds := 4.0) -> bool:
	if dead or _trap > 0.0:
		return false
	_trap = seconds
	return true


## Nadpisywane: reakcja na trafienie (ucieczka, wściekłość).
func _on_hit() -> void:
	pass


func _tick_status(delta: float) -> void:
	_stun = maxf(0.0, _stun - delta)
	_trap = maxf(0.0, _trap - delta)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _model and _flash_t <= 0.0:
			_model.scale = Vector3.ONE


func _die() -> void:
	if not phantom:
		GameState.learn(scan_id(), "kill")
	dead = true
	collision_layer = 0
	killed.emit(self)
	_death_effect()
	_drop()
	var tween := create_tween()
	if _model:
		tween.tween_property(_model, "scale", Vector3(1.3, 0.05, 1.3), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


## Nadpisywane: efekt śmierci (puff zarodników).
func _death_effect() -> void:
	Effects.burst(get_parent(), global_position + Vector3(0, 0.4, 0), Color(0.6, 1.0, 0.4), 18)


func _drop() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var pickup := Pickup.new()
	pickup.setup(Pickup.entry_for(&"mycelium_fiber", 1))
	parent.add_child(pickup)
	pickup.global_position = Vector3(global_position.x, _ground(global_position.x, global_position.z), global_position.z)


## Obrażenia dla gracza (fantomy tylko udają atak).
func _hurt(player: Player, amount: float) -> bool:
	if phantom or player == null:
		return false
	player.take_damage(amount, global_position)
	return true


func _ground(x: float, z: float) -> float:
	if ground_height.is_valid():
		return float(ground_height.call(x, z))
	return global_position.y


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
