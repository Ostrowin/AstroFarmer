class_name TerrainRing
extends Node3D
## Teren poziomu: płaski środek (na nim stoi cała gra, y = 0), a wokół wzgórza,
## które rosną do grzbietu i dalej przechodzą w pagórki aż za mgłę.
## Dzięki temu nie widać krawędzi świata.
## Kolizję mają tylko zbocza blisko granic poziomu (płaski środek ma własną
## podłogę "Ground", np. grządki w bazie), więc można wejść kawałek pod górę;
## dalej zatrzymuje niewidzialna ściana poziomu.

## Połowa boku płaskiego środka (zaokrąglony kwadrat).
@export var flat_half := 60.0
## Odległość grzbietu od środka i jego wysokość.
@export var ridge := 92.0
@export var ridge_height := 16.0
## Jak daleko sięga teren (dalej jest już tylko mgła).
@export var extent := 260.0
## Rozmiar oczka siatki w metrach (mniejszy = gładsze wzgórza, więcej trójkątów).
@export var cell := 3.0
## Kolizja zboczy tylko do tej odległości od środka (dalej i tak nie da się dojść).
@export var collision_extent := 90.0
@export var layout_seed := 7
@export var material: Material
## Dzieci tego węzła (np. góry) zostaną postawione na terenie, zagłębione o `snap_sink`.
@export var snap_children_of: NodePath
@export var snap_sink := 4.0

var _noise: FastNoiseLite


func _ready() -> void:
	var verts := _grid()
	var mesh := _build_mesh(verts)
	var instance := MeshInstance3D.new()
	instance.name = "Terrain"
	instance.mesh = mesh
	instance.material_override = material
	instance.set_meta("no_outline", true)
	add_child(instance)
	var body := StaticBody3D.new()
	body.name = "Hills"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("terrain")
	add_child(body)
	var shape := CollisionShape3D.new()
	var faces := ConcavePolygonShape3D.new()
	faces.set_faces(_collision_faces(verts))
	shape.shape = faces
	body.add_child(shape)
	_snap_children()


## Wysokość terenu w punkcie (x, z). W płaskim środku dokładnie 0.
func height_at(x: float, z: float) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = layout_seed
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 0.012
		_noise.fractal_octaves = 4
	var d := _distance(x, z)
	if d <= flat_half:
		return 0.0
	var n := _noise.get_noise_2d(x, z) * 0.5 + 0.5
	var rise := smoothstep(flat_half, ridge, d)
	var h := rise * ridge_height * (0.65 + 0.7 * n)
	# Za grzbietem dalsze pagórki: wyższe i rzadsze, żeby linia horyzontu była nierówna.
	if d > ridge:
		var far := _noise.get_noise_2d(x * 0.45 + 300.0, z * 0.45) * 0.5 + 0.5
		h += smoothstep(ridge, ridge + 60.0, d) * far * ridge_height * 1.4
	# Drobna nierówność, żeby zbocza nie były gładkie jak miska.
	h += rise * _noise.get_noise_2d(x * 4.0, z * 4.0) * 1.2
	return h


## Zaokrąglony kwadrat: rogi łagodne, boki proste jak granice poziomu.
static func _distance(x: float, z: float) -> float:
	return pow(pow(absf(x), 4.0) + pow(absf(z), 4.0), 0.25)


func _grid() -> PackedVector3Array:
	var count := _count()
	var verts := PackedVector3Array()
	verts.resize(count * count)
	for iz in count:
		for ix in count:
			var x := -extent + ix * cell
			var z := -extent + iz * cell
			verts[iz * count + ix] = Vector3(x, height_at(x, z), z)
	return verts


func _count() -> int:
	return int(ceil(extent * 2.0 / cell)) + 1


func _build_mesh(verts: PackedVector3Array) -> ArrayMesh:
	var count := _count()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in count - 1:
		for ix in count - 1:
			var a := verts[iz * count + ix]
			var b := verts[iz * count + ix + 1]
			var c := verts[(iz + 1) * count + ix]
			var d := verts[(iz + 1) * count + ix + 1]
			for v in [a, b, c, b, d, c]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## Trójkąty kolizji: tylko zbocza (płaski środek pomijamy) do `collision_extent`.
func _collision_faces(verts: PackedVector3Array) -> PackedVector3Array:
	var count := _count()
	var faces := PackedVector3Array()
	for iz in count - 1:
		for ix in count - 1:
			var a := verts[iz * count + ix]
			var b := verts[iz * count + ix + 1]
			var c := verts[(iz + 1) * count + ix]
			var d := verts[(iz + 1) * count + ix + 1]
			if maxf(maxf(absf(a.x), absf(d.x)), maxf(absf(a.z), absf(d.z))) > collision_extent:
				continue
			if a.y == 0.0 and b.y == 0.0 and c.y == 0.0 and d.y == 0.0:
				continue
			faces.append_array(PackedVector3Array([a, b, c, b, d, c]))
	return faces


func _snap_children() -> void:
	if snap_children_of.is_empty():
		return
	var holder := get_node_or_null(snap_children_of)
	if holder == null:
		return
	for child in holder.get_children():
		if child is Node3D:
			var n := child as Node3D
			var p := to_local(n.global_position)
			n.global_position.y = to_global(Vector3(p.x, height_at(p.x, p.z) - snap_sink, p.z)).y
