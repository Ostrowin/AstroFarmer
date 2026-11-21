class_name Sporekin
extends StaticBody3D
## Sporekin: krępy, uśmiechnięty ludek z bagien (grzybki rosną mu na plecionym ponczu).
## Stoi w wiosce, kołysze się, odwraca do gracza, który podejdzie, i "mówi" dymkami z emocjami.
## Handlarz (z lampionem) otwiera handel: E przy nim.

const MODELS := [
	preload("res://art/models/forest/sporekin_0.glb"),
	preload("res://art/models/forest/sporekin_1.glb"),
	preload("res://art/models/forest/sporekin_2.glb"),
	preload("res://art/models/forest/sporekin_3.glb"),
]
const MOODS := ["!", "?", "♪", "♥", "~", ":)"]
const LOOK_RANGE := 9.0

@export var variant := 0
@export var trader := false

var _model: Node3D
var _bubble: Label3D
var _t := 0.0
var _talk := 0.0
var _phase := 0.0
var _base_yaw := 0.0


func _ready() -> void:
	add_to_group("sporekin")
	collision_layer = 1 | 4
	collision_mask = 0
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.5
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.75
	add_child(cs)
	# Handlarz ma lampion (model 0), reszta: modele 1-3.
	var model: PackedScene = MODELS[0] if trader else MODELS[1 + posmod(variant, 3)]
	_model = model.instantiate() as Node3D
	add_child(_model)
	ForestProps.apply(_model, "sporekin")
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 72
	_bubble.outline_size = 14
	_bubble.modulate = Color(1.0, 0.95, 0.8)
	_bubble.position.y = 1.95
	_bubble.visible = false
	add_child(_bubble)
	_phase = randf() * TAU
	_base_yaw = rotation.y
	_talk = randf_range(2.0, 6.0)


func get_scan_info() -> Dictionary:
	return {"id": &"sporekin", "name": "Sporekin Trader" if trader else "Sporekin"}


func _process(delta: float) -> void:
	_t += delta
	# Kołysanie z nogi na nogę i oddech.
	_model.rotation.z = sin(_t * 1.6 + _phase) * 0.05
	_model.scale = Vector3(1.0, 1.0 + sin(_t * 2.2 + _phase) * 0.02, 1.0)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var target_yaw := _base_yaw
	if player:
		var to := player.global_position - global_position
		to.y = 0.0
		if to.length() < LOOK_RANGE:
			target_yaw = atan2(to.x, to.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 3.0, 1.0))
	# Dymki z emocjami co jakiś czas (częściej, gdy gracz jest blisko).
	_talk -= delta * (2.0 if player and player.global_position.distance_to(global_position) < LOOK_RANGE else 1.0)
	if _talk <= 0.0:
		say(MOODS.pick_random())
		_talk = randf_range(4.0, 9.0)


func say(text: String) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble.scale = Vector3.ONE * 0.3
	var tw := create_tween()
	tw.tween_property(_bubble, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.6)
	tw.tween_callback(func() -> void: _bubble.visible = false)
	# Podskok przy mówieniu.
	var hop := create_tween()
	hop.tween_property(_model, "position:y", 0.12, 0.12)
	hop.tween_property(_model, "position:y", 0.0, 0.18)
