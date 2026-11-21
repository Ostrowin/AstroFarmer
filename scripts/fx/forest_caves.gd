class_name ForestCaves
extends Node3D
## Jaskinie Grzybowego Lasu (miejsca losuje ForestTerrain.caves, tam też jest wyrównana podłoga):
## skalny kopiec z grubą ścianą i łukowym wejściem; w środku ciemno (podłogę przyciemnia shader ziemi),
## na ścianach pulsuje cieniutka grzybnia, świecą małe grzybki, w powietrzu drobne zarodniki,
## na ścianach kępy grzybów. Jaskinia 0 to Grota Zarodników: większa, fioletowa, gęsta od zarodników,
## ze strefą halucynacji (Area3D w grupie "spore_fog").
## Kolizja: trójkąty obu ścian i krawędzi wejścia (od obu stron).

@export var terrain_path: NodePath

const SEG := 44
const RINGS := 16
const THICK := 1.6
const ENTRANCE_HALF := 0.42
const ENTRANCE_H := 4.4
const WALL_SHADER := preload("res://art/materials/cave_wall.gdshader")
const NOISE := preload("res://art/materials/ground_noise.tres")

## Węzeł każdej jaskini (dzieci: ściany, dekoracje, zarodniki, strefa).
var cave_nodes: Array[Node3D] = []

var _terrain: ForestTerrain
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_terrain = get_node(terrain_path) as ForestTerrain
	_noise.seed = _terrain.rng.randi()
	_noise.frequency = 0.12
	_noise.fractal_octaves = 3
	for i in _terrain.caves.size():
		cave_nodes.append(_build_cave(i))


func is_spore_hollow(i: int) -> bool:
	return i == 0


## Punkt tuż przed wejściem jaskini (na zewnątrz).
func entrance_point(i: int) -> Vector3:
	var c := _terrain.caves[i]
	var a := _terrain.cave_facing[i]
	var r := c.z + 3.0
	return _terrain.surface_point(c.x + cos(a) * r, c.y + sin(a) * r)


## Losowy punkt na podłodze w głębi jaskini (dalej od wejścia).
func inside_point(i: int, rng: RandomNumberGenerator) -> Vector3:
	var c := _terrain.caves[i]
	var back := _terrain.cave_facing[i] + PI
	var a := back + rng.randf_range(-1.3, 1.3)
	var d := c.z * rng.randf_range(0.15, 0.6)
	return _terrain.surface_point(c.x + cos(a) * d, c.y + sin(a) * d)


func _height(r: float) -> float:
	return 0.55 * r + 1.0


# --- Budowa jednej jaskini --------------------------------------------------------

func _build_cave(i: int) -> Node3D:
	var c := _terrain.caves[i]
	var spore := is_spore_hollow(i)
	var node := Node3D.new()
	node.name = "SporeHollow" if spore else "Cave%d" % i
	add_child(node)
	node.global_position = Vector3(c.x, c.w, c.y)
	var R := c.z
	var H := _height(R)
	var facing := _terrain.cave_facing[i]
	# Siatki punktów obu ścian.
	var outer: Array = []
	var inner: Array = []
	for ri in RINGS + 1:
		var e := lerpf(-0.14, PI * 0.5, float(ri) / RINGS)
		var row_o: Array[Vector3] = []
		var row_i: Array[Vector3] = []
		for si in SEG + 1:
			var a := TAU * float(si % SEG) / SEG
			var dir := Vector3(cos(a), 0.0, sin(a))
			var rh := pow(maxf(cos(e), 0.0), 0.55)
			var base := dir * rh + Vector3(0, sin(e), 0)
			var wob := _noise.get_noise_3d(dir.x * 8.0 + i * 50.0, sin(e) * 8.0, dir.z * 8.0)
			var po := Vector3(base.x * R, base.y * H, base.z * R) * (1.0 + 0.12 * wob)
			var pin := Vector3(base.x * (R - THICK), base.y * (H - THICK), base.z * (R - THICK)) * (1.0 + 0.07 * wob)
			row_o.append(po)
			row_i.append(pin)
		outer.append(row_o)
		inner.append(row_i)
	# Które czworokąty wycinamy (wejście: łuk o szerokości 2*ENTRANCE_HALF i wysokości ENTRANCE_H).
	var hole: Array = []
	for ri in RINGS:
		var row: Array[bool] = []
		for si in SEG:
			var a := TAU * (si + 0.5) / SEG
			var y := ((outer[ri][si] as Vector3).y + (outer[ri + 1][si] as Vector3).y) * 0.5
			var da := absf(angle_difference(a, facing))
			var arch := ENTRANCE_H * sqrt(maxf(0.0, 1.0 - pow(da / ENTRANCE_HALF, 2.0)))
			row.append(da < ENTRANCE_HALF and y < arch)
		hole.append(row)
	var st_o := SurfaceTool.new()
	st_o.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_i := SurfaceTool.new()
	st_i.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for ri in RINGS:
		for si in SEG:
			if hole[ri][si]:
				_lips(st_o, faces, outer, inner, hole, ri, si)
				continue
			_quad(st_o, faces, outer[ri][si], outer[ri][si + 1], outer[ri + 1][si + 1], outer[ri + 1][si], 1.0)
			_quad(st_i, faces, inner[ri][si], inner[ri + 1][si], inner[ri + 1][si + 1], inner[ri][si + 1], -1.0)
	var mesh := ArrayMesh.new()
	st_o.commit(mesh)
	st_i.commit(mesh)
	mesh.surface_set_material(0, _wall_material(false, spore, node.global_position))
	mesh.surface_set_material(1, _wall_material(true, spore, node.global_position))
	var mi := MeshInstance3D.new()
	mi.name = "Walls"
	mi.mesh = mesh
	mi.set_meta("no_outline", true)
	node.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("cave")
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	node.add_child(body)
	_decorate(node, i, R, H, spore)
	return node


func _quad(st: SurfaceTool, faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, side: float) -> void:
	for tri in [[a, b, c], [a, c, d]]:
		var n: Vector3 = ((tri[1] - tri[0]) as Vector3).cross(tri[2] - tri[0]).normalized() * -1.0
		# Normalna zewnętrzna: od osi kopca; wewnętrzna: do środka.
		var mid: Vector3 = (tri[0] + tri[1] + tri[2]) / 3.0
		var out := Vector3(mid.x, mid.y * 0.4, mid.z).normalized() * side
		if n.dot(out) < 0.0:
			n = -n
		for v in tri:
			st.set_normal(n)
			st.add_vertex(v)
			faces.append(v)


## Krawędź wejścia: tam, gdzie wycięty czworokąt sąsiaduje z pełnym, łączymy ścianę zewnętrzną z wewnętrzną.
func _lips(st: SurfaceTool, faces: PackedVector3Array, outer: Array, inner: Array, hole: Array, ri: int, si: int) -> void:
	var nb := [[ri - 1, si, [ri, si], [ri, si + 1]], [ri + 1, si, [ri + 1, si], [ri + 1, si + 1]],
		[ri, si - 1, [ri, si], [ri + 1, si]], [ri, si + 1, [ri, si + 1], [ri + 1, si + 1]]]
	for e in nb:
		var r2: int = e[0]
		var s2: int = posmod(int(e[1]), SEG)
		if r2 < 0 or r2 >= RINGS or hole[r2][s2]:
			continue
		var p0: Array = e[2]
		var p1: Array = e[3]
		var o0: Vector3 = outer[p0[0]][p0[1]]
		var o1: Vector3 = outer[p1[0]][p1[1]]
		var i0: Vector3 = inner[p0[0]][p0[1]]
		var i1: Vector3 = inner[p1[0]][p1[1]]
		_quad(st, faces, o0, o1, i1, i0, 1.0)


func _wall_material(is_inner: bool, spore: bool, center: Vector3) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WALL_SHADER
	m.set_shader_parameter("noise_tex", NOISE)
	m.set_shader_parameter("inner", is_inner)
	m.set_shader_parameter("spore", spore)
	m.set_shader_parameter("center", center)
	return m


# --- Wnętrze --------------------------------------------------------------------

func _decorate(node: Node3D, i: int, R: float, H: float, spore: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _terrain.rng.randi() + i
	var facing := _terrain.cave_facing[i]
	var c := _terrain.caves[i]
	# Małe świecące grzybki na podłodze (kępy).
	var caps: Array[Transform3D] = []
	for k in (40 if spore else 24):
		var a := rng.randf_range(0, TAU)
		var d := (R - THICK - 0.8) * sqrt(rng.randf())
		var cx := c.x + cos(a) * d
		var cz := c.y + sin(a) * d
		for j in rng.randi_range(3, 8):
			var x := cx + rng.randf_range(-0.6, 0.6)
			var z := cz + rng.randf_range(-0.6, 0.6)
			var s := rng.randf_range(0.05, 0.14)
			var y := _terrain.mesh_height_at(x, z) + rng.randf_range(0.1, 0.45)
			caps.append(Transform3D(Basis.from_scale(Vector3(s, s * 0.55, s)), Vector3(x, y, z) - node.global_position))
	node.add_child(_glowcaps(caps, Color(0.75, 0.4, 1.0) if spore else Color(0.3, 0.6, 1.0)))
	# Kępy grzybów na ścianach (świecące wachlarze, boczniaki) skierowane do środka.
	var wall_props := {"ghost_wall_a": [], "oyster": [], "ruffle": []}
	for k in (22 if spore else 14):
		var a := rng.randf_range(0, TAU)
		if absf(angle_difference(a, facing)) < ENTRANCE_HALF + 0.2:
			continue
		var y := rng.randf_range(0.6, minf(4.5, H * 0.5))
		var e := asin(clampf(y / (H - THICK), 0.0, 0.99))
		var rh := pow(cos(e), 0.55) * (R - THICK) - 0.15
		var p := Vector3(cos(a) * rh, y, sin(a) * rh)
		var inward := Vector3(-cos(a), 0, -sin(a))
		var keys := wall_props.keys()
		var prop: String = keys[rng.randi() % keys.size()]
		var s := rng.randf_range(0.6, 1.3)
		(wall_props[prop] as Array).append(Transform3D(Basis(Vector3.UP.cross(inward).normalized(), Vector3.UP, inward).scaled(Vector3.ONE * s), p))
	for prop: String in wall_props:
		var list: Array = wall_props[prop]
		if list.is_empty():
			continue
		var info := ForestProps.mesh(prop)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = info[0]
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, (list[k] as Transform3D) * (info[1] as Transform3D))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mmi)
	# Drobne zarodniki w powietrzu.
	node.add_child(_spores(R, H, spore))
	if spore:
		var area := Area3D.new()
		area.name = "SporeFog"
		area.add_to_group("spore_fog")
		area.collision_layer = 0
		area.collision_mask = 2  # gracz
		var sphere := SphereShape3D.new()
		sphere.radius = R - THICK
		var cs := CollisionShape3D.new()
		cs.shape = sphere
		area.add_child(cs)
		node.add_child(area)


func _glowcaps(transforms: Array[Transform3D], color: Color) -> MultiMeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	var m := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;
uniform vec3 color : source_color;
varying float phase;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	phase = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831;
}
void fragment() {
	float b = 0.5 + 0.5 * sin(TIME * 1.1 + phase) * sin(TIME * 0.37 + phase * 2.0);
	ALBEDO = color * (0.5 + 0.9 * b);
}
"""
	m.shader = shader
	m.set_shader_parameter("color", color)
	mesh.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for k in transforms.size():
		mm.set_instance_transform(k, transforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Glowcaps"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


func _spores(R: float, H: float, spore: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Spores"
	p.amount = 900 if spore else 260
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.visibility_aabb = AABB(Vector3(-R, 0, -R), Vector3(R * 2, H, R * 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(R * 0.65, H * 0.4, R * 0.65)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.03
	pm.initial_velocity_max = 0.15
	pm.gravity = Vector3(0, -0.03, 0)
	pm.lifetime_randomness = 0.7
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.add_point(0.75, Color(1, 1, 1, 0.8))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_ramp = tex
	p.process_material = pm
	p.position = Vector3(0, H * 0.4, 0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.018, 0.018)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.8, 0.5, 1.0) if spore else Color(0.5, 0.9, 1.0)
	quad.material = mat
	p.draw_pass_1 = quad
	return p
