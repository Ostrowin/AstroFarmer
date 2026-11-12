class_name WorkbenchPanel
extends UiPanel
## Okno warsztatu: lista receptur z kosztem i przyciskiem "Zrób".

signal crafted(id: StringName)


func open() -> void:
	_rebuild()
	open_panel(720, 560)


func _rebuild() -> void:
	clear()
	_box.add_child(label("Warsztat", 28))
	_box.add_child(label("Kryształy i próbki z wypraw zamieniasz tu na płot i trwałe ulepszenia.", 16, 660, Color(0.85, 0.85, 0.95)))
	for recipe: Dictionary in Recipes.LIST:
		_box.add_child(_row(recipe))
	_box.add_child(label("W magazynie: %s" % _stock_text(), 15, 660, Color(0.8, 0.95, 1.0)))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(button("Zamknij", close))
	_box.add_child(buttons)


func _row(recipe: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var problem := Recipes.problem(recipe)
	var owned: bool = recipe.get("upgrade", false) and GameState.has_upgrade(recipe["id"])
	text.add_child(label(recipe["name"] + ("  ✓" if owned else ""), 19))
	text.add_child(label(recipe["desc"], 14, 480, Color(0.8, 0.8, 0.9)))
	var cost_color := Color(0.6, 1.0, 0.6) if problem == "" else Color(1.0, 0.6, 0.55)
	text.add_child(label("Koszt: %s" % Recipes.cost_text(recipe) if not owned else "Zrobione", 14, 480, cost_color if not owned else Color(0.7, 0.7, 0.8)))
	row.add_child(text)
	var make := button("Zrób", _craft.bind(recipe["id"]))
	make.disabled = problem != ""
	make.tooltip_text = problem
	row.add_child(make)
	return row


func _craft(id: StringName) -> void:
	if not Recipes.craft(id):
		Sfx.play(&"deny")
		return
	Sfx.play(&"craft")
	crafted.emit(id)
	_rebuild()


static func _stock_text() -> String:
	var parts: Array[String] = []
	for id in [&"crystal", &"sample_glowmoss", &"fence_post"]:
		parts.append("%s: %d" % [PlantCatalog.item_name(id), GameState.get_resource(id)])
	return " · ".join(parts)
