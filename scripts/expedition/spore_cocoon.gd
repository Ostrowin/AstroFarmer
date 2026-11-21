class_name SporeCocoon
extends Node3D
## Kokon z grzybni: wyrasta z ziemi, drży i po `hatch_time` pęka; wychodzą z niego stworzenia
## (tworzy je reżyser w sygnale `hatched`). Słychać go z kierunku, więc gracz może się odwrócić.

signal hatched(cocoon: SporeCocoon)

const MODEL := preload("res://art/models/forest/cocoon.glb")

@export var hatch_time := 1.5

var done := false

var _t := 0.0
var _model: Node3D


func _ready() -> void:
	_model = MODEL.instantiate() as Node3D
	add_child(_model)
	ForestProps.apply(_model, "cocoon")
	_model.scale = Vector3(0.2, 0.05, 0.2)
	create_tween().tween_property(_model, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(&"plant", global_position)


func _process(delta: float) -> void:
	if done:
		return
	_t += delta
	# Drży coraz mocniej przed pęknięciem.
	var k := clampf(_t / hatch_time, 0.0, 1.0)
	_model.rotation.z = sin(_t * 30.0) * 0.08 * k
	_model.rotation.x = cos(_t * 27.0) * 0.06 * k
	if _t >= hatch_time:
		_burst()


func _burst() -> void:
	done = true
	Sfx.play(&"snap", global_position)
	Effects.burst(get_parent(), global_position + Vector3(0, 0.8, 0), Color(0.45, 0.95, 1.0), 26)
	hatched.emit(self)
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3(1.4, 0.15, 1.4), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_interval(1.5)
	tween.tween_property(_model, "scale", Vector3(0.01, 0.01, 0.01), 0.6)
	tween.tween_callback(queue_free)
