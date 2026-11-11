class_name Farm
extends Node3D
## Wszystkie rośliny w bazie: sadzenie, zbiór, wzrost co cykl i zapis do GameState.

signal changed
signal cycle_report(lines: Array)

const MAX_SLOPE_NORMAL_Y := 0.85
const REACH := 3.5

var _plants: Array[Plant] = []


func _ready() -> void:
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
	if data.harvest_item != &"":
		var amount := randi_range(data.harvest_amount.x, data.harvest_amount.y)
		if amount > 0:
			gained[data.harvest_item] = amount
	var seeds := randi_range(data.seeds_per_harvest.x, data.seeds_per_harvest.y)
	if seeds > 0:
		gained[data.seed_item()] = seeds
	for item in gained:
		GameState.add_resource(item, gained[item])
	_plants.erase(plant)
	plant.queue_free()
	_sync()
	return gained


# --- Cykle -------------------------------------------------------------------

func _on_cycle_advanced(_cycle: int) -> void:
	var lines: Array[String] = []
	for plant in _plants:
		var line := plant.advance_cycle()
		if line != "":
			lines.append(line)
	_sync()
	cycle_report.emit(lines)


# --- Zapis -------------------------------------------------------------------

func load_from_state() -> void:
	for plant in _plants:
		plant.queue_free()
	_plants.clear()
	for entry: Dictionary in GameState.farm:
		var data := PlantCatalog.get_plant(StringName(entry.get("id", "")))
		if data == null:
			continue
		var pos := Vector3(float(entry.get("x", 0)), float(entry.get("y", 0)), float(entry.get("z", 0)))
		_spawn(data, pos, int(entry.get("stage", 0)), int(entry.get("progress", 0)), bool(entry.get("watered", false)))


func plant_count() -> int:
	return _plants.size()


func _spawn(data: PlantData, pos: Vector3, stage := 0, progress := 0, watered := false) -> Plant:
	var plant := Plant.new()
	plant.setup(data, stage, progress, watered)
	add_child(plant)
	plant.global_position = pos
	# Stały, "losowy" obrót zależny od pozycji: różnorodność bez zapisywania kąta.
	plant.rotation.y = fposmod(pos.x * 12.9898 + pos.z * 78.233, TAU)
	_plants.append(plant)
	return plant


func _sync() -> void:
	GameState.farm = _plants.map(func(p: Plant) -> Dictionary: return p.to_dict())
	changed.emit()
