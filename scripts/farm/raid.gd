class_name Raid
extends RefCounted
## Najazd fauny na bazę, rozstrzygany automatycznie (bez walki na żywo).
##
## Niepokój fauny rośnie co cykl, szybciej przy wysokiej Uwadze planety.
## Przy 100 przychodzą Chrupiki i celują w losowe uprawy. Jeśli w zasięgu
## uprawy stoi obrońca z wolną "pojemnością", szkodnik zostaje przegoniony
## i zostawia nawóz. Inaczej uprawa traci etap wzrostu, a kiełek znika.
## Zasada: najazd nigdy nie niszczy więcej niż połowy upraw.
## Czysta logika na słownikach (jak w GameState.farm), żeby dało się ją testować.

## Pierwszy najazd po 3 cyklach przy Uwadze 0.
const START_PRESSURE := 55
const PRESSURE_BASE := 15
const PRESSURE_MAX := 100
## Od tej Uwagi planety najazdy są częstsze i silniejsze.
const ATTENTION_HIGH := 50

## Obrońcy: rośliny-narzędzia (tylko dojrzałe) i budowle.
## radius = zasięg wokół obrońcy, capacity = ilu szkodników przegoni w jednym najeździe.
const DEFENDERS := {
	&"snapper": {"name": "Snapper", "verb": "caught", "radius": 3.0, "capacity": 2},
	&"boomshroom": {"name": "Boomshroom", "verb": "blasted", "radius": 4.5, "capacity": 3},
	&"fence": {"name": "Fence", "verb": "stopped", "radius": 2.0, "capacity": 1},
}


## O ile rośnie Niepokój fauny w jednym cyklu.
static func pressure_gain(attention: int) -> int:
	return PRESSURE_BASE + attention / 2


## Ilu szkodników przyjdzie.
static func pest_count(attention: int) -> int:
	return 3 + attention / 20


static func raid_name(attention: int) -> String:
	return "Great Muncher Swarm" if attention >= ATTENTION_HIGH else "Muncher Swarm"


## Za ile cykli najazd przy obecnym tempie (do HUD i ekranu wyprawy).
static func cycles_until(pressure: int, attention: int) -> int:
	var missing := PRESSURE_MAX - pressure
	if missing <= 0:
		return 1
	var gain := pressure_gain(attention)
	return int(ceil(float(missing) / float(gain)))


## "1 cycle", "3 cycles" (tekst w grze po angielsku).
static func cycles_text(count: int) -> String:
	return "%d %s" % [count, "cycle" if count == 1 else "cycles"]


## Rozstrzyga najazd. `plants` i `structures` w formacie GameState.farm / .structures.
## Zwraca słownik z wynikiem; indeksy w "damaged" / "destroyed" odnoszą się do `plants`.
static func resolve(plants: Array, structures: Array, attention: int, rng: RandomNumberGenerator) -> Dictionary:
	var result := {
		"name": raid_name(attention),
		"pests": pest_count(attention),
		"repelled": {},
		"damaged": {},
		"destroyed": [],
		"idle": 0,
		"fertilizer": 0,
		"defender_hits": [],
		"bites": [],
		"lines": [],
	}

	# Obrońcy z pozostałą pojemnością.
	var defenders: Array = []
	for entry: Dictionary in plants:
		var id := StringName(entry.get("id", ""))
		var data := PlantCatalog.get_plant(id)
		if DEFENDERS.has(id) and data and int(entry.get("stage", 0)) >= data.last_stage():
			defenders.append(_defender(id, entry))
	for entry: Dictionary in structures:
		var id := StringName(entry.get("id", ""))
		if DEFENDERS.has(id):
			defenders.append(_defender(id, entry))

	# Uprawy (nie rośliny-narzędzia) i ich bieżące etapy.
	var alive: Array[int] = []
	var stages := {}
	for i in plants.size():
		var data := PlantCatalog.get_plant(StringName(plants[i].get("id", "")))
		if data and not data.is_tool:
			alive.append(i)
			stages[i] = int(plants[i].get("stage", 0))
	var max_destroyed := alive.size() / 2

	for pest in int(result["pests"]):
		if alive.is_empty():
			result["idle"] += 1
			continue
		var target: int = alive[rng.randi_range(0, alive.size() - 1)]
		var at := _flat(plants[target])
		var guard := _best_defender(defenders, at)
		if not guard.is_empty():
			guard["left"] -= 1
			var gid: StringName = guard["id"]
			result["repelled"][gid] = int(result["repelled"].get(gid, 0)) + 1
			result["fertilizer"] += 1
			result["defender_hits"].append(guard["pos"])
			continue
		if stages[target] > 0:
			stages[target] -= 1
			result["damaged"][target] = int(result["damaged"].get(target, 0)) + 1
			result["bites"].append(Vector3(at.x, 0.0, at.y))
		elif result["destroyed"].size() < max_destroyed:
			result["destroyed"].append(target)
			result["damaged"].erase(target)
			alive.erase(target)
			result["bites"].append(Vector3(at.x, 0.0, at.y))
		else:
			result["idle"] += 1

	result["lines"] = _describe(result, plants)
	return result


static func _defender(id: StringName, entry: Dictionary) -> Dictionary:
	var info: Dictionary = DEFENDERS[id]
	return {
		"id": id,
		"pos": Vector3(float(entry.get("x", 0)), float(entry.get("y", 0)), float(entry.get("z", 0))),
		"radius": float(info["radius"]),
		"left": int(info["capacity"]),
	}


## Najbliższy obrońca z wolną pojemnością, w którego zasięgu jest punkt.
static func _best_defender(defenders: Array, at: Vector2) -> Dictionary:
	var best := {}
	var best_distance := INF
	for guard: Dictionary in defenders:
		if guard["left"] <= 0:
			continue
		var pos: Vector3 = guard["pos"]
		var distance := Vector2(pos.x, pos.z).distance_to(at)
		if distance <= guard["radius"] and distance < best_distance:
			best = guard
			best_distance = distance
	return best


static func _flat(entry: Dictionary) -> Vector2:
	return Vector2(float(entry.get("x", 0)), float(entry.get("z", 0)))


static func _describe(result: Dictionary, plants: Array) -> Array[String]:
	var lines: Array[String] = []
	lines.append("%s (%d)" % [result["name"], result["pests"]])
	var repelled: Dictionary = result["repelled"]
	for id in DEFENDERS:
		if repelled.has(id):
			var info: Dictionary = DEFENDERS[id]
			lines.append("%s %s %d" % [info["name"], info["verb"], repelled[id]])
	var bitten := _count_names(result["damaged"].keys(), plants, result["damaged"])
	if not bitten.is_empty():
		lines.append("Bitten: %s" % bitten)
	var eaten := _count_names(result["destroyed"], plants)
	if not eaten.is_empty():
		lines.append("Eaten: %s" % eaten)
	if result["damaged"].is_empty() and result["destroyed"].is_empty():
		lines.append("Crops safe!")
	if result["fertilizer"] > 0:
		lines.append("+%d Fertilizer" % result["fertilizer"])
	return lines


static func _count_names(indices: Array, plants: Array, weights: Dictionary = {}) -> String:
	var counts := {}
	for index in indices:
		var data := PlantCatalog.get_plant(StringName(plants[index].get("id", "")))
		var label := data.display_name if data else "?"
		counts[label] = int(counts.get(label, 0)) + int(weights.get(index, 1))
	var parts: Array[String] = []
	for label in counts:
		parts.append("%s ×%d" % [label, counts[label]])
	return ", ".join(parts)
