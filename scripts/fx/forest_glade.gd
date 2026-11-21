class_name ForestGlade
extends Node3D
## Słoneczna Polana (mini-biom etapu 1): jedyne miejsce, gdzie przez dziurę w kapeluszach wpada
## słońce. Zielona trawa kołysząca się na wietrze, kwiaty, motyle, ciepłe światło. Brzegi zjada
## brunatna zgnilizna (shader ziemi: glade_rot), a na środku pasie stado Rot Shepherd.
## Po pokonaniu pasterza zgnilizna się cofa (cleanse) i Polana staje się bezpieczna.

signal cleansed

@export var terrain_path: NodePath

var rot := 1.0
var shepherd: RotShepherd
var herd: Array[Rotling] = []
var cleared := false

var _terrain: ForestTerrain
var _floor: ShaderMaterial
var _sun: SpotLight3D
var _sun_energy := 9.0
var _cone: MeshInstance3D


func _ready() -> void:
	_terrain = get_node(terrain_path) as ForestTerrain
	var g := _terrain.glade
	if g.z <= 0.0:
		return
	var center := _terrain.glade_point()
	var mesh := _terrain.get_node_or_null("Mesh") as MeshInstance3D
	if mesh:
		_floor = mesh.material_override as ShaderMaterial
	_sun_shaft(center, g.z)
	_grass(center, g.z)
	_butterflies(center, g.z)


func center() -> Vector3:
	return _terrain.glade_point()


func radius() -> float:
	return _terrain.glade.z


## Pasterz i jego zarażone stado (śpi, dopóki gracz nie wejdzie na Polanę).
func spawn_shepherd(level: Node3D, director: SpawnDirector) -> RotShepherd:
	if _terrain.glade.z <= 0.0:
		return null
	var c := center()
	shepherd = RotShepherd.new()
	shepherd.glade = self
	shepherd.director = director
	shepherd.ground_height = _terrain.mesh_height_at
	level.add_child(shepherd)
	shepherd.global_position = c + Vector3(0, 0.2, 0)
	for i in 3:
		var r := Rotling.new()
		r.dormant = true
		r.home = c + Vector3(cos(i * 2.1) * 4.0, 0, sin(i * 2.1) * 4.0)
		r.ground_height = _terrain.mesh_height_at
		level.add_child(r)
		r.global_position = r.home + Vector3(0, 0.3, 0)
		herd.append(r)
	shepherd.killed.connect(func(_c: ForestCreature) -> void: cleanse())
	return shepherd


## Zgnilizna cofa się (płynnie), Polana jest bezpieczna.
func cleanse() -> void:
	if cleared:
		return
	cleared = true
	var tw := create_tween()
	tw.tween_method(_set_rot, rot, 0.0, 4.0)
	cleansed.emit()


func _set_rot(v: float) -> void:
	rot = v
	if _floor:
		_floor.set_shader_parameter("glade_rot", v)


func _sun_shaft(center: Vector3, r: float) -> void:
	_sun = SpotLight3D.new()
	_sun.light_color = Color(1.0, 0.9, 0.65)
	_sun.light_energy = 9.0
	_sun.spot_range = 70.0
	_sun.spot_angle = rad_to_deg(atan(r * 1.1 / 45.0))
	_sun.spot_attenuation = 0.4
	_sun.shadow_enabled = true
	add_child(_sun)
	_sun.global_position = center + Vector3(0, 45, 0)
	_sun.rotation_degrees = Vector3(-90, 0, 0)
	# Widoczna smuga światła (przezroczysty stożek).
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.35
	cm.bottom_radius = r * 1.0
	cm.height = 40.0
	cm.cap_top = false
	cm.cap_bottom = false
	cone.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.0, 0.85, 0.55, 0.012)
	cone.material_override = m
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cone)
	cone.global_position = center + Vector3(0, 20, 0)
	_cone = cone


## Słońce przez dziurę w kapeluszach świeci tylko w dzień.
func _process(_delta: float) -> void:
	if _sun == null:
		return
	var day := 1.0 - GameState.night_amount(GameState.time_of_day)
	_sun.light_energy = _sun_energy * day * (1.5 if cleared else 1.0)
	_cone.visible = day > 0.2


func _grass(center: Vector3, r: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(center.x * 13.0 + center.z * 7.0)
	var blade := _blade_mesh()
	var flower := _flower_mesh()
	var blades: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	for i in 7000:
		var a := rng.randf_range(0, TAU)
		var d := r * 0.95 * sqrt(rng.randf())
		var x := center.x + cos(a) * d
		var z := center.z + sin(a) * d
		var y := _terrain.mesh_height_at(x, z)
		var s := rng.randf_range(0.7, 1.4) * (1.0 - smoothstep(r * 0.7, r * 0.95, d) * 0.6)
		var t := Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(s, s, s)), Vector3(x, y, z) - global_position)
		if i % 22 == 0:
			flowers.append(t)
		else:
			blades.append(t)
	add_child(_multimesh(blade, blades, "GladeGrass"))
	add_child(_multimesh(flower, flowers, "GladeFlowers"))


func _multimesh(mesh: Mesh, list: Array[Transform3D], node_name: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = list.size()
	var rng := RandomNumberGenerator.new()
	for i in list.size():
		mm.set_instance_transform(i, list[i])
		mm.set_instance_color(i, Color(rng.randf(), rng.randf(), rng.randf()))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


## Źdźbło: dwa zwężające się czworokąty na krzyż, kołysane wiatrem w shaderze.
func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var side := Vector3(0.025, 0, 0).rotated(Vector3.UP, k * PI / 2)
		var pts := [-side, side, side * 0.3 + Vector3(0, 0.3, 0), -side * 0.3 + Vector3(0, 0.3, 0), Vector3(0, 0.45, 0)]
		for tri in [[0, 1, 2], [0, 2, 3], [3, 2, 4]]:
			for idx in tri:
				var v: Vector3 = pts[idx]
				st.set_uv(Vector2(0, v.y / 0.45))
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	var mesh := st.commit()
	mesh.surface_set_material(0, _sway_material(Color(0.22, 0.5, 0.14), Color(0.55, 0.85, 0.3)))
	return mesh


func _flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0, 0.42, 0)
	for k in 6:  # płatki
		var a0 := TAU * k / 6.0
		var a1 := a0 + 0.5
		for v in [top, top + Vector3(cos(a0), 0.02, sin(a0)) * 0.07, top + Vector3(cos(a1), 0.02, sin(a1)) * 0.07]:
			st.set_uv(Vector2(1, 1))
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	for v in [Vector3(-0.01, 0, 0), Vector3(0.01, 0, 0), top]:  # łodyżka
		st.set_uv(Vector2(0, v.y / 0.45))
		st.set_normal(Vector3.UP)
		st.add_vertex(v)
	var mesh := st.commit()
	mesh.surface_set_material(0, _sway_material(Color(0.25, 0.5, 0.2), Color(1.0, 0.8, 0.3), true))
	return mesh


func _sway_material(base: Color, tip: Color, flower := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_toon;
uniform vec3 base_col : source_color;
uniform vec3 tip_col : source_color;
uniform bool flower = false;
varying float h;
void vertex() {
	h = UV.y;
	vec3 o = MODEL_MATRIX[3].xyz;
	float w = sin(TIME * 1.7 + o.x * 0.35 + o.z * 0.25) * 0.6 + sin(TIME * 3.1 + o.x * 1.3) * 0.25;
	VERTEX.x += w * 0.09 * h * h;
	VERTEX.z += w * 0.05 * h * h;
}
void fragment() {
	vec3 c = mix(base_col, tip_col, h);
	if (flower && UV.x > 0.5) {
		// Kwiaty w kilku kolorach (żółte, różowe, białe).
		c = mix(vec3(1.0, 0.82, 0.3), vec3(0.95, 0.45, 0.7), step(0.5, COLOR.r));
		c = mix(c, vec3(0.95, 0.95, 0.9), step(0.8, COLOR.g));
	}
	ALBEDO = c * (0.85 + 0.3 * COLOR.b);
	ROUGHNESS = 0.8;
}
"""
	m.shader = sh
	m.set_shader_parameter("base_col", base)
	m.set_shader_parameter("tip_col", tip)
	m.set_shader_parameter("flower", flower)
	return m


func _butterflies(center: Vector3, r: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 8.0
	p.preprocess = 8.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(r * 0.7, 1.0, r * 0.7)
	pm.direction = Vector3(1, 0.2, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.0
	pm.turbulence_noise_scale = 3.0
	pm.color_initial_ramp = _butterfly_colors()
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	p.draw_pass_1 = quad
	add_child(p)
	p.global_position = center + Vector3(0, 1.4, 0)


static func _butterfly_colors() -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.25))
	g.set_color(1, Color(0.6, 0.85, 1.0))
	g.add_point(0.5, Color(1.0, 0.5, 0.8))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
