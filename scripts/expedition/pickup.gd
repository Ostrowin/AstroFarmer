class_name Pickup
extends StaticBody3D
## Znajdźka na wyprawie: nasiona, kryształy, rzadka próbka albo ulepszenie wyprawy.

## Rodzaj: "seed", "crystal", "sample", "artifact".
var kind := "seed"
var item_id: StringName
var amount := 1
## Rzadkie znalezisko mocniej podnosi Przebudzenie.
var rare := false
var scan_id: StringName
var scan_name := ""
var color := Color.WHITE
## Dla "artifact": {"id", "name", "desc"}.
var buff: Dictionary = {}

var _visual: Node3D
var _time := 0.0


func setup(entry: Dictionary) -> void:
	kind = entry.get("kind", "seed")
	item_id = entry.get("item", &"")
	amount = int(entry.get("amount", 1))
	rare = entry.get("rare", false)
	scan_id = entry.get("scan", &"")
	scan_name = entry.get("scan_name", "")
	color = entry.get("color", Color.WHITE)
	buff = entry.get("buff", {})


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.45
	add_child(collision)
	_visual = Node3D.new()
	add_child(_visual)
	_build_visual()
	_time = randf() * TAU


func _process(delta: float) -> void:
	_time += delta
	match kind:
		"artifact":
			_visual.rotation.y += delta * 1.5
			_visual.position.y = 0.25 + sin(_time * 2.0) * 0.1
		"seed":
			_visual.position.y = sin(_time * 2.5) * 0.05
			_visual.rotation.y += delta * 0.6


func display_name() -> String:
	if kind == "artifact":
		return buff.get("name", "Ulepszenie")
	return PlantCatalog.item_name(item_id)


func get_scan_info() -> Dictionary:
	if scan_id == &"":
		return {}
	return {"id": scan_id, "name": scan_name}


func _build_visual() -> void:
	match kind:
		"seed":
			_mesh(_sphere(0.17), Vector3(0, 0.35, 0), color, 1.0)
			_mesh(_sphere(0.12, 0.04), Vector3(0.12, 0.5, 0), Color(0.35, 0.75, 0.4), 0.0, Vector3(0, 0, -0.6))
			_mesh(_cylinder(0.02, 0.2), Vector3(0, 0.12, 0), Color(0.35, 0.6, 0.35))
		"crystal":
			for i in 4:
				var angle := TAU * i / 4.0
				var tilt := Vector3(cos(angle) * 0.4, 0, sin(angle) * 0.4)
				var pos := Vector3(cos(angle) * 0.15, 0.25, sin(angle) * 0.15)
				_mesh(_cone(0.1, 0.5 + 0.12 * i), pos, color, 1.3, tilt)
		"sample":
			for i in 7:
				var angle := TAU * i / 7.0
				var r := 0.18 + 0.12 * (i % 2)
				_mesh(_sphere(0.13 + 0.03 * (i % 3)), Vector3(cos(angle) * r, 0.1, sin(angle) * r), color, 1.6)
			var light := OmniLight3D.new()
			light.light_color = color
			light.light_energy = 1.2
			light.omni_range = 3.0
			light.position.y = 0.6
			add_child(light)
		"artifact":
			var box := BoxMesh.new()
			box.size = Vector3(0.35, 0.35, 0.35)
			_mesh(box, Vector3(0, 0.35, 0), color, 1.4, Vector3(0.6, 0, 0.6))
			_mesh(_cylinder(0.35, 0.12), Vector3(0, -0.2, 0), Color(0.5, 0.48, 0.6))
			var glow := OmniLight3D.new()
			glow.light_color = color
			glow.light_energy = 1.5
			glow.omni_range = 4.0
			glow.position.y = 0.6
			add_child(glow)


func _mesh(mesh: Mesh, pos: Vector3, mesh_color: Color, glow := 0.0, rot := Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rot
	instance.material_override = PlantVisuals.material(mesh_color, glow)
	_visual.add_child(instance)


static func _sphere(radius: float, height := -1.0) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0 if height < 0.0 else height
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	return mesh


static func _cone(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 5
	return mesh
