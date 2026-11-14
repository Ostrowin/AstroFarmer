extends Node
## Narzędzie: renderuje ikony przedmiotów (art/ui/icons/<id>.png) z modeli znajdziek.
## Uruchamiać w oknie (nie headless): godot --path . res://tests/_make_icons.tscn

const IDS := [
	&"seed_voidberry", &"seed_crystal_bloom", &"seed_snapper", &"seed_boomshroom", &"seed_mistbloom", &"seed_moonpetal",
	&"crystal", &"sample_glowmoss", &"pollen", &"thorn", &"fertilizer", &"water_misty", &"voidberry", &"mist_fruit",
	&"glow_spores", &"starfall_shard", &"lumen_dust", &"moon_petal",
]
## Przedmioty bez modelu znajdźki: model zastępczy.
const EXTRA := {
	&"fence_post": "res://art/models/buildings/fence_post_painted.glb",
	&"moon_petal": "res://art/models/pickups/moonpetal.glb",
	&"lumen_dust": "res://art/models/pickups/pollen.glb",
}
const SIZE := 128

var _vp: SubViewport
var _holder: Node3D
var _cam: Camera3D


func _ready() -> void:
	Stylize.enabled = true
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.95)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 0.85
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	for id in IDS + [&"fence_post"]:
		await _render(id)
	get_tree().quit()


func _render(id: StringName) -> void:
	for c in _holder.get_children():
		c.free()
	var node: Node3D
	if EXTRA.has(id):
		node = (load(EXTRA[id]) as PackedScene).instantiate()
		if id == &"lumen_dust":
			for mi in node.find_children("*", "MeshInstance3D", true, false):
				var m := StandardMaterial3D.new()
				m.albedo_color = Color(0.45, 0.85, 1.0)
				m.emission_enabled = true
				m.emission = Color(0.45, 0.85, 1.0)
				m.emission_energy_multiplier = 0.6
				(mi as MeshInstance3D).material_override = m
	else:
		var p := Pickup.new()
		p.setup(Pickup.entry_for(id))
		p.set_process(false)
		node = p
	_holder.add_child(node)
	for l in node.find_children("*", "Light3D", true, false):
		(l as Light3D).visible = false
	await get_tree().process_frame
	var aabb := _bounds(node)
	var center := aabb.get_center()
	var radius := aabb.size.length() * 0.5
	_cam.size = radius * 2.1
	var dir := Vector3(0.55, 0.45, 1.0).normalized()
	_cam.position = center + dir * (radius * 4.0)
	_cam.look_at(center)
	_cam.near = 0.01
	_cam.far = radius * 10.0
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.save_png("res://art/ui/icons/%s.png" % id)
	print("icon ", id)


static func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.visible:
			continue
		var box := m.global_transform * m.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
