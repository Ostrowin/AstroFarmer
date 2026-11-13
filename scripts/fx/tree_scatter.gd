class_name TreeScatter
extends Node3D
## Rozsiewa generowane drzewa (TreeGenerator) po poziomie przy starcie.
## Każde drzewo ma własne ziarno, więc każde jest inne, ale układ jest stały
## (to samo `layout_seed` = ta sama mapa). Omija miejsca zajęte przez inne obiekty
## poziomu (budynki, skały, drzewa, znaczniki znajdziek) i strefy z `keep_clear`.

## Ile drzew posadzić.
@export var count := 30
## Ziarno układu mapy.
@export var layout_seed := 1
## Prostokąt rozsiewu (środek w 0,0): połowa szerokości X i Z.
@export var half_extents := Vector2(38, 38)
## Bez drzew w tym promieniu od środka (np. farma w bazie).
@export var inner_radius := 0.0
## Strefy bez drzew: Vector3(x, z, promień).
@export var keep_clear: Array[Vector3] = []
## Gatunki i ich wagi.
@export var species: Dictionary = {&"gnarled": 3.0, &"umbrella": 2.0, &"willow": 2.0, &"spooky": 1.0}
## Najmniejsza odległość między drzewami.
@export var spacing := 5.5

var _blockers: Array[Vector3] = []


func _ready() -> void:
	_collect_blockers()
	var spots := _pick_spots()
	for i in spots.size():
		var spot: Dictionary = spots[i]
		var body := StaticBody3D.new()
		body.name = "GenTree%d" % i
		body.collision_layer = 1
		body.collision_mask = 0
		body.add_to_group("obstacle")
		body.position = spot["position"]
		body.rotation.y = spot["yaw"]
		# Pierwsze uruchomienie generuje siatki, kolejne wczytują je z dysku.
		var tree := TreeGenerator.build_cached(spot["species"], spot["seed"])
		tree.scale = Vector3.ONE * float(spot["scale"])
		body.add_child(tree)
		var shape := CylinderShape3D.new()
		shape.radius = 0.4
		shape.height = 2.5
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.y = 1.25
		body.add_child(collision)
		add_child(body)


## Lista drzew do posadzenia: {position, species, seed, yaw, scale}.
func _pick_spots() -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var names: Array = species.keys()
	var total := 0.0
	for n in names:
		total += float(species[n])
	var placed: Array[Vector3] = []
	var out: Array[Dictionary] = []
	var attempts := 0
	while out.size() < count and attempts < count * 60:
		attempts += 1
		var p := Vector3(rng.randf_range(-half_extents.x, half_extents.x), 0, rng.randf_range(-half_extents.y, half_extents.y))
		if Vector2(p.x, p.z).length() < inner_radius or not _free(p, placed):
			continue
		var pick := rng.randf() * total
		var chosen: StringName = names[0]
		for n in names:
			pick -= float(species[n])
			if pick <= 0.0:
				chosen = n
				break
		placed.append(p)
		out.append({"position": p, "species": chosen, "seed": rng.randi(), "yaw": rng.randf() * TAU,
			"scale": rng.randf_range(0.85, 1.2)})
	return out


func _free(p: Vector3, placed: Array[Vector3]) -> bool:
	for zone in keep_clear:
		if Vector2(p.x - zone.x, p.z - zone.y).length() < zone.z:
			return false
	for b in _blockers:
		if Vector2(p.x - b.x, p.z - b.y).length() < b.z:
			return false
	for q in placed:
		if Vector2(p.x - q.x, p.z - q.z).length() < spacing:
			return false
	return true


## Zajęte miejsca: ciała statyczne i znaczniki z rodzica (poza ziemią i granicami).
func _collect_blockers() -> void:
	var level := get_parent()
	if level == null:
		return
	for node in level.find_children("*", "Node3D", true, false):
		if node == self or is_ancestor_of(node) or node.get_parent() is CollisionObject3D:
			continue
		var n := node as Node3D
		var radius := 0.0
		if n is StaticBody3D and n.name != "Ground" and n.name != "Bounds":
			radius = 4.0
		elif n is Marker3D:
			radius = 3.0
		if radius > 0.0:
			var local := to_local(n.global_position)
			_blockers.append(Vector3(local.x, local.z, radius))
