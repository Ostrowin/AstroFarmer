class_name Farm
extends Node3D
## Baza: rośliny (sadzenie, zbiór, wzrost co cykl), słupki płotu
## i najazdy fauny rozstrzygane po wzroście w każdym cyklu. Zapis do GameState.

signal changed
signal cycle_report(lines: Array)
signal raid_resolved(result: Dictionary)

const MAX_SLOPE_NORMAL_Y := 0.85
const REACH := 3.5
const POST_SPACING := 0.8
const POST_TO_PLANT := 0.6
## Słupki bliżej niż to łączą się poprzeczką.
const RAIL_DISTANCE := 2.6

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

## Zwraca "" jeśli można posadzić, w przeciwnym razie powód (do pokazania graczowi).
func placement_problem(data: PlantData, point: Vector3, normal: Vector3, collider: Object, from: Vector3) -> String:
	if GameState.get_resource(data.seed_item()) <= 0:
		return "Brak nasion: %s" % data.display_name
	if collider == null or not (collider is Node and (collider as Node).is_in_group("soil")):
		return "Tu nic nie urośnie: to nie gleba"
	if normal.y < MAX_SLOPE_NORMAL_Y:
		return "Za stromo"
	if Vector2(point.x - from.x, point.z - from.z).length() > REACH:
		return "Za daleko"
	for plant in _plants:
		var spacing := maxf(data.min_spacing, plant.data.min_spacing)
		if Vector2(plant.global_position.x - point.x, plant.global_position.z - point.z).length() < spacing:
			return "Za blisko innej rośliny (min. %.1f m)" % spacing
	for post in _posts:
		if _flat_distance(post.global_position, point) < POST_TO_PLANT:
			return "Za blisko płotu"
	return ""


func post_problem(point: Vector3, normal: Vector3, collider: Object, from: Vector3) -> String:
	if GameState.get_resource(&"fence_post") <= 0:
		return "Brak słupków: zrób je w warsztacie (2 kryształy = 3 słupki)"
	if collider == null or not (collider is Node and (collider as Node).is_in_group("soil")):
		return "Płot stawia się na gruncie"
	if normal.y < MAX_SLOPE_NORMAL_Y:
		return "Za stromo"
	if _flat_distance(point, from) > REACH:
		return "Za daleko"
	for post in _posts:
		if _flat_distance(post.global_position, point) < POST_SPACING:
			return "Za blisko innego słupka"
	for plant in _plants:
		if _flat_distance(plant.global_position, point) < POST_TO_PLANT:
			return "Za blisko rośliny"
	return ""


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
		return "Nie potrzebuje wody"
	if plant.needs_sprout_item():
		var item := plant.data.sprout_item
		if not GameState.spend_resource(item, 1):
			return "%s obudzi tylko %s (poziom 2 łąki)" % [plant.data.display_name, PlantCatalog.item_name(item)]
		GameState.learn(&"misty_spring", "sprout")
	elif not GameState.spend_resource(&"water", 1):
		return "Konewka pusta: napełnij w stawie"
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
	post.global_position = pos
	_posts.append(post)
	return post


## Poprzeczki między bliskimi słupkami: z kilku słupków robi się płot.
func _rebuild_rails() -> void:
	for child in _rails.get_children():
		child.queue_free()
	for i in _posts.size():
		for j in range(i + 1, _posts.size()):
			var a := _posts[i].global_position
			var b := _posts[j].global_position
			var length := _flat_distance(a, b)
			if length > RAIL_DISTANCE or length < 0.01:
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


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _spawn(data: PlantData, pos: Vector3, stage := 0, progress := 0, watered := false, mutation: StringName = &"", fertilized := false) -> Plant:
	var plant := Plant.new()
	plant.setup(data, stage, progress, watered)
	if PlantVisuals.MUTATIONS.has(mutation):
		plant.mutation = mutation
	plant.fertilized = fertilized
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
