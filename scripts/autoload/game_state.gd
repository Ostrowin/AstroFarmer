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
## Nowy fakt w bazie danych (Codex). count = ile faktów wpisu znamy teraz.
signal research_added(id: StringName, text: String, count: int)
signal level_unlocked(biome_id: StringName, level: int)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const START_BIOME := &"zielona_dolina"
## Pojemność konewki; woda trzymana jako zasób &"water".
const WATER_CAPACITY := 5
## Konewka po ulepszeniu w warsztacie.
const WATER_CAPACITY_UPGRADED := 8
## Dodatkowe miejsca w plecaku po ulepszeniu w warsztacie.
const BACKPACK_BONUS := 3
## Ile Uwagi planety dodaje wywiezienie 1 sztuki przedmiotu.
const ATTENTION_PER_ITEM := {
	&"sample_glowmoss": 10,
	&"thorn": 3,
	&"crystal": 1,
}
## O tyle spada Uwaga po skromnej wyprawie (bez rzadkich rzeczy) albo porażce.
const ATTENTION_DECAY := 5
## Wyposażenie na start nowej gry.
const STARTING_RESOURCES := {
	&"seed_voidberry": 2,
	&"seed_crystal_bloom": 1,
	&"seed_snapper": 1,
	&"seed_boomshroom": 1,
	&"water": WATER_CAPACITY,
}

## Czas farmy liczony w cyklach: 1 wyprawa = 1 cykl.
var cycle: int = 0
## Odkryte gatunki, minerały, anomalie: id -> true.
var discoveries: Dictionary = {}
## Baza danych: id wpisu -> Array nazw akcji ("scan", "grow"...), które odkryły fakty.
var research: Dictionary = {}
## Zasoby w magazynie bazy: id -> ilość.
var resources: Dictionary = {}
## Stan biomów: id -> {"balance": int (-100..100), "max_level": int}.
## "balance" to Równowaga z dokumentu projektowego.
var biomes: Dictionary = {}
## Uwaga planety (0..100): globalna presja na bazę.
var planet_attention: int = 0
## Rośliny posadzone w bazie (zapisywane przez Farm): lista słowników.
var farm: Array = []
## Budowle postawione w bazie (np. słupki płotu): lista {"id", "x", "y", "z"}.
var structures: Array = []
## Trwałe ulepszenia z warsztatu: id -> true.
var upgrades: Dictionary = {}
## Niepokój fauny 0..100: rośnie co cykl, przy 100 jest najazd na bazę.
var raid_pressure: int = 0
## Plik zapisu; sceny testowe ustawiają własny, żeby nie nadpisać gry.
var save_path: String = SAVE_PATH
## Trwająca wyprawa (null w bazie). Nie jest zapisywana.
var run: RunState = null
## Raport ostatniej wyprawy, pokazywany po powrocie do bazy.
var last_run_report: Dictionary = {}
## Cykle do rozliczenia przez farmę po powrocie do bazy.
var pending_cycles: int = 0
## Pora doby 0..1 (0 = północ, 0.25 = świt, 0.5 = południe, 0.75 = zmierzch).
## Płynie w czasie rzeczywistym w bazie i na wyprawie (DayNight), niezależnie od cykli.
var time_of_day: float = START_TIME


## Doba trwa 10 minut czasu rzeczywistego. Gra zaczyna się rano.
const DAY_SECONDS := 600.0
const START_TIME := 0.33


func advance_time(seconds: float) -> void:
	time_of_day = fposmod(time_of_day + seconds / DAY_SECONDS, 1.0)


## Zegar "HH:MM" dla HUD.
static func clock_text(t: float) -> String:
	var minutes := int(fposmod(t, 1.0) * 1440.0)
	return "%02d:%02d" % [minutes / 60, minutes % 60]


## 0 w dzień, 1 w pełnej nocy, płynnie o świcie (0.21-0.29) i o zmierzchu (0.71-0.79).
static func night_amount(t: float) -> float:
	t = fposmod(t, 1.0)
	if t < 0.21 or t > 0.79:
		return 1.0
	if t < 0.29:
		return 1.0 - smoothstep(0.21, 0.29, t)
	if t > 0.71:
		return smoothstep(0.71, 0.79, t)
	return 0.0


func _ready() -> void:
	reset()


## Czyści cały stan (puste konto, używane też w testach).
func reset() -> void:
	cycle = 0
	time_of_day = START_TIME
	discoveries.clear()
	research.clear()
	resources.clear()
	biomes.clear()
	planet_attention = 0
	farm = []
	structures = []
	upgrades.clear()
	raid_pressure = Raid.START_PRESSURE
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
## options: "meal" (id dania z Meals, zjadane od razu), "level" (poziom łąki).
func start_run(loadout: Dictionary, options: Dictionary = {}) -> RunState:
	var new_run := RunState.new()
	new_run.capacity = backpack_capacity()
	new_run.level = clampi(int(options.get("level", 1)), 1, get_biome(START_BIOME)["max_level"])
	var meal: StringName = options.get("meal", &"")
	if meal != &"" and cook_meal(meal):
		new_run.meal = meal
	for id in loadout:
		var amount := mini(int(loadout[id]), get_resource(id))
		amount = mini(amount, new_run.free_space())
		if amount > 0 and spend_resource(id, amount):
			new_run.backpack[id] = amount
			new_run.loadout[id] = amount
	new_run.ensure_offhand()
	run = new_run
	return new_run


## Kończy wyprawę. Sukces: plecak trafia do magazynu. Porażka: plecak przepada.
## Odkrycia zostają zawsze. Cykl rozlicza baza po powrocie (pending_cycles).
func finish_run(success: bool, cause := "") -> Dictionary:
	var report := {"success": success, "cause": cause, "items": {}, "lost": {}, "discoveries": [], "buffs": [], "attention": 0}
	var attention := -ATTENTION_DECAY
	if run:
		report["discoveries"] = run.discoveries.duplicate()
		report["buffs"] = run.buffs.duplicate()
		if success:
			for id in run.backpack:
				add_resource(id, int(run.backpack[id]))
			report["items"] = run.backpack.duplicate()
			var gained := attention_for(run.backpack)
			if gained > 0:
				attention = gained
		else:
			report["lost"] = run.backpack.duplicate()
	var before := planet_attention
	change_planet_attention(attention)
	report["attention"] = planet_attention - before
	run = null
	pending_cycles += 1
	last_run_report = report
	return report


## Ile Uwagi planety ściągnie wywiezienie tych przedmiotów.
static func attention_for(items: Dictionary) -> int:
	var total := 0
	for id in items:
		total += int(ATTENTION_PER_ITEM.get(id, 0)) * int(items[id])
	return total


# --- Ulepszenia --------------------------------------------------------------

func has_upgrade(id: StringName) -> bool:
	return upgrades.has(id)


func add_upgrade(id: StringName) -> void:
	upgrades[id] = true
	resources_changed.emit()


func water_capacity() -> int:
	return WATER_CAPACITY_UPGRADED if has_upgrade(&"can_mk2") else WATER_CAPACITY


func backpack_capacity() -> int:
	return RunState.BACKPACK_CAPACITY + (BACKPACK_BONUS if has_upgrade(&"backpack_mk2") else 0)


## Zużywa składniki dania z magazynu. Zwraca true, jeśli danie powstało.
func cook_meal(id: StringName) -> bool:
	var meal := Meals.get_meal(id)
	if not Meals.can_cook(meal, resources):
		return false
	var cost: Dictionary = meal["cost"]
	for item in cost:
		spend_resource(item, int(cost[item]))
	return true


# --- Odkrycia ----------------------------------------------------------------

## Odkrywa fakt w bazie danych. Zwraca jego treść albo "" (już znany / brak faktu).
func learn(id: StringName, how: String) -> String:
	var found := Codex.fact(id, how)
	if found.is_empty():
		return ""
	var known: Array = research.get(id, [])
	if known.has(how):
		return ""
	known.append(how)
	research[id] = known
	add_discovery(id)
	research_added.emit(id, found["text"], known.size())
	_check_unlocks()
	return found["text"]


func knows(id: StringName, how: String) -> bool:
	return (research.get(id, []) as Array).has(how)


func max_level() -> int:
	return get_biome(START_BIOME)["max_level"]


func _check_unlocks() -> void:
	if max_level() < 2 and Codex.discovered_count(research, 1) >= Codex.LEVEL2_REQUIRED:
		unlock_biome_level(START_BIOME, 2)
		level_unlocked.emit(START_BIOME, 2)


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
		"research": _stringify_keys(research),
		"resources": _stringify_keys(resources),
		"biomes": _stringify_keys(biomes),
		"planet_attention": planet_attention,
		"farm": farm.duplicate(true),
		"structures": structures.duplicate(true),
		"upgrades": upgrades.keys().map(func(k): return String(k)),
		"raid_pressure": raid_pressure,
		"pending_cycles": pending_cycles,
		"time_of_day": time_of_day,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	# JSON zamienia liczby całkowite na float, więc wszędzie rzutujemy na int.
	cycle = int(data.get("cycle", 0))
	time_of_day = fposmod(float(data.get("time_of_day", START_TIME)), 1.0)
	for id in data.get("discoveries", []):
		discoveries[StringName(id)] = true
	var saved_research: Dictionary = data.get("research", {})
	for id in saved_research:
		research[StringName(id)] = (saved_research[id] as Array).map(func(h): return Codex.RENAMED_HOWS.get(String(h), String(h)))
	# Starsze zapisy: odkrycia ze skanera bez wpisu w bazie danych.
	for id in discoveries:
		if Codex.has_entry(id) and not research.has(id):
			research[id] = ["scan"]
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
	for entry in data.get("structures", []):
		if typeof(entry) == TYPE_DICTIONARY:
			structures.append(entry)
	for id in data.get("upgrades", []):
		# Ogłuszacz Mk2 z wcześniejszych wersji = Pistolet Mk2.
		upgrades[&"pistol_mk2" if String(id) == "stunner_mk2" else StringName(id)] = true
	raid_pressure = int(data.get("raid_pressure", Raid.START_PRESSURE))
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
