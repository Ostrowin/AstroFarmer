class_name Workbench
extends StaticBody3D
## Stół warsztatowy w bazie (E otwiera okno receptur).
## Model z Blendera; bez pliku zostaje model z prymitywów.

const MODEL := preload("res://art/models/buildings/workbench.glb")

const WOOD := Color(0.6, 0.42, 0.3)
const METAL := Color(0.55, 0.57, 0.65)


func _ready() -> void:
	add_to_group("workbench")
	collision_layer = 1
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.1, 2.15, 1.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 1.07
	add_child(collision)

	if MODEL:
		add_child(MODEL.instantiate())
		return
	_box(Vector3(2.0, 0.12, 1.0), Vector3(0, 0.92, 0), WOOD)
	for x in [-0.85, 0.85]:
		for z in [-0.38, 0.38]:
			_box(Vector3(0.1, 0.86, 0.1), Vector3(x, 0.43, z), WOOD.darkened(0.25))
	_box(Vector3(1.8, 0.06, 0.8), Vector3(0, 0.3, 0), WOOD.darkened(0.15))
	# Imadło, skrzynka i świecący ekran z recepturami.
	_box(Vector3(0.3, 0.2, 0.25), Vector3(-0.7, 1.08, 0.2), METAL)
	_box(Vector3(0.5, 0.25, 0.35), Vector3(0.55, 1.1, -0.2), Color(0.85, 0.4, 0.3))
	_box(Vector3(0.7, 0.45, 0.05), Vector3(0.0, 1.35, -0.42), Color(0.1, 0.1, 0.15))
	var screen := _box(Vector3(0.62, 0.37, 0.02), Vector3(0.0, 1.35, -0.39), Color(0.35, 0.95, 1.0))
	screen.material_override = PlantVisuals.material(Color(0.35, 0.95, 1.0), 1.4)
	var crystal := CylinderMesh.new()
	crystal.top_radius = 0.0
	crystal.bottom_radius = 0.07
	crystal.height = 0.25
	crystal.radial_segments = 4
	var gem := MeshInstance3D.new()
	gem.mesh = crystal
	gem.position = Vector3(-0.25, 1.11, 0.25)
	gem.material_override = PlantVisuals.material(Color(0.45, 0.95, 1.0), 1.2)
	add_child(gem)


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = PlantVisuals.material(color)
	add_child(instance)
	return instance
