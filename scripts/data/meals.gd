class_name Meals
extends RefCounted
## Kuchnia ekspedycyjna: jedno danie z upraw przed wyjściem = efekt na całą wyprawę.
## Danie wybiera się na ekranie przygotowania, składniki schodzą z magazynu przy wyjściu
## (GameState.cook_meal).

const LIST := [
	{
		"id": &"salad", "name": "Sałatka z Voidberry",
		"desc": "+25 maks. Kondycji na wyprawę",
		"cost": {&"voidberry": 3}, "effect": "vitality",
	},
	{
		"id": &"tea", "name": "Kryształowa herbatka",
		"desc": "Przebudzenie rośnie o 25% wolniej",
		"cost": {&"crystal": 1, &"voidberry": 1}, "effect": "calm", "awakening_rate": 0.75,
	},
	{
		"id": &"cookies", "name": "Pyłkowe ciastka",
		"desc": "+20% szybkości na wyprawę",
		"cost": {&"pollen": 1, &"voidberry": 1}, "effect": "speed",
	},
	{
		"id": &"brew", "name": "Mgielny napar",
		"desc": "Przebudzenie rośnie o połowę wolniej",
		"cost": {&"mist_fruit": 1}, "effect": "calm", "awakening_rate": 0.5,
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
