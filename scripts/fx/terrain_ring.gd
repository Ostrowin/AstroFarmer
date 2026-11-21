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
	var heights := _heights()
	var mesh := _build_mesh(heights)
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
	faces.set_faces(_collision_faces(heights))
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


## Wysokości wszystkich punktów siatki (wiersz po wierszu, od -extent).
func _heights() -> PackedFloat32Array:
	var count := _count()
	var heights := PackedFloat32Array()
	heights.resize(count * count)
	for iz in count:
		var z := -extent + iz * cell
		for ix in count:
			heights[iz * count + ix] = height_at(-extent + ix * cell, z)
	return heights


func _count() -> int:
	return int(ceil(extent * 2.0 / cell)) + 1


## Siatka z indeksami i normalnymi z różnic wysokości (szybko nawet dla dużych map).
## Komórki w całości w płaskim środku zastępuje jeden kwadrat (mniej trójkątów).
func _build_mesh(heights: PackedFloat32Array) -> ArrayMesh:
	var count := _count()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(count * count)
	normals.resize(count * count)
	for iz in count:
		for ix in count:
			var i := iz * count + ix
			var h := heights[i]
			var hl := heights[iz * count + maxi(ix - 1, 0)]
			var hr := heights[iz * count + mini(ix + 1, count - 1)]
			var hu := heights[maxi(iz - 1, 0) * count + ix]
			var hd := heights[mini(iz + 1, count - 1) * count + ix]
			verts[i] = Vector3(-extent + ix * cell, h, -extent + iz * cell)
			normals[i] = Vector3(-(hr - hl) / (2.0 * cell), 1.0, -(hd - hu) / (2.0 * cell)).normalized()
	var inner := flat_half / 1.2  # kwadrat mieszczący się w zaokrąglonym płaskim środku
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var indices := PackedInt32Array()
	for iz in count - 1:
		for ix in count - 1:
			var a := iz * count + ix
			var b := a + 1
			var c := a + count
			var d := c + 1
			var va := verts[a]
			var vd := verts[d]
			if maxf(absf(va.x), absf(vd.x)) <= inner and maxf(absf(va.z), absf(vd.z)) <= inner:
				lo = Vector2(minf(lo.x, va.x), minf(lo.y, va.z))
				hi = Vector2(maxf(hi.x, vd.x), maxf(hi.y, vd.z))
				continue
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	if lo.x < hi.x:
		var base := verts.size()
		for corner in [Vector3(lo.x, 0, lo.y), Vector3(hi.x, 0, lo.y), Vector3(lo.x, 0, hi.y), Vector3(hi.x, 0, hi.y)]:
			verts.append(corner)
			normals.append(Vector3.UP)
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Trójkąty kolizji: tylko zbocza (płaski środek pomijamy) do `collision_extent`.
func _collision_faces(heights: PackedFloat32Array) -> PackedVector3Array:
	var count := _count()
	var faces := PackedVector3Array()
	for iz in count - 1:
		var z0 := -extent + iz * cell
		var z1 := z0 + cell
		if minf(absf(z0), absf(z1)) > collision_extent:
			continue
		for ix in count - 1:
			var x0 := -extent + ix * cell
			var x1 := x0 + cell
			if maxf(maxf(absf(x0), absf(x1)), maxf(absf(z0), absf(z1))) > collision_extent:
				continue
			var i := iz * count + ix
			var ha := heights[i]
			var hb := heights[i + 1]
			var hc := heights[i + count]
			var hd := heights[i + count + 1]
			if ha == 0.0 and hb == 0.0 and hc == 0.0 and hd == 0.0:
				continue
			var a := Vector3(x0, ha, z0)
			var b := Vector3(x1, hb, z0)
			var c := Vector3(x0, hc, z1)
			var d := Vector3(x1, hd, z1)
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
