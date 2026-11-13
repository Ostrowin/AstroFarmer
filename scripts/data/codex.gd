class_name Codex
extends RefCounted
## Baza danych: wpisy o roślinach, stworzeniach i minerałach.
## Każdy wpis ma kilka faktów, odkrywanych różnymi akcjami ("how"):
##   scan (skaner Q), grow (wyhodowane w bazie), harvest (zbiór w bazie),
##   eat, hit (trafienie z pistoletu), trap, boom, pickup, craft, repel (obrona w najeździe),
##   raid (przetrwany najazd), sprout (obudzenie Mgielnika).
## Czysta logika: funkcje dostają słownik research z GameState
## (id -> Array nazw "how"), żeby dało się je testować bez autoloadów.

## Ile wpisów poziomu 1 trzeba odkryć, żeby odblokować poziom 2 doliny.
const LEVEL2_REQUIRED := 6

const CATEGORIES := ["Plants", "Creatures", "Minerals"]

const ENTRIES := {
	&"voidberry": {"name": "Voidberry", "category": "Plants", "level": 1, "facts": [
		{"how": "scan", "text": "A wild bush with violet berries.", "hint": "scan a wild bush"},
		{"how": "harvest", "text": "Yields 2-3 berries and 1-2 seeds.", "hint": "harvest one at the base"},
		{"how": "eat", "text": "Berries heal: wild 25, packed 30.", "hint": "eat one on an expedition"},
	]},
	&"crystal_bloom": {"name": "Crystal Bloom", "category": "Plants", "level": 1, "facts": [
		{"how": "scan", "text": "Pulls minerals from the soil into crystals.", "hint": "scan its seeds"},
		{"how": "grow", "text": "Needs no water, but each stage takes 2 cycles.", "hint": "grow one"},
		{"how": "harvest", "text": "Yields crystals. Shipping them raises Attention.", "hint": "harvest one"},
	]},
	&"snapper": {"name": "Snapper", "category": "Plants", "level": 1, "facts": [
		{"how": "scan", "text": "A carnivorous jaw, grown for its seeds.", "hint": "scan its seeds"},
		{"how": "trap", "text": "A thrown seed grows into a 4 s trap.", "hint": "trap something"},
		{"how": "repel", "text": "Ripe, it catches 2 pests within 3 m.", "hint": "defend the farm with it"},
	]},
	&"boomshroom": {"name": "Boomshroom", "category": "Plants", "level": 1, "facts": [
		{"how": "scan", "text": "A mushroom that bursts into spores.", "hint": "scan its seeds"},
		{"how": "boom", "text": "Thrown, it stuns everything within 4 m.", "hint": "stun something with it"},
		{"how": "repel", "text": "Ripe, it blasts 3 pests within 4.5 m.", "hint": "defend the farm with it"},
	]},
	&"pollenbug": {"name": "Pollenbug", "category": "Creatures", "level": 1, "facts": [
		{"how": "scan", "text": "A shy pollinator near wild bushes.", "hint": "scan one"},
		{"how": "hit", "text": "Hit, it drops a ball of pollen.", "hint": "hit one"},
		{"how": "pickup", "text": "Pollen makes Pollen Cookies.", "hint": "pick up pollen"},
	]},
	&"chrupik": {"name": "Muncher", "category": "Creatures", "level": 1, "facts": [
		{"how": "scan", "text": "A herd grazer. Eats wild bushes when the meadow wakes.", "hint": "scan one"},
		{"how": "hit", "text": "Harmless. Flees when hit, drops fertilizer.", "hint": "hit one"},
		{"how": "raid", "text": "Munchers are the ones raiding your farm.", "hint": "survive a raid"},
	]},
	&"thornback": {"name": "Thornback", "category": "Creatures", "level": 1, "facts": [
		{"how": "scan", "text": "A spiny predator sleeping in the north den.", "hint": "scan it from afar"},
		{"how": "hit", "text": "Shooting wakes it. Wounded, it flees; dead, it drops spikes.", "hint": "hit it"},
		{"how": "trap", "text": "A Snapper holds it for 4 s.", "hint": "trap it"},
	]},
	&"glowmoss": {"name": "Glowmoss", "category": "Minerals", "level": 1, "facts": [
		{"how": "scan", "text": "Rare glowing moss in risky spots.", "hint": "scan it"},
		{"how": "pickup", "text": "Picking it up raises Awakening.", "hint": "pick it up"},
		{"how": "craft", "text": "Used for upgrades. Shipping it raises Attention.", "hint": "use it at the workbench"},
	]},
	&"crystal_vein": {"name": "Crystal Vein", "category": "Minerals", "level": 1, "facts": [
		{"how": "scan", "text": "Crystals growing straight from the ground.", "hint": "scan them"},
		{"how": "pickup", "text": "Light: one slot each.", "hint": "pick one up"},
		{"how": "craft", "text": "2 crystals make 4 fence posts.", "hint": "craft something"},
	]},
	&"misty_spring": {"name": "Misty Spring", "category": "Minerals", "level": 2, "facts": [
		{"how": "scan", "text": "A glowing spring on Meadow II.", "hint": "find it on Meadow II"},
		{"how": "pickup", "text": "Water is carried in the backpack.", "hint": "collect water"},
		{"how": "sprout", "text": "Only this water wakes a Mistbloom seed.", "hint": "water a Mistbloom"},
	]},
	&"mistbloom": {"name": "Mistbloom", "category": "Plants", "level": 2, "facts": [
		{"how": "scan", "text": "A hard-shelled seed. Plain water won't wake it.", "hint": "scan its seed"},
		{"how": "grow", "text": "Once awake, it grows and glows in the fog.", "hint": "grow one"},
		{"how": "harvest", "text": "Mist Fruit makes Mist Brew.", "hint": "harvest one"},
	]},
}

## Jaki wpis odkrywa użycie przedmiotu w warsztacie.
const CRAFT_SOURCES := {
	&"crystal": &"crystal_vein",
	&"sample_glowmoss": &"glowmoss",
}

## Stare nazwy akcji z wcześniejszych zapisów -> nowe.
const RENAMED_HOWS := {"stun": "hit"}


static func has_entry(id: StringName) -> bool:
	return ENTRIES.has(id)


static func entry_name(id: StringName) -> String:
	return ENTRIES[id]["name"] if ENTRIES.has(id) else String(id)


## Fakt dla danej akcji albo pusty słownik.
static func fact(id: StringName, how: String) -> Dictionary:
	if not ENTRIES.has(id):
		return {}
	for item: Dictionary in ENTRIES[id]["facts"]:
		if item["how"] == how:
			return item
	return {}


static func known_count(research: Dictionary, id: StringName) -> int:
	return (research.get(id, []) as Array).size()


static func fact_count(id: StringName) -> int:
	return (ENTRIES[id]["facts"] as Array).size()


## Ile wpisów danego poziomu ma choć jeden fakt.
static func discovered_count(research: Dictionary, level: int) -> int:
	var count := 0
	for id in ENTRIES:
		if int(ENTRIES[id]["level"]) == level and known_count(research, id) > 0:
			count += 1
	return count


static func entry_count(level: int) -> int:
	var count := 0
	for id in ENTRIES:
		if int(ENTRIES[id]["level"]) == level:
			count += 1
	return count


## Kompletność bazy danych w procentach (fakty ze wszystkich wpisów do danego poziomu).
static func completion(research: Dictionary, max_level := 2) -> int:
	var known := 0
	var total := 0
	for id in ENTRIES:
		if int(ENTRIES[id]["level"]) > max_level:
			continue
		known += known_count(research, id)
		total += fact_count(id)
	return roundi(100.0 * known / maxf(1.0, total))
