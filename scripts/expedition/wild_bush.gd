class_name WildBush
extends StaticBody3D
## Dziki krzew Voidberry na wyprawie: owoce zjada się na miejscu (leczą Kondycję).

const HEAL := 25.0

var eaten := false
var _model: Node3D
var _data: PlantData


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape := SphereShape3D.new()
	shape.radius = 0.6
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.5
	add_child(collision)
	_data = PlantCatalog.get_plant(&"voidberry")
	_rebuild()


func eat() -> bool:
	if eaten:
		return false
	eaten = true
	Effects.burst(get_parent(), global_position + Vector3(0, 0.6, 0), _data.accent_color)
	_rebuild()
	return true


func get_scan_info() -> Dictionary:
	return {"id": &"voidberry", "name": "Voidberry"}


func _rebuild() -> void:
	if _model:
		_model.queue_free()
	_model = PlantVisuals.build(_data, 1 if eaten else _data.last_stage())
	add_child(_model)
