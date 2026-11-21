class_name PropScatter
extends Node3D
## Rozsiewa gotowe rekwizyty (sceny .tscn: skały, grzyby-drzewa, drzewa stożkowe
## i latarniowe) po dużej mapie przy starcie. Układ stały dla danego `layout_seed`.
## Skupia je w grupy szumem (pole skał, gaj grzybów), omija znaczniki i budynki
## poziomu oraz strefy `keep_clear`. Nazwy węzłów biorą prefiks z `names`, bo po nim
## rozpoznają je inne systemy (np. Bioluminescence świeci pod "Mushroom*").
## Musi stać w scenie przed TreeScatter i Bioluminescence (one czytają, co już stoi).

## Sceny rekwizytów i ich wagi.
@export var scenes: Array[PackedScene] = []
@export var weights: Array[float] = []
## Prefiks nazwy węzła dla każdej sceny (np. "Rock", "Mushroom").
@export var names: Array[String] = []
@export var count := 40
@export var layout_seed := 1
@export var half_extents := Vector2(100, 100)
@export var inner_radius := 0.0
## Strefy bez rekwizytów: Vector3(x, z, promień).
@export var keep_clear: Array[Vector3] = []
@export var spacing := 6.0
@export var scale_range := Vector2(0.8, 1.3)
@export_range(0.0, 1.0) var clustering := 0.6
@export var cluster_size := 60.0
## Od tej odległości od kamery rekwizyt znika (płynnie); 0 = zawsze widoczny.
@export var view_distance := 0.0

var _grid := ScatterGrid.new(8.0)


func _ready() -> void:
	if scenes.is_empty():
		return
	_collect_blockers()
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var noise := FastNoiseLite.new()
	noise.seed = layout_seed + 77
	noise.frequency = 1.0 / cluster_size
	var total := 0.0
	for i in scenes.size():
		total += _weight(i)
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 50:
		attempts += 1
		var p := Vector3(rng.randf_range(-half_extents.x, half_extents.x), 0, rng.randf_range(-half_extents.y, half_extents.y))
		if Vector2(p.x, p.z).length() < inner_radius:
			continue
		var n := noise.get_noise_2d(p.x, p.z) * 0.5 + 0.5
		if rng.randf() > lerpf(1.0, smoothstep(0.4, 0.75, n), clustering):
			continue
		if not _clear(p) or not _grid.is_free(p.x, p.z, spacing * 0.5):
			continue
		var pick := rng.randf() * total
		var index := 0
		for i in scenes.size():
			pick -= _weight(i)
			if pick <= 0.0:
				index = i
				break
		var prop := scenes[index].instantiate() as Node3D
		prop.name = "%s_S%d" % [names[index] if index < names.size() else "Prop", placed]
		prop.position = p
		prop.rotation.y = rng.randf() * TAU
		prop.scale = Vector3.ONE * rng.randf_range(scale_range.x, scale_range.y)
		if view_distance > 0.0:
			for g in prop.find_children("*", "GeometryInstance3D", true, false):
				var geo := g as GeometryInstance3D
				geo.visibility_range_end = view_distance  # bez przenikania: dithering kosztuje (patrz TreeMeshes)
		add_child(prop)
		_grid.add(p.x, p.z, spacing * 0.5)
		placed += 1


func _weight(i: int) -> float:
	return weights[i] if i < weights.size() else 1.0


func _clear(p: Vector3) -> bool:
	for zone in keep_clear:
		if Vector2(p.x - zone.x, p.z - zone.y).length() < zone.z:
			return false
	return true


## Znaczniki (miejsca znajdziek), budynki i ręcznie postawione obiekty poziomu.
func _collect_blockers() -> void:
	var level := get_parent()
	if level == null:
		return
	for node in level.find_children("*", "Node3D", true, false):
		if node == self or is_ancestor_of(node) or node.get_parent() is CollisionObject3D:
			continue
		var radius := 0.0
		if node is StaticBody3D and node.name != "Ground" and node.name != "Bounds" and not node.is_in_group("terrain"):
			radius = 3.5
		elif node is Marker3D:
			radius = 2.5
		if radius > 0.0:
			var local := to_local((node as Node3D).global_position)
			_grid.add(local.x, local.z, radius)
