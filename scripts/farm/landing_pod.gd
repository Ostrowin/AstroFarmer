class_name LandingPod
extends StaticBody3D
## Kapsuła farmera na lądowisku w bazie. Po wyprawie opada z nieba
## (rytuał powrotu), potem stoi na lądowisku jako dekoracja.

const BODY := Color(0.93, 0.93, 0.97)
const STRIPE := Color(1.0, 0.55, 0.2)
const WINDOW := Color(0.35, 0.95, 1.0)
## Model z Blendera: Pad (lądowisko), Capsule (spada z nieba), Hatch (właz w Capsule).
const MODEL := preload("res://art/models/buildings/landing_pod.glb")
const HATCH_OPEN := deg_to_rad(100.0)

var _visual: Node3D
var _flame: MeshInstance3D
var _light: OmniLight3D
var _hatch: Node3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CylinderShape3D.new()
	shape.radius = 0.9
	shape.height = 2.4
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 1.4
	add_child(collision)
	_build()


## Animacja lądowania: kapsuła spada z wysokości, hamuje płomieniem i osiada.
func land(duration := 2.2) -> void:
	_visual.position.y = 32.0
	if _hatch:
		_hatch.rotation.x = 0.0
	_flame.visible = true
	_light.visible = true
	Sfx.play(&"evac", global_position)
	var tween := create_tween()
	tween.tween_property(_visual, "position:y", 0.0, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tween.finished
	_flame.visible = false
	_light.visible = false
	Sfx.play(&"land", global_position)
	Effects.burst(get_parent(), global_position + Vector3(0, 0.2, 0), Color(0.75, 0.68, 0.55), 40)
	_visual.scale = Vector3(1.12, 0.85, 1.12)
	var squash := create_tween()
	squash.tween_property(_visual, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await squash.finished
	if _hatch:
		# Właz otwiera się, gdy gracz wysiada (bez czekania na koniec animacji).
		var open := create_tween()
		open.tween_property(_hatch, "rotation:x", HATCH_OPEN, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _build() -> void:
	if MODEL:
		_build_model()
	else:
		_build_primitive()
	_build_flame()


func _build_model() -> void:
	var model := MODEL.instantiate() as Node3D
	add_child(model)
	_visual = Node3D.new()
	add_child(_visual)
	var capsule := model.get_node("Capsule") as Node3D
	model.remove_child(capsule)
	_visual.add_child(capsule)
	_hatch = capsule.get_node_or_null("Hatch") as Node3D
	if _hatch:
		_hatch.rotation.x = HATCH_OPEN


func _build_primitive() -> void:
	# Lądowisko: płaski krąg z obwódką.
	var pad := CylinderMesh.new()
	pad.top_radius = 2.0
	pad.bottom_radius = 2.1
	pad.height = 0.1
	pad.radial_segments = 16
	_mesh(self, pad, Vector3(0, 0.05, 0), Color(0.55, 0.55, 0.62))
	var ring := TorusMesh.new()
	ring.inner_radius = 1.75
	ring.outer_radius = 1.9
	ring.rings = 24
	ring.ring_segments = 4
	_mesh(self, ring, Vector3(0, 0.11, 0), STRIPE, 0.6)

	_visual = Node3D.new()
	add_child(_visual)
	var body := CapsuleMesh.new()
	body.radius = 0.8
	body.height = 2.4
	body.radial_segments = 14
	body.rings = 6
	_mesh(_visual, body, Vector3(0, 1.55, 0), BODY)
	var stripe := CylinderMesh.new()
	stripe.top_radius = 0.82
	stripe.bottom_radius = 0.82
	stripe.height = 0.22
	stripe.radial_segments = 14
	_mesh(_visual, stripe, Vector3(0, 1.2, 0), STRIPE)
	var window := SphereMesh.new()
	window.radius = 0.36
	window.height = 0.5
	window.radial_segments = 10
	window.rings = 5
	_mesh(_visual, window, Vector3(0, 1.85, 0.62), WINDOW, 1.0)
	var leg := CylinderMesh.new()
	leg.top_radius = 0.06
	leg.bottom_radius = 0.1
	leg.height = 0.8
	leg.radial_segments = 5
	for i in 3:
		var angle := TAU * i / 3.0 + 0.5
		var instance := _mesh(_visual, leg, Vector3(cos(angle) * 0.75, 0.38, sin(angle) * 0.75), Color(0.5, 0.5, 0.58))
		instance.rotation = Vector3(sin(angle) * 0.35, 0, -cos(angle) * 0.35)


func _build_flame() -> void:
	var flame_mesh := CylinderMesh.new()
	flame_mesh.top_radius = 0.45
	flame_mesh.bottom_radius = 0.0
	flame_mesh.height = 1.6
	flame_mesh.radial_segments = 8
	_flame = _mesh(_visual, flame_mesh, Vector3(0, -0.5, 0), Color(1.0, 0.7, 0.3), 3.0)
	_flame.visible = false
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.65, 0.3)
	_light.light_energy = 3.0
	_light.omni_range = 9.0
	_light.position.y = -0.5
	_light.visible = false
	_visual.add_child(_light)


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, glow := 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = PlantVisuals.material(color, glow)
	parent.add_child(instance)
	return instance
