class_name MistySpring
extends StaticBody3D
## Mgliste źródło (tylko poziom 2 łąki): E nabiera porcję wody do plecaka.
## Tylko ta woda budzi nasiono Mgielnika w bazie.

const WATER := Color(0.65, 0.9, 1.0)


func _ready() -> void:
	add_to_group("spring")
	collision_layer = 4
	collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = 1.6
	shape.height = 0.4
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.2
	add_child(collision)

	var pool := CylinderMesh.new()
	pool.top_radius = 1.5
	pool.bottom_radius = 1.5
	pool.height = 0.08
	pool.radial_segments = 16
	var water := _mesh(pool, Vector3(0, 0.06, 0), WATER)
	water.material_override = PlantVisuals.material(WATER, 0.6)
	var stone := SphereMesh.new()
	stone.radius = 0.35
	stone.height = 0.4
	stone.radial_segments = 6
	stone.rings = 3
	for i in 7:
		var angle := TAU * i / 7.0
		_mesh(stone, Vector3(cos(angle) * 1.75, 0.12, sin(angle) * 1.75), Color(0.5, 0.52, 0.62)).scale = Vector3.ONE * (0.8 + 0.3 * sin(i * 2.3))

	var light := OmniLight3D.new()
	light.light_color = WATER
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.position.y = 1.0
	add_child(light)

	# Unosząca się mgiełka.
	var mist := CPUParticles3D.new()
	mist.amount = 24
	mist.lifetime = 3.0
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mist.emission_sphere_radius = 1.2
	mist.direction = Vector3.UP
	mist.spread = 20.0
	mist.gravity = Vector3(0, 0.2, 0)
	mist.initial_velocity_min = 0.1
	mist.initial_velocity_max = 0.3
	mist.scale_amount_min = 0.6
	mist.scale_amount_max = 1.2
	var puff := SphereMesh.new()
	puff.radius = 0.15
	puff.height = 0.3
	puff.radial_segments = 6
	puff.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.95, 1.0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = mat
	mist.mesh = puff
	mist.position.y = 0.3
	add_child(mist)


func get_scan_info() -> Dictionary:
	return {"id": &"misty_spring", "name": "Mgliste źródło"}


func _mesh(mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = PlantVisuals.material(color)
	add_child(instance)
	return instance
