class_name TrapPlant
extends Node3D
## Rzucone nasiono Snappera: wyrasta w ~1.5 s i łapie pierwsze stworzenie,
## które podejdzie. Znika po złapaniu albo po czasie (tylko na tę wyprawę).

const GROW_TIME := 1.5
const RADIUS := 1.5
const LIFETIME := 30.0
const TRAP_SECONDS := 4.0
const SIZE := 1.4

var _armed := false
var _done := false
var _age := 0.0
var _model: Node3D


func _ready() -> void:
	_model = PlantVisuals.build(PlantCatalog.get_plant(&"snapper"), 2)
	_model.scale = Vector3.ONE * 0.05
	add_child(_model)
	Sfx.play(&"plant", global_position)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_model, "scale", Vector3.ONE * SIZE, GROW_TIME)
	tween.tween_callback(func() -> void: _armed = true)


func _physics_process(delta: float) -> void:
	_age += delta
	if _done:
		return
	if _age > LIFETIME:
		_wilt()
		return
	if not _armed:
		return
	for node in get_tree().get_nodes_in_group("creature"):
		var creature := node as Creature
		if creature == null:
			continue
		var offset := creature.global_position - global_position
		if Vector2(offset.x, offset.z).length() < RADIUS and creature.trap(TRAP_SECONDS):
			_close_jaws()
			_done = true
			get_tree().create_timer(TRAP_SECONDS).timeout.connect(_wilt)
			return


func _close_jaws() -> void:
	Sfx.play(&"snap", global_position)
	var head := _model.get_node_or_null("Head") as Node3D
	if head == null:
		return
	var tween := create_tween().set_parallel()
	tween.tween_property(head.get_node("JawTop"), "rotation:x", 0.0, 0.08)
	tween.tween_property(head.get_node("JawBottom"), "rotation:x", 0.0, 0.08)


func _wilt() -> void:
	_done = true
	var tween := create_tween()
	tween.tween_property(_model, "scale", Vector3.ZERO, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
