class_name PlantCatalog
extends RefCounted
## Spis wszystkich gatunków i nazw przedmiotów.
## preload zamiast skanowania folderu, żeby działało też w eksporcie.

const PLANTS := {
	&"voidberry": preload("res://data/plants/voidberry.tres"),
	&"crystal_bloom": preload("res://data/plants/crystal_bloom.tres"),
	&"snapper": preload("res://data/plants/snapper.tres"),
}


static func get_plant(id: StringName) -> PlantData:
	return PLANTS.get(id)


static func all_ids() -> Array:
	return PLANTS.keys()


## Przedmioty, które nie pochodzą z roślin (próbki, minerały z wypraw).
const OTHER_ITEMS := {
	&"sample_glowmoss": "Próbka: Lśniący mech",
}


## Czytelna nazwa przedmiotu z magazynu.
static func item_name(item_id: StringName) -> String:
	if OTHER_ITEMS.has(item_id):
		return OTHER_ITEMS[item_id]
	var text := String(item_id)
	if text.begins_with("seed_"):
		var plant := get_plant(StringName(text.trim_prefix("seed_")))
		if plant:
			return "Nasiona: %s" % plant.display_name
	for plant: PlantData in PLANTS.values():
		if plant.harvest_item == item_id:
			return plant.harvest_item_name
	return text
