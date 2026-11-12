class_name Effects
extends RefCounted
## Jednorazowe efekty wizualne: wybuch cząsteczek i przedmiot lecący do plecaka.


static func burst(parent: Node, position: Vector3, color: Color, amount := 24) -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = amount
	particles.lifetime = 0.8
	particles.direction = Vector3.UP
	particles.spread = 55.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.0
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 6
	mesh.rings = 3
	particles.mesh = mesh
	particles.material_override = PlantVisuals.material(color, 0.8)
	parent.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	particles.get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(particles.queue_free)


## Krótki błysk promienia (smuga strzału).
static func beam(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.04
	mesh.bottom_radius = 0.04
	mesh.height = length
	mesh.radial_segments = 6
	var ray := MeshInstance3D.new()
	ray.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	ray.material_override = mat
	parent.add_child(ray)
	ray.global_position = (from + to) * 0.5
	# Cylinder stoi wzdłuż Y: obracamy go w stronę celu.
	var dir := (to - from).normalized()
	var up_hint := Vector3.FORWARD if absf(dir.dot(Vector3.UP)) > 0.99 else Vector3.UP
	ray.global_basis = Basis.looking_at(dir, up_hint) * Basis(Vector3.RIGHT, -PI / 2.0)
	var tween := ray.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tween.tween_callback(ray.queue_free)


## Mała kulka leci od `from` do celu (np. plecaka gracza) i znika.
static func fly_to(parent: Node, from: Vector3, target: Node3D, color: Color, delay := 0.0) -> void:
	var orb := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	mesh.radial_segments = 8
	mesh.rings = 4
	orb.mesh = mesh
	orb.material_override = PlantVisuals.material(color, 1.0)
	parent.add_child(orb)
	orb.global_position = from
	var tween := orb.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(orb, "global_position", from + Vector3(0, 0.8, 0), 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_method(_fly_step.bind(orb, target), 0.0, 1.0, 0.35)
	tween.tween_callback(orb.queue_free)


static func _fly_step(t: float, orb: Node3D, target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	orb.global_position = orb.global_position.lerp(target.global_position + Vector3(0, 1.1, 0), t)
	orb.scale = Vector3.ONE * (1.0 - t * 0.7)
