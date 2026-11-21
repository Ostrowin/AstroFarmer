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
	&"moonpetal": {"name": "Moonpetal", "category": "Plants", "level": 1, "facts": [
		{"how": "scan", "text": "A flower that opens only at night.", "hint": "scan one at night"},
		{"how": "grow", "text": "At the base it glows after dark.", "hint": "grow one"},
		{"how": "harvest", "text": "Moon Petals make Moon Tea.", "hint": "harvest one"},
	]},
	&"glowcap": {"name": "Glowcap", "category": "Plants", "level": 1, "facts": [
		{"how": "scan", "text": "Tiny mushrooms that glow and drift spores at night.", "hint": "scan them at night"},
		{"how": "pickup", "text": "The spores can be carried home.", "hint": "collect spores"},
		{"how": "craft", "text": "Spores feed the Bright Lamp.", "hint": "use them at the workbench"},
	]},
	&"starfall": {"name": "Starfall Shard", "category": "Minerals", "level": 1, "facts": [
		{"how": "scan", "text": "A glowing rock that fell from the sky.", "hint": "scan one at night"},
		{"how": "pickup", "text": "Rare. Taking it raises Awakening.", "hint": "pick one up"},
		{"how": "craft", "text": "Powers the Bright Lamp. Shipping it raises Attention.", "hint": "use it at the workbench"},
	]},
	&"lumimoth": {"name": "Lumimoth", "category": "Creatures", "level": 1, "facts": [
		{"how": "scan", "text": "A night moth drawn to your helmet light.", "hint": "scan one at night"},
		{"how": "hit", "text": "Hit, it falls and sheds Lumen Dust.", "hint": "hit one"},
		{"how": "craft", "text": "Lumen Dust feeds the Bright Lamp.", "hint": "use the dust at the workbench"},
	]},
	&"spore_pod": {"name": "Spore Pod", "category": "Plants", "level": 2, "facts": [
		{"how": "scan", "text": "A pod blown here from a distant forest.", "hint": "find it on Meadow II"},
		{"how": "pickup", "text": "It smells of mushrooms and damp shade.", "hint": "pick it up"},
	]},
	# --- Grzybowy Las (forest: zablokowane, dopóki las nie jest odkryty) ---
	&"sporebat": {"name": "Sporebat", "category": "Creatures", "level": 1, "forest": true, "facts": [
		{"how": "scan", "text": "A mushroom bat. Circles above, then dives.", "hint": "scan one"},
		{"how": "hit", "text": "One shot brings it down. Dash aside when it shrieks.", "hint": "hit one"},
		{"how": "kill", "text": "Drops Mycelium Fiber.", "hint": "defeat one"},
	]},
	&"rotling": {"name": "Rotling", "category": "Creatures", "level": 1, "forest": true, "facts": [
		{"how": "scan", "text": "A Muncher taken over by fungus.", "hint": "scan one"},
		{"how": "hit", "text": "Takes three shots. A Snapper holds it.", "hint": "hit one"},
		{"how": "kill", "text": "Bursts into spores and drops Mycelium Fiber.", "hint": "defeat one"},
	]},
	&"spore_tick": {"name": "Spore Tick", "category": "Creatures", "level": 1, "forest": true, "facts": [
		{"how": "scan", "text": "Walks up walls and leaps at you.", "hint": "scan one"},
		{"how": "bite", "text": "Its bite floods you with spores.", "hint": "get bitten"},
		{"how": "hit", "text": "Fragile. Easiest to shoot mid-leap.", "hint": "hit one"},
	]},
	&"rot_thornback": {"name": "Rot Thornback", "category": "Creatures", "level": 1, "forest": true, "facts": [
		{"how": "scan", "text": "A Thornback rotten with fungus.", "hint": "scan one"},
		{"how": "hit", "text": "It paws the ground, then charges in a straight line.", "hint": "hit one"},
		{"how": "kill", "text": "Its growths burst in a spore cloud.", "hint": "defeat one"},
	]},
	&"hammer_cap": {"name": "Hammer Cap", "category": "Creatures", "level": 1, "forest": true, "facts": [
		{"how": "scan", "text": "Grows from canyon walls and slams the floor.", "hint": "scan one"},
		{"how": "wave", "text": "The shockwave runs along the ground. Jump it.", "hint": "get hit by its wave"},
		{"how": "hit", "text": "A shot breaks its swing.", "hint": "hit one"},
	]},
	&"sporekin": {"name": "Sporekin", "category": "Creatures", "level": 1, "forest": true, "facts": [
		{"how": "scan", "text": "Smiling swamp folk. Mushrooms grow on their clothes.", "hint": "scan one"},
		{"how": "visit", "text": "Their village is safe from cocoons.", "hint": "visit the village"},
		{"how": "trade", "text": "They trade plans and goods for fiber and spores.", "hint": "trade with them"},
	]},
	&"rot_shepherd": {"name": "Rot Shepherd", "category": "Creatures", "level": 1, "forest": true, "facts": [
		{"how": "scan", "text": "Herds the rotten flock in the Sunbreak Glade.", "hint": "scan him"},
		{"how": "hit", "text": "Hit the glowing staff while he raises it.", "hint": "hit him"},
		{"how": "kill", "text": "Defeated, the glade heals and a moth follows you.", "hint": "defeat him"},
	]},
	&"puffking": {"name": "The Puffking", "category": "Creatures", "level": 1, "forest": true, "facts": [
		{"how": "scan", "text": "A giant puffball sleeping where the mycelium thickens.", "hint": "scan it"},
		{"how": "hit", "text": "Glowing vents take double damage.", "hint": "hit it"},
		{"how": "kill", "text": "It bursts into three Pufflings that explode.", "hint": "defeat it"},
	]},
	&"mycelium_fiber": {"name": "Mycelium Fiber", "category": "Minerals", "level": 1, "forest": true, "facts": [
		{"how": "scan", "text": "Tough glowing threads from forest creatures.", "hint": "scan some"},
		{"how": "pickup", "text": "Light: one slot per tangle.", "hint": "pick some up"},
		{"how": "craft", "text": "Used for the Spore Mask and Fungicide.", "hint": "use it at the workbench"},
	]},
	&"glade_bloom": {"name": "Glade Bloom", "category": "Plants", "level": 1, "forest": true, "facts": [
		{"how": "scan", "text": "A sun flower from the Sunbreak Glade.", "hint": "scan its seeds"},
		{"how": "grow", "text": "Grows at the base like any flower.", "hint": "grow one"},
		{"how": "harvest", "text": "Gives pollen for Pollen Cookies.", "hint": "harvest one"},
	]},
	&"cluster_shroom": {"name": "Cluster Shroom", "category": "Plants", "level": 1, "forest": true, "facts": [
		{"how": "scan", "text": "A Boomshroom from the Puffking.", "hint": "scan its seeds"},
		{"how": "boom", "text": "Thrown, it bursts into three smaller bombs.", "hint": "throw one"},
		{"how": "grow", "text": "Grows at the base for more seeds.", "hint": "grow one"},
	]},
	&"mushroom_log": {"name": "Mushroom Log", "category": "Plants", "level": 1, "forest": true, "facts": [
		{"how": "place", "text": "A log from the Sporekin, placed at the base.", "hint": "place one"},
		{"how": "harvest", "text": "A mushroom grows each cycle, no water needed.", "hint": "harvest mushrooms"},
		{"how": "cook", "text": "Mushroom Stew slows hallucinations.", "hint": "cook Mushroom Stew"},
	]},
	&"drifter": {"name": "Drifter", "category": "Creatures", "level": 1, "facts": [
		{"how": "scan", "text": "A floating jelly that lights up the night.", "hint": "scan one at night"},
		{"how": "sting", "text": "Its tentacles sting. Keep your distance.", "hint": "get too close"},
		{"how": "hit", "text": "Shot, it pops and drops Lumen Dust.", "hint": "hit one"},
	]},
}

## Jaki wpis odkrywa użycie przedmiotu w warsztacie.
const CRAFT_SOURCES := {
	&"crystal": &"crystal_vein",
	&"sample_glowmoss": &"glowmoss",
	&"glow_spores": &"glowcap",
	&"starfall_shard": &"starfall",
	&"lumen_dust": &"lumimoth",
	&"mycelium_fiber": &"mycelium_fiber",
}

## Stare nazwy akcji z wcześniejszych zapisów -> nowe.
const RENAMED_HOWS := {"stun": "hit"}


## Wpis z Grzybowego Lasu (zablokowany, dopóki las nie jest odkryty; nie liczy się do Meadow II).
static func is_forest(id: StringName) -> bool:
	return ENTRIES.has(id) and bool(ENTRIES[id].get("forest", false))


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
		if int(ENTRIES[id]["level"]) == level and not is_forest(id) and known_count(research, id) > 0:
			count += 1
	return count


static func entry_count(level: int) -> int:
	var count := 0
	for id in ENTRIES:
		if int(ENTRIES[id]["level"]) == level and not is_forest(id):
			count += 1
	return count


## Kompletność bazy danych w procentach (fakty ze wszystkich wpisów do danego poziomu).
static func completion(research: Dictionary, max_level := 2, forest := false) -> int:
	var known := 0
	var total := 0
	for id in ENTRIES:
		if int(ENTRIES[id]["level"]) > max_level or (is_forest(id) and not forest):
			continue
		known += known_count(research, id)
		total += fact_count(id)
	return roundi(100.0 * known / maxf(1.0, total))
