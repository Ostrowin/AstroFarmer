class_name RunState
extends RefCounted
## Stan jednej wyprawy: plecak, Przebudzenie, odkrycia z tej wyprawy.
## Nie jest zapisywany: wyjście z gry w trakcie wyprawy liczy się jako porażka.

signal changed
signal threshold_reached(threshold: int)

## Bazowa pojemność plecaka (bez ulepszeń z warsztatu).
const BACKPACK_CAPACITY := 10
const THRESHOLDS: Array[int] = [25, 50, 75, 100]

## Pojemność tej wyprawy (z ulepszeniami); ustawia GameState.start_run.
var capacity := BACKPACK_CAPACITY
## Przedmioty w plecaku: id -> ilość. Wyposażenie z bazy też zajmuje miejsce.
var backpack: Dictionary = {}
## Przebudzenie 0..100: presja w trakcie wyprawy.
var awakening := 0.0
## Nowe odkrycia zrobione na tej wyprawie (same odkrycia są już w GameState).
var discoveries: Array[StringName] = []
## Co gracz zabrał z bazy (do raportu).
var loadout: Dictionary = {}
## Nazwy aktywnych ulepszeń wyprawy.
var buffs: Array[String] = []
## Poziom łąki (2 = Mgliste źródło, Mgielnik).
var level := 1
## Danie z kuchni zjedzone przed wyjściem (id z Meals) albo &"".
var meal: StringName = &""
## Przedmiot w drugiej ręce (PPM): jedno z THROWABLES albo &"".
var offhand: StringName = &""

## Przedmioty, które można włożyć do drugiej ręki i rzucać (PPM).
const THROWABLES: Array[StringName] = [&"seed_snapper", &"seed_boomshroom"]

var _reached: Array[int] = []


func used_space() -> int:
	var total := 0
	for id in backpack:
		total += int(backpack[id])
	return total


func free_space() -> int:
	return capacity - used_space()


func count(id: StringName) -> int:
	return int(backpack.get(id, 0))


## Dodaje tyle, ile się zmieści. Zwraca, ile faktycznie dodano.
func add_item(id: StringName, amount: int) -> int:
	var added := mini(amount, free_space())
	if added > 0:
		backpack[id] = count(id) + added
		changed.emit()
	return added


func remove_item(id: StringName, amount := 1) -> bool:
	if count(id) < amount:
		return false
	backpack[id] = count(id) - amount
	if backpack[id] <= 0:
		backpack.erase(id)
	if id == offhand and count(id) == 0:
		offhand = &""
		ensure_offhand()
	changed.emit()
	return true


# --- Druga ręka (PPM) -------------------------------------------------------

## Rzucane przedmioty, które są w plecaku.
func throwables() -> Array[StringName]:
	var result: Array[StringName] = []
	for id in THROWABLES:
		if count(id) > 0:
			result.append(id)
	return result


## Wkłada przedmiot do drugiej ręki (tylko rzucane, które są w plecaku).
func set_offhand(id: StringName) -> bool:
	if not THROWABLES.has(id) or count(id) <= 0:
		return false
	offhand = id
	changed.emit()
	return true


## Pusta ręka: weź pierwszy rzucany przedmiot z plecaka.
func ensure_offhand() -> void:
	if offhand != &"" and count(offhand) > 0:
		return
	var available := throwables()
	offhand = available[0] if not available.is_empty() else &""


## R: następny rzucany przedmiot.
func cycle_offhand() -> StringName:
	var available := throwables()
	if available.is_empty():
		offhand = &""
	else:
		var index := available.find(offhand)
		offhand = available[(index + 1) % available.size()]
	changed.emit()
	return offhand


func add_awakening(amount: float) -> void:
	awakening = clampf(awakening + amount, 0.0, 100.0)
	for threshold in THRESHOLDS:
		if awakening >= threshold and not _reached.has(threshold):
			_reached.append(threshold)
			threshold_reached.emit(threshold)


func has_reached(threshold: int) -> bool:
	return _reached.has(threshold)
