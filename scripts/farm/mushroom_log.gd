class_name MushroomLog
extends StaticBody3D
## Mushroom Log (od Sporekinów): kłoda na koziołkach, stawiana na polu siatki jak słupek płotu.
## Co cykl wyrasta na niej jadalny grzyb (do MAX naraz), bez wody i w cieniu.
## E: zbiór grzybów (gdy są), inaczej zabiera kłodę z powrotem do magazynu.

const MODEL := preload("res://art/models/forest/mushroom_log.glb")
const MAX := 3

## Ile grzybów czeka na zbiór (0..MAX).
var mushrooms := 0

var _model: Node3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 1.1, 0.8)
	var collision := CollisionShape3D.new()
	collision.shape = box
	collision.position.y = 0.55
	add_child(collision)
	_model = MODEL.instantiate() as Node3D
	add_child(_model)
	ForestProps.apply(_model, "mushroom_log")
	_refresh()


func grow() -> void:
	if mushrooms < MAX:
		mushrooms += 1
		_refresh()


## Zbiera grzyby; zwraca ile.
func harvest() -> int:
	var got := mushrooms
	mushrooms = 0
	_refresh()
	return got


func get_status() -> String:
	return "Mushroom Log · %d/%d" % [mushrooms, MAX]


## Grzyby na kłodzie (z modelu): pokazuje tyle kęp boczniaków, ile grzybów czeka.
func _refresh() -> void:
	if _model == null:
		return
	var mi := _model.find_children("*", "MeshInstance3D", true, false)
	for m: MeshInstance3D in mi:
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i)
			if src == null:
				continue
			var n := src.resource_name
			if n.begins_with("OysterTop") or n.begins_with("GillOrange") or n.begins_with("StemPale"):
				# Grzyby widać dopiero, gdy coś wyrosło.
				m.set_surface_override_material(i, ForestProps.material(n, "mushroom_log") if mushrooms > 0 else _hidden())
	_model.scale = Vector3.ONE * (1.0 + 0.03 * mushrooms)


static var _hidden_mat: ShaderMaterial


static func _hidden() -> ShaderMaterial:
	if _hidden_mat == null:
		_hidden_mat = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded;\nvoid fragment() { discard; }\n"
		_hidden_mat.shader = sh
	return _hidden_mat
