class_name Trades
extends RefCounted
## Handel ze Sporekinami (wioska w Grzybowym Lesie). Płaci się tym, co jest w plecaku wyprawy.
## "plan": przepis do warsztatu (wiedza, zostaje na zawsze, także po porażce wyprawy),
## "item": przedmiot do plecaka (trafia do magazynu po udanej ewakuacji).

const LIST := [
	{
		"id": &"plan_spore_mask", "name": "Spore Mask (plan)",
		"desc": "Workbench: a mask against spores",
		"cost": {&"crystal": 2}, "plan": true,
	},
	{
		"id": &"plan_fungicide", "name": "Fungicide (plan)",
		"desc": "Workbench: protects crops from fungus",
		"cost": {&"mycelium_fiber": 2}, "plan": true,
	},
	{
		"id": &"mushroom_log", "name": "Mushroom Log",
		"desc": "Base: grows a mushroom every cycle, no water",
		"cost": {&"mycelium_fiber": 3, &"glow_spores": 1}, "gives": {&"mushroom_log": 1},
	},
	{
		"id": &"boomshroom_seeds", "name": "Boomshroom Seeds ×2",
		"desc": "Throw: stun",
		"cost": {&"glow_spores": 1}, "gives": {&"seed_boomshroom": 2},
	},
	{
		"id": &"glowmoss", "name": "Glowmoss",
		"desc": "Rare sample",
		"cost": {&"mycelium_fiber": 4}, "gives": {&"sample_glowmoss": 1},
	},
]


static func get_offer(id: StringName) -> Dictionary:
	for offer: Dictionary in LIST:
		if offer["id"] == id:
			return offer
	return {}


## "" jeśli można kupić, inaczej powód.
static func problem(offer: Dictionary, run: RunState) -> String:
	if run == null:
		return "No backpack"
	if offer.get("plan", false) and GameState.has_upgrade(offer["id"]):
		return "Known"
	var missing: Array[String] = []
	var cost: Dictionary = offer["cost"]
	for id in cost:
		var lack := int(cost[id]) - run.count(id)
		if lack > 0:
			missing.append("%d× %s" % [lack, PlantCatalog.item_name(id)])
	if not missing.is_empty():
		return "Missing: " + ", ".join(missing)
	var gives: Dictionary = offer.get("gives", {})
	var need := 0
	var paid := 0
	for id in gives:
		need += int(gives[id])
	for id in cost:
		paid += int(cost[id])
	if need > run.free_space() + paid:
		return "Backpack full"
	return ""


static func buy(id: StringName, run: RunState) -> bool:
	var offer := get_offer(id)
	if offer.is_empty() or problem(offer, run) != "":
		return false
	var cost: Dictionary = offer["cost"]
	for item in cost:
		for i in int(cost[item]):
			run.remove_item(item)
	if offer.get("plan", false):
		GameState.add_upgrade(id)
	var gives: Dictionary = offer.get("gives", {})
	for item in gives:
		run.add_item(item, int(gives[item]))
	GameState.learn(&"sporekin", "trade")
	return true


static func cost_text(offer: Dictionary) -> String:
	var parts: Array[String] = []
	var cost: Dictionary = offer["cost"]
	for id in cost:
		parts.append("%d× %s" % [cost[id], PlantCatalog.item_name(id)])
	return ", ".join(parts)
