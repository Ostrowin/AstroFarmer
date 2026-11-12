class_name FencePost
extends StaticBody3D
## Słupek płotu z warsztatu. Blokuje ruch i w najeździe zatrzymuje
## 1 szkodnika w promieniu 2 m. Farm łączy bliskie słupki poprzeczkami.
## E na słupku zabiera go z powrotem do magazynu.

const WOOD := Color(0.62, 0.42, 0.28)
const HEIGHT := 1.1


func _ready() -> void:
	add_to_group("structure")
	collision_layer = 1
	collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = 0.14
	shape.height = HEIGHT
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = HEIGHT * 0.5
	add_child(collision)

	var post := CylinderMesh.new()
	post.top_radius = 0.09
	post.bottom_radius = 0.12
	post.height = HEIGHT
	post.radial_segments = 6
	_mesh(post, Vector3(0, HEIGHT * 0.5, 0), WOOD)
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.1
	tip.height = 0.18
	tip.radial_segments = 6
	_mesh(tip, Vector3(0, HEIGHT + 0.09, 0), WOOD.darkened(0.2))
	# Kryształowy "czujnik" na szczycie: z daleka widać, gdzie stoi płot.
	var gem := SphereMesh.new()
	gem.radius = 0.05
	gem.height = 0.1
	gem.radial_segments = 6
	gem.rings = 3
	var gem_mesh := _mesh(gem, Vector3(0, HEIGHT - 0.12, -0.1), Color(0.45, 0.95, 1.0))
	gem_mesh.material_override = PlantVisuals.material(Color(0.45, 0.95, 1.0), 1.2)


func get_status() -> String:
	var info: Dictionary = Raid.DEFENDERS[&"fence"]
	return "Słupek płotu · zatrzyma %d szkodnika w promieniu %d m · [E] zabierz" % [info["capacity"], int(info["radius"])]


func _mesh(mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = PlantVisuals.material(color)
	add_child(instance)
	return instance
