class_name RunState
extends RefCounted
## Stan jednej wyprawy: plecak, Przebudzenie, odkrycia z tej wyprawy.
## Nie jest zapisywany: wyjście z gry w trakcie wyprawy liczy się jako porażka.

signal changed
signal threshold_reached(threshold: int)

const BACKPACK_CAPACITY := 10
const THRESHOLDS: Array[int] = [25, 50, 75, 100]

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

var _reached: Array[int] = []


func used_space() -> int:
	var total := 0
	for id in backpack:
		total += int(backpack[id])
	return total


func free_space() -> int:
	return BACKPACK_CAPACITY - used_space()


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
	changed.emit()
	return true


func add_awakening(amount: float) -> void:
	awakening = clampf(awakening + amount, 0.0, 100.0)
	for threshold in THRESHOLDS:
		if awakening >= threshold and not _reached.has(threshold):
			_reached.append(threshold)
			threshold_reached.emit(threshold)


func has_reached(threshold: int) -> bool:
	return _reached.has(threshold)
