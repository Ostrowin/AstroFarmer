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
## Bez drzew wewnątrz kwadratu o tej połowie boku (drzewa tylko na obrzeżach, np. na wzgórzach).
@export var ring_inner := 0.0
## Teren (TerrainRing), na którym stoją drzewa; puste = płasko, y = 0.
@export var terrain: NodePath
## Bez kolizji (drzewa poza zasięgiem gracza, np. na wzgórzach za ścianą).
@export var no_collision := false
## Skupienie w gaje (0 = równo po całej mapie, 1 = gęste gaje i puste polany).
@export_range(0.0, 1.0) var clustering := 0.0
## Wielkość gajów i polan w metrach (skala szumu).
@export var cluster_size := 45.0
## Ile różnych drzew na gatunek (siatki generowane raz i współdzielone; 0 = każde inne).
@export var variants := 0
## Od tej odległości od kamery drzewo znika (płynnie); 0 = zawsze widoczne.
@export var view_distance := 0.0
## Do tej odległości pełne drzewo, do `mid_distance` średnie, dalej najlżejsze (gdy view_distance > 0).
@export var near_distance := 25.0
@export var mid_distance := 60.0

var _terrain: TerrainRing
var _grid := ScatterGrid.new(8.0)
var _noise: FastNoiseLite


func _ready() -> void:
	if not terrain.is_empty():
		_terrain = get_node_or_null(terrain) as TerrainRing
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
		# Z bliska pełne drzewo, dalej uproszczone (bez cienia), za view_distance znika.
		var near := near_distance if view_distance > 0.0 else 0.0
		var tree := TreeGenerator.build_cached(spot["species"], spot["seed"], near, view_distance, mid_distance)
		tree.scale = Vector3.ONE * float(spot["scale"])
		body.add_child(tree)
		add_child(body)
		if no_collision:
			continue
		var shape := CylinderShape3D.new()
		shape.radius = 0.4
		shape.height = 2.5
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.y = 1.25
		body.add_child(collision)


## Lista drzew do posadzenia: {position, species, seed, yaw, scale}.
func _pick_spots() -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var names: Array = species.keys()
	var total := 0.0
	for n in names:
		total += float(species[n])
	var out: Array[Dictionary] = []
	var attempts := 0
	if clustering > 0.0:
		_noise = FastNoiseLite.new()
		_noise.seed = layout_seed + 101
		_noise.frequency = 1.0 / cluster_size
	while out.size() < count and attempts < count * 60:
		attempts += 1
		var p := Vector3(rng.randf_range(-half_extents.x, half_extents.x), 0, rng.randf_range(-half_extents.y, half_extents.y))
		if Vector2(p.x, p.z).length() < inner_radius:
			continue
		if ring_inner > 0.0 and maxf(absf(p.x), absf(p.z)) < ring_inner:
			continue
		if _noise and rng.randf() > _density(p):
			continue
		if not _free(p):
			continue
		if _terrain:
			# Trochę w głąb, żeby na zboczu nie wisiał żaden bok pnia.
			p.y = _terrain.height_at(p.x, p.z) - 0.4
		var pick := rng.randf() * total
		var chosen: StringName = names[0]
		for n in names:
			pick -= float(species[n])
			if pick <= 0.0:
				chosen = n
				break
		_grid.add(p.x, p.z, spacing * 0.5)
		var tree_seed := rng.randi()
		if variants > 0:
			tree_seed = tree_seed % variants
		out.append({"position": p, "species": chosen, "seed": tree_seed, "yaw": rng.randf() * TAU,
			"scale": rng.randf_range(0.85, 1.2)})
	return out


## Szansa na drzewo w punkcie: w gajach prawie 1, na polanach prawie 0.
func _density(p: Vector3) -> float:
	var n := _noise.get_noise_2d(p.x, p.z) * 0.5 + 0.5
	return lerpf(1.0, smoothstep(0.35, 0.7, n), clustering)


func _free(p: Vector3) -> bool:
	for zone in keep_clear:
		if Vector2(p.x - zone.x, p.z - zone.y).length() < zone.z:
			return false
	return _grid.is_free(p.x, p.z, spacing * 0.5)


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
		if n is StaticBody3D and n.name != "Ground" and n.name != "Bounds" and not n.is_in_group("terrain"):
			radius = 4.0
		elif n is Marker3D:
			radius = 3.0
		if radius > 0.0:
			var local := to_local(n.global_position)
			# Promień blokady minus pół odstępu drzew (odstęp drzewa dolicza is_free).
			_grid.add(local.x, local.z, maxf(radius - spacing * 0.5, 0.1))
