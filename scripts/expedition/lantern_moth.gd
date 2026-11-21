class_name LanternMoth
extends Node3D
## Lantern Moth (towarzysz, nagroda za Rot Shepherda): ćma-latarnia krąży nad graczem
## i świeci ciepłym światłem, mocniej nocą. Działa na każdej wyprawie (ulepszenie "lantern_moth").

const MODEL := preload("res://art/models/creatures/lumimoth.glb")

var target: Node3D

var _t := 0.0
var _light: OmniLight3D


func _ready() -> void:
	add_to_group("lantern_moth")
	var model := MODEL.instantiate() as Node3D
	model.scale = Vector3.ONE * 0.7
	add_child(model)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.8, 0.45)
	_light.omni_range = 9.0
	_light.shadow_enabled = false
	add_child(_light)
	top_level = true
	if target:
		global_position = target.global_position + Vector3(0, 2.5, 0)


func _process(delta: float) -> void:
	_t += delta
	if target == null or not is_instance_valid(target):
		return
	var goal := target.global_position + Vector3(cos(_t * 0.9) * 1.8, 2.7 + sin(_t * 2.1) * 0.25, sin(_t * 0.9) * 1.8)
	global_position = global_position.lerp(goal, minf(delta * 2.5, 1.0))
	var dir := goal - global_position
	if Vector2(dir.x, dir.z).length() > 0.02:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(delta * 4.0, 1.0))
	var night := GameState.night_amount(GameState.time_of_day)
	_light.light_energy = 0.2 + night * 1.0
