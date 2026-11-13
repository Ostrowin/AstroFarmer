class_name Meals
extends RefCounted
## Kuchnia ekspedycyjna: jedno danie z upraw przed wyjściem = efekt na całą wyprawę.
## Danie wybiera się na ekranie przygotowania, składniki schodzą z magazynu przy wyjściu
## (GameState.cook_meal).

const LIST := [
	{
		"id": &"salad", "name": "Voidberry Salad",
		"desc": "+25 max health",
		"cost": {&"voidberry": 3}, "effect": "vitality",
	},
	{
		"id": &"tea", "name": "Crystal Tea",
		"desc": "Awakening -25%",
		"cost": {&"crystal": 1, &"voidberry": 1}, "effect": "calm", "awakening_rate": 0.75,
	},
	{
		"id": &"cookies", "name": "Pollen Cookies",
		"desc": "+20% speed",
		"cost": {&"pollen": 1, &"voidberry": 1}, "effect": "speed",
	},
	{
		"id": &"brew", "name": "Mist Brew",
		"desc": "Awakening -50%",
		"cost": {&"mist_fruit": 1}, "effect": "calm", "awakening_rate": 0.5,
	},
	{
		"id": &"moon_tea", "name": "Moon Tea",
		"desc": "Awakening -40%",
		"cost": {&"moon_petal": 1, &"voidberry": 1}, "effect": "calm", "awakening_rate": 0.6,
	},
]


static func get_meal(id: StringName) -> Dictionary:
	for meal: Dictionary in LIST:
		if meal["id"] == id:
			return meal
	return {}


## Czy w magazynie (stock: id -> ilość) są składniki. Czysta funkcja (bez autoloadów).
static func can_cook(meal: Dictionary, stock: Dictionary) -> bool:
	if meal.is_empty():
		return false
	var cost: Dictionary = meal["cost"]
	for item in cost:
		if int(stock.get(item, 0)) < int(cost[item]):
			return false
	return true


static func cost_text(meal: Dictionary) -> String:
	var parts: Array[String] = []
	var cost: Dictionary = meal["cost"]
	for id in cost:
		parts.append("%d× %s" % [cost[id], PlantCatalog.item_name(id)])
	return ", ".join(parts)


## Mnożnik tempa Przebudzenia dla dania (1.0 = bez zmian).
static func awakening_rate(id: StringName) -> float:
	return float(get_meal(id).get("awakening_rate", 1.0))
