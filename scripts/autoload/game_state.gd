extends Node
## Globalny stan gry (autoload "GameState").
##
## Trzyma wszystko, co przetrwa między scenami i wyprawami:
## cykl farmy, odkrycia, zasoby, stan biomów i Uwagę planety.
## Zapis do pliku JSON w user://.

signal cycle_advanced(cycle: int)
signal discovery_added(id: StringName)
signal resources_changed
signal biome_changed(biome_id: StringName)
signal planet_attention_changed(value: int)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const START_BIOME := &"zielona_dolina"
## Pojemność konewki; woda trzymana jako zasób &"water".
const WATER_CAPACITY := 5
## Wyposażenie na start nowej gry.
const STARTING_RESOURCES := {
	&"seed_voidberry": 2,
	&"seed_crystal_bloom": 1,
	&"seed_snapper": 1,
	&"water": WATER_CAPACITY,
}

## Czas farmy liczony w cyklach: 1 wyprawa = 1 cykl.
var cycle: int = 0
## Odkryte gatunki, minerały, anomalie: id -> true.
var discoveries: Dictionary = {}
## Zasoby w magazynie bazy: id -> ilość.
var resources: Dictionary = {}
## Stan biomów: id -> {"balance": int (-100..100), "max_level": int}.
## "balance" to Równowaga z dokumentu projektowego.
var biomes: Dictionary = {}
## Uwaga planety (0..100): globalna presja na bazę.
var planet_attention: int = 0
## Rośliny posadzone w bazie (zapisywane przez Farm): lista słowników.
var farm: Array = []
## Plik zapisu; sceny testowe ustawiają własny, żeby nie nadpisać gry.
var save_path: String = SAVE_PATH
## Trwająca wyprawa (null w bazie). Nie jest zapisywana.
var run: RunState = null
## Raport ostatniej wyprawy, pokazywany po powrocie do bazy.
var last_run_report: Dictionary = {}
## Cykle do rozliczenia przez farmę po powrocie do bazy.
var pending_cycles: int = 0


func _ready() -> void:
	reset()


## Czyści cały stan (puste konto, używane też w testach).
func reset() -> void:
	cycle = 0
	discoveries.clear()
	resources.clear()
	biomes.clear()
	planet_attention = 0
	farm = []
	run = null
	last_run_report = {}
	pending_cycles = 0
	_ensure_biome(START_BIOME)


## Nowa gra: czysty stan + wyposażenie startowe.
func new_game() -> void:
	reset()
	for id in STARTING_RESOURCES:
		resources[id] = STARTING_RESOURCES[id]
	resources_changed.emit()


# --- Cykle -------------------------------------------------------------------

func advance_cycle() -> void:
	cycle += 1
	cycle_advanced.emit(cycle)


# --- Wyprawy -----------------------------------------------------------------

## Zaczyna wyprawę: zabiera wyposażenie z magazynu do plecaka.
func start_run(loadout: Dictionary) -> RunState:
	var new_run := RunState.new()
	for id in loadout:
		var amount := mini(int(loadout[id]), get_resource(id))
		amount = mini(amount, new_run.free_space())
		if amount > 0 and spend_resource(id, amount):
			new_run.backpack[id] = amount
			new_run.loadout[id] = amount
	run = new_run
	return new_run


## Kończy wyprawę. Sukces: plecak trafia do magazynu. Porażka: plecak przepada.
## Odkrycia zostają zawsze. Cykl rozlicza baza po powrocie (pending_cycles).
func finish_run(success: bool, cause := "") -> Dictionary:
	var report := {"success": success, "cause": cause, "items": {}, "lost": {}, "discoveries": [], "buffs": []}
	if run:
		report["discoveries"] = run.discoveries.duplicate()
		report["buffs"] = run.buffs.duplicate()
		if success:
			for id in run.backpack:
				add_resource(id, int(run.backpack[id]))
			report["items"] = run.backpack.duplicate()
		else:
			report["lost"] = run.backpack.duplicate()
	run = null
	pending_cycles += 1
	last_run_report = report
	return report


# --- Odkrycia ----------------------------------------------------------------

## Zwraca true, jeśli to nowe odkrycie.
func add_discovery(id: StringName) -> bool:
	if discoveries.has(id):
		return false
	discoveries[id] = true
	discovery_added.emit(id)
	return true


func has_discovery(id: StringName) -> bool:
	return discoveries.has(id)


# --- Zasoby ------------------------------------------------------------------

func add_resource(id: StringName, amount: int) -> void:
	if amount == 0:
		return
	resources[id] = maxi(0, get_resource(id) + amount)
	if resources[id] == 0:
		resources.erase(id)
	resources_changed.emit()


func get_resource(id: StringName) -> int:
	return resources.get(id, 0)


## Zużywa zasób, jeśli jest go wystarczająco. Zwraca true przy sukcesie.
func spend_resource(id: StringName, amount: int) -> bool:
	if get_resource(id) < amount:
		return false
	add_resource(id, -amount)
	return true


# --- Biomy i Równowaga -------------------------------------------------------

func get_biome(id: StringName) -> Dictionary:
	return _ensure_biome(id)


func get_balance(id: StringName) -> int:
	return _ensure_biome(id)["balance"]


## Zmienia Równowagę biomu, przycinając do -100..100.
func change_balance(id: StringName, delta: int) -> void:
	var biome := _ensure_biome(id)
	biome["balance"] = clampi(biome["balance"] + delta, -100, 100)
	biome_changed.emit(id)


func unlock_biome_level(id: StringName, level: int) -> void:
	var biome := _ensure_biome(id)
	if level > biome["max_level"]:
		biome["max_level"] = level
		biome_changed.emit(id)


# --- Uwaga planety -----------------------------------------------------------

func change_planet_attention(delta: int) -> void:
	planet_attention = clampi(planet_attention + delta, 0, 100)
	planet_attention_changed.emit(planet_attention)


# --- Zapis / wczytanie -------------------------------------------------------

func save_game(path: String = "") -> Error:
	if path.is_empty():
		path = save_path
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return OK


func load_game(path: String = "") -> bool:
	if path.is_empty():
		path = save_path
	if not FileAccess.file_exists(path):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("GameState: uszkodzony zapis %s" % path)
		return false
	from_dict(data)
	return true


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"cycle": cycle,
		"discoveries": discoveries.keys().map(func(k): return String(k)),
		"resources": _stringify_keys(resources),
		"biomes": _stringify_keys(biomes),
		"planet_attention": planet_attention,
		"farm": farm.duplicate(true),
		"pending_cycles": pending_cycles,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	# JSON zamienia liczby całkowite na float, więc wszędzie rzutujemy na int.
	cycle = int(data.get("cycle", 0))
	for id in data.get("discoveries", []):
		discoveries[StringName(id)] = true
	var saved_resources: Dictionary = data.get("resources", {})
	for id in saved_resources:
		resources[StringName(id)] = int(saved_resources[id])
	var saved_biomes: Dictionary = data.get("biomes", {})
	for id in saved_biomes:
		var biome := _ensure_biome(StringName(id))
		biome["balance"] = int(saved_biomes[id].get("balance", 0))
		biome["max_level"] = int(saved_biomes[id].get("max_level", 1))
	planet_attention = int(data.get("planet_attention", 0))
	for entry in data.get("farm", []):
		if typeof(entry) == TYPE_DICTIONARY:
			farm.append(entry)
	pending_cycles = int(data.get("pending_cycles", 0))
	resources_changed.emit()


# --- Pomocnicze --------------------------------------------------------------

func _ensure_biome(id: StringName) -> Dictionary:
	if not biomes.has(id):
		biomes[id] = {"balance": 0, "max_level": 1}
	return biomes[id]


func _stringify_keys(source: Dictionary) -> Dictionary:
	var result := {}
	for key in source:
		result[String(key)] = source[key]
	return result
