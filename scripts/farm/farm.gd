class_name Farm
extends Node3D
## Baza: rośliny (sadzenie, zbiór, wzrost co cykl), słupki płotu
## i najazdy fauny rozstrzygane po wzroście w każdym cyklu. Zapis do GameState.
## Sadzenie i budowanie na siatce 1×1 m: każda roślina i słupek zajmuje jedno pole.

signal changed
signal cycle_report(lines: Array)
signal raid_resolved(result: Dictionary)

const MAX_SLOPE_NORMAL_Y := 0.85
const REACH := 3.5
## Bok pola siatki (metry).
const CELL := 1.0

var rng := RandomNumberGenerator.new()

var _plants: Array[Plant] = []
var _posts: Array[FencePost] = []
var _rails: Node3D
var _marks: RaidMarks


func _ready() -> void:
	rng.randomize()
	_rails = Node3D.new()
	_rails.name = "Rails"
	add_child(_rails)
	_marks = RaidMarks.new()
	_marks.name = "RaidMarks"
	add_child(_marks)
	GameState.cycle_advanced.connect(_on_cycle_advanced)


# --- Sadzenie ----------------------------------------------------------------

# --- Siatka -------------------------------------------------------------------

static func cell_of(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.z / CELL))


static func cell_center(cell: Vector2i, y := 0.0) -> Vector3:
	return Vector3((cell.x + 0.5) * CELL, y, (cell.y + 0.5) * CELL)


## Środek pola siatki pod punktem (zachowuje wysokość).
static func snap(point: Vector3) -> Vector3:
	return cell_center(cell_of(point), point.y)


## Roślina albo słupek na danym polu (null = wolne).
func occupant(cell: Vector2i) -> Node3D:
	for plant in _plants:
		if cell_of(plant.global_position) == cell:
			return plant
	for post in _posts:
		if cell_of(post.global_position) == cell:
			return post
	return null


## Wspólne zasady dla sadzenia i budowania na polu pod punktem.
func _cell_problem(point: Vector3, normal: Vector3, collider: Object, from: Vector3, soil_message: String) -> String:
	if collider == null or not (collider is Node and (collider as Node).is_in_group("soil")):
		return soil_message
	if normal.y < MAX_SLOPE_NORMAL_Y:
		return "Too steep"
	if _flat_distance(snap(point), from) > REACH:
		return "Too far"
	var taken := occupant(cell_of(point))
	if taken is Plant:
		return "Occupied"
	if taken is FencePost:
		return "Occupied"
	return ""


## Zwraca "" jeśli można posadzić, w przeciwnym razie powód (do pokazania graczowi).
func placement_problem(data: PlantData, point: Vector3, normal: Vector3, collider: Object, from: Vector3) -> String:
	if GameState.get_resource(data.seed_item()) <= 0:
		return "No seeds"
	return _cell_problem(point, normal, collider, from, "Can't plant here")


func post_problem(point: Vector3, normal: Vector3, collider: Object, from: Vector3) -> String:
	if GameState.get_resource(&"fence_post") <= 0:
		return "No fence posts"
	return _cell_problem(point, normal, collider, from, "Can't build here")


func place_post(point: Vector3) -> FencePost:
	if not GameState.spend_resource(&"fence_post", 1):
		return null
	var post := _spawn_post(point)
	_rebuild_rails()
	_sync()
	return post


func remove_post(post: FencePost) -> void:
	if not _posts.has(post):
		return
	_posts.erase(post)
	post.queue_free()
	GameState.add_resource(&"fence_post", 1)
	_rebuild_rails()
	_sync()


func fertilize(plant: Plant) -> bool:
	if plant.is_ripe() or plant.needs_sprout_item() or not GameState.spend_resource(&"fertilizer", 1):
		return false
	plant.fertilize()
	if plant.is_ripe():
		GameState.learn(plant.data.id, "grow")
	_sync()
	return true


## Podlewa roślinę. Zwraca "" przy sukcesie, inaczej powód.
## Nasiono-zagadka na etapie 0 bierze specjalną wodę zamiast zwykłej.
func water_plant(plant: Plant) -> String:
	if not plant.is_thirsty():
		return "Not thirsty"
	if plant.needs_sprout_item():
		var item := plant.data.sprout_item
		if not GameState.spend_resource(item, 1):
			return "Needs Misty Water"
		GameState.learn(&"misty_spring", "sprout")
	elif not GameState.spend_resource(&"water", 1):
		return "Can is empty"
	plant.water()
	_sync()
	return ""


func plant_seed(data: PlantData, point: Vector3) -> Plant:
	if not GameState.spend_resource(data.seed_item(), 1):
		return null
	var plant := _spawn(data, point)
	plant.bounce()
	_sync()
	return plant


# --- Zbiór -------------------------------------------------------------------

## Zbiera dojrzałą roślinę i usuwa ją. Zwraca {item_id: ilość}.
func harvest(plant: Plant) -> Dictionary:
	if not plant.is_ripe():
		return {}
	var gained := {}
	var data := plant.data
	var bonus := {"harvest_bonus": 0, "seed_bonus": 0}
	if plant.mutation != &"":
		bonus = PlantVisuals.MUTATIONS[plant.mutation]
	var seeds := randi_range(data.seeds_per_harvest.x, data.seeds_per_harvest.y) + int(bonus["seed_bonus"])
	if data.harvest_item != &"":
		var amount := randi_range(data.harvest_amount.x, data.harvest_amount.y) + int(bonus["harvest_bonus"])
		if amount > 0:
			gained[data.harvest_item] = amount
	else:
		seeds += int(bonus["harvest_bonus"])
	if seeds > 0:
		gained[data.seed_item()] = seeds
	for item in gained:
		GameState.add_resource(item, gained[item])
	_plants.erase(plant)
	plant.queue_free()
	GameState.learn(data.id, "harvest")
	_sync()
	return gained


# --- Cykle -------------------------------------------------------------------

func _on_cycle_advanced(_cycle: int) -> void:
	_marks.clear()
	var lines: Array[String] = []
	for plant in _plants:
		var was_ripe := plant.is_ripe()
		var line := plant.advance_cycle()
		if line != "":
			lines.append(line)
		if plant.is_ripe() and not was_ripe:
			GameState.learn(plant.data.id, "grow")
	_sync()
	cycle_report.emit(lines)

	GameState.raid_pressure += Raid.pressure_gain(GameState.planet_attention)
	if GameState.raid_pressure >= Raid.PRESSURE_MAX:
		run_raid()


# --- Najazdy -----------------------------------------------------------------

## Rozstrzyga najazd teraz (wywoływane przy Niepokoju 100; testy wołają wprost).
func run_raid() -> Dictionary:
	GameState.raid_pressure = 0
	var result := Raid.resolve(GameState.farm, GameState.structures, GameState.planet_attention, rng)
	var destroyed: Array = result["destroyed"]
	var damaged: Dictionary = result["damaged"]
	for index in damaged:
		_plants[index].damage(int(damaged[index]))
	var doomed: Array[Plant] = []
	for index in destroyed:
		doomed.append(_plants[index])
	for plant in doomed:
		_plants.erase(plant)
		Effects.burst(self, plant.global_position + Vector3(0, 0.2, 0), Color(0.55, 0.42, 0.3), 12)
		plant.queue_free()
	if result["fertilizer"] > 0:
		GameState.add_resource(&"fertilizer", int(result["fertilizer"]))
	for id in result["repelled"]:
		GameState.learn(id, "repel")
	GameState.learn(&"chrupik", "raid")
	_marks.show_raid(result)
	_sync()
	raid_resolved.emit(result)
	return result


# --- Zapis -------------------------------------------------------------------

func load_from_state() -> void:
	for plant in _plants:
		plant.queue_free()
	_plants.clear()
	for post in _posts:
		post.queue_free()
	_posts.clear()
	_marks.clear()
	for entry: Dictionary in GameState.structures:
		if String(entry.get("id", "")) == "fence":
			_spawn_post(Vector3(float(entry.get("x", 0)), float(entry.get("y", 0)), float(entry.get("z", 0))))
	_rebuild_rails()
	for entry: Dictionary in GameState.farm:
		var data := PlantCatalog.get_plant(StringName(entry.get("id", "")))
		if data == null:
			continue
		var pos := Vector3(float(entry.get("x", 0)), float(entry.get("y", 0)), float(entry.get("z", 0)))
		_spawn(data, pos, int(entry.get("stage", 0)), int(entry.get("progress", 0)), bool(entry.get("watered", false)),
			StringName(entry.get("mutation", "")), bool(entry.get("fertilized", false)))


func plant_count() -> int:
	return _plants.size()


func plants() -> Array[Plant]:
	return _plants


func post_count() -> int:
	return _posts.size()


func _spawn_post(pos: Vector3) -> FencePost:
	var post := FencePost.new()
	add_child(post)
	post.global_position = _free_cell_near(pos)
	_posts.append(post)
	return post


## Czy dwa słupki łączy poprzeczka: sąsiednie pola (także po skosie)
## albo co drugie pole w linii prostej, jeśli między nimi nic nie stoi.
func _rail_between(a: Vector2i, b: Vector2i) -> bool:
	var d := b - a
	if maxi(absi(d.x), absi(d.y)) == 1:
		return true
	if (absi(d.x) == 2 and d.y == 0) or (absi(d.y) == 2 and d.x == 0):
		return occupant(a + d / 2) == null
	return false


## Poprzeczki między bliskimi słupkami: z kilku słupków robi się płot.
func _rebuild_rails() -> void:
	for child in _rails.get_children():
		child.queue_free()
	for i in _posts.size():
		for j in range(i + 1, _posts.size()):
			var a := _posts[i].global_position
			var b := _posts[j].global_position
			var length := _flat_distance(a, b)
			if not _rail_between(cell_of(a), cell_of(b)):
				continue
			for height in [0.45, 0.85]:
				var rail := MeshInstance3D.new()
				var mesh := BoxMesh.new()
				mesh.size = Vector3(0.06, 0.08, length)
				rail.mesh = mesh
				rail.material_override = PlantVisuals.material(FencePost.WOOD.lightened(0.08))
				_rails.add_child(rail)
				var mid := (a + b) * 0.5 + Vector3(0, height, 0)
				rail.global_transform = Transform3D(Basis.looking_at(Vector3(b.x - a.x, 0, b.z - a.z)), mid)


## Środek wolnego pola najbliżej punktu (stare zapisy sprzed siatki trafiają na siatkę).
func _free_cell_near(pos: Vector3) -> Vector3:
	var start := cell_of(pos)
	for radius in 6:
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if maxi(absi(x), absi(z)) != radius:
					continue
				var cell := start + Vector2i(x, z)
				if occupant(cell) == null:
					return cell_center(cell, pos.y)
	return cell_center(start, pos.y)


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _spawn(data: PlantData, pos: Vector3, stage := 0, progress := 0, watered := false, mutation: StringName = &"", fertilized := false) -> Plant:
	var plant := Plant.new()
	plant.setup(data, stage, progress, watered)
	if PlantVisuals.MUTATIONS.has(mutation):
		plant.mutation = mutation
	plant.fertilized = fertilized
	pos = _free_cell_near(pos)
	add_child(plant)
	plant.global_position = pos
	# Stały, "losowy" obrót zależny od pozycji: różnorodność bez zapisywania kąta.
	plant.rotation.y = fposmod(pos.x * 12.9898 + pos.z * 78.233, TAU)
	_plants.append(plant)
	return plant


func _sync() -> void:
	GameState.farm = _plants.map(func(p: Plant) -> Dictionary: return p.to_dict())
	GameState.structures = _posts.map(_post_entry)
	changed.emit()


static func _post_entry(post: FencePost) -> Dictionary:
	var pos := post.global_position
	return {"id": "fence", "x": pos.x, "y": pos.y, "z": pos.z}
