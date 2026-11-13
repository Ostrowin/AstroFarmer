class_name Recipes
extends RefCounted
## Receptury warsztatu. "upgrade" = trwałe ulepszenie (raz), "item" = przedmiot do magazynu.

const LIST := [
	{
		"id": &"fence", "name": "Fence Posts ×4",
		"desc": "Each post stops 1 pest",
		"cost": {&"crystal": 2}, "gives": {&"fence_post": 4},
	},
	{
		"id": &"can_mk2", "name": "Big Watering Can",
		"desc": "8 water instead of 5",
		"cost": {&"crystal": 3}, "upgrade": true,
	},
	{
		"id": &"backpack_mk2", "name": "Bigger Backpack",
		"desc": "+3 backpack slots",
		"cost": {&"crystal": 4, &"sample_glowmoss": 1}, "upgrade": true,
	},
	{
		"id": &"pistol_mk2", "name": "Pistol Mk2",
		"desc": "More damage, faster shots",
		"cost": {&"crystal": 3, &"thorn": 2}, "upgrade": true,
	},
]


static func get_recipe(id: StringName) -> Dictionary:
	for recipe: Dictionary in LIST:
		if recipe["id"] == id:
			return recipe
	return {}


## "" jeśli można zrobić, inaczej powód.
static func problem(recipe: Dictionary) -> String:
	if recipe.get("upgrade", false) and GameState.has_upgrade(recipe["id"]):
		return "Owned"
	var missing: Array[String] = []
	var cost: Dictionary = recipe["cost"]
	for id in cost:
		var lack := int(cost[id]) - GameState.get_resource(id)
		if lack > 0:
			missing.append("%d× %s" % [lack, PlantCatalog.item_name(id)])
	if not missing.is_empty():
		return "Missing: " + ", ".join(missing)
	return ""


## Zużywa koszt i daje efekt. Zwraca true przy sukcesie.
static func craft(id: StringName) -> bool:
	var recipe := get_recipe(id)
	if recipe.is_empty() or problem(recipe) != "":
		return false
	var cost: Dictionary = recipe["cost"]
	for item in cost:
		GameState.spend_resource(item, int(cost[item]))
		if Codex.CRAFT_SOURCES.has(item):
			GameState.learn(Codex.CRAFT_SOURCES[item], "craft")
	if recipe.get("upgrade", false):
		GameState.add_upgrade(id)
	var gives: Dictionary = recipe.get("gives", {})
	for item in gives:
		GameState.add_resource(item, int(gives[item]))
	return true


static func cost_text(recipe: Dictionary) -> String:
	var parts: Array[String] = []
	var cost: Dictionary = recipe["cost"]
	for id in cost:
		parts.append("%d× %s" % [cost[id], PlantCatalog.item_name(id)])
	return ", ".join(parts)
