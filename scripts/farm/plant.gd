class_name Plant
extends StaticBody3D
## Pojedyncza posadzona roślina. Rośnie o etap co `cycles_per_stage` cykli,
## jeśli dostała wodę (gdy jej potrzebuje).

const COLLISION_LAYER_PLANTS := 4  # warstwa 3 "plants"
const SNAP_RANGE := 2.0
const WATCH_RANGE := 5.0
const SNAP_COOLDOWN := 1.6

var data: PlantData
var stage := 0
## Cykle spędzone w bieżącym etapie.
var progress := 0
var watered := false

var _model: Node3D
var _soil: MeshInstance3D
var _drop: MeshInstance3D
var _time := 0.0
var _snap_cooldown := 0.0


func setup(plant_data: PlantData, start_stage := 0, start_progress := 0, is_watered := false) -> void:
	data = plant_data
	stage = clampi(start_stage, 0, data.last_stage())
	progress = start_progress
	watered = is_watered
	name = "%s_%d" % [data.id, get_instance_id()]


func _ready() -> void:
	collision_layer = COLLISION_LAYER_PLANTS
	collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = 0.35
	shape.height = 1.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.5
	add_child(collision)

	_soil = MeshInstance3D.new()
	var soil_mesh := CylinderMesh.new()
	soil_mesh.top_radius = 0.38
	soil_mesh.bottom_radius = 0.42
	soil_mesh.height = 0.04
	soil_mesh.radial_segments = 10
	_soil.mesh = soil_mesh
	_soil.position.y = 0.02
	add_child(_soil)

	_drop = MeshInstance3D.new()
	var drop_mesh := SphereMesh.new()
	drop_mesh.radius = 0.08
	drop_mesh.height = 0.2
	drop_mesh.radial_segments = 8
	drop_mesh.rings = 4
	_drop.mesh = drop_mesh
	_drop.material_override = PlantVisuals.material(Color(0.3, 0.7, 1.0), 1.0)
	add_child(_drop)

	_rebuild_model()
	_update_status_visuals()


func _process(delta: float) -> void:
	_time += delta
	if _drop.visible:
		_drop.position.y = 1.05 + sin(_time * 3.0) * 0.06
	if data.shape == PlantData.Shape.SNAPPER and is_ripe():
		_update_snapper(delta)


# --- Stan --------------------------------------------------------------------

func is_ripe() -> bool:
	return stage >= data.last_stage()


func is_thirsty() -> bool:
	return data.needs_water and not watered and not is_ripe()


## Tekst do podpowiedzi, gdy gracz celuje w roślinę.
func status_text() -> String:
	if is_ripe():
		return "%s: gotowa do zbioru" % data.display_name
	var parts := ["%s · etap %d/%d" % [data.display_name, stage + 1, data.stages]]
	if is_thirsty():
		parts.append("potrzebuje wody")
	elif data.needs_water:
		parts.append("podlana")
	if data.cycles_per_stage > 1:
		parts.append("rośnie wolno (%d/%d cykli)" % [progress, data.cycles_per_stage])
	return " · ".join(parts)


func water() -> bool:
	if not data.needs_water or watered or is_ripe():
		return false
	watered = true
	_update_status_visuals()
	return true


## Wywoływane raz na cykl. Zwraca linię raportu albo "".
func advance_cycle() -> String:
	if is_ripe():
		watered = false
		_update_status_visuals()
		return ""
	if data.needs_water and not watered:
		return "%s nie rośnie: brak wody" % data.display_name
	watered = false
	progress += 1
	var report := ""
	if progress >= data.cycles_per_stage:
		progress = 0
		stage += 1
		_rebuild_model()
		bounce()
		if is_ripe():
			report = "%s: gotowa do zbioru!" % data.display_name
	_update_status_visuals()
	return report


func to_dict() -> Dictionary:
	return {
		"id": String(data.id),
		"x": global_position.x, "y": global_position.y, "z": global_position.z,
		"stage": stage, "progress": progress, "watered": watered,
	}


# --- Wygląd ------------------------------------------------------------------

func bounce() -> void:
	if _model == null:
		return
	_model.scale = Vector3.ONE * 0.6
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_model, "scale", Vector3.ONE, 0.45)


func _rebuild_model() -> void:
	if _model:
		_model.queue_free()
	_model = PlantVisuals.build(data, stage)
	add_child(_model)


func _update_status_visuals() -> void:
	if _soil == null:
		return
	var wet := watered or not data.needs_water
	_soil.material_override = PlantVisuals.material(Color(0.3, 0.2, 0.17) if wet else Color(0.55, 0.42, 0.3))
	_drop.visible = is_thirsty()


## Dojrzały Snapper śledzi gracza głową i kłapie, gdy ten podejdzie za blisko.
func _update_snapper(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var head := _model.get_node_or_null("Head") as Node3D
	if player == null or head == null:
		return
	var distance := player.global_position.distance_to(global_position)
	if distance < WATCH_RANGE:
		var local := global_transform.basis.inverse() * (player.global_position - head.global_position)
		head.rotation.y = lerp_angle(head.rotation.y, atan2(-local.x, -local.z), clampf(delta * 5.0, 0.0, 1.0))
	_snap_cooldown -= delta
	if _snap_cooldown <= 0.0 and distance < SNAP_RANGE:
		_snap()


func _snap() -> void:
	_snap_cooldown = SNAP_COOLDOWN
	var top := _model.get_node_or_null("Head/JawTop") as Node3D
	var bottom := _model.get_node_or_null("Head/JawBottom") as Node3D
	if top == null or bottom == null:
		return
	Sfx.play(&"snap", global_position)
	var tween := create_tween().set_parallel()
	tween.tween_property(top, "rotation:x", 0.05, 0.07)
	tween.tween_property(bottom, "rotation:x", -0.05, 0.07)
	tween.chain().tween_interval(0.15)
	tween.chain().tween_property(top, "rotation:x", PlantVisuals.JAW_OPEN, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(bottom, "rotation:x", -PlantVisuals.JAW_OPEN, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
