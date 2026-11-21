class_name ExpeditionPrep
extends PanelContainer
## Okno przygotowania wyprawy: poziom łąki, wyposażenie z magazynu (zajmuje plecak)
## i danie z kuchni ekspedycyjnej (jedno, zjadane przy wyjściu).

## options: {"level": int, "meal": StringName, "biome": StringName (&"meadow" / &"mushroom")}
signal depart(loadout: Dictionary, options: Dictionary)
signal rest
signal cancelled

const OPTIONS := [
	{"id": &"seed_snapper", "label": "Snapper Seeds", "hint": "Throw (RMB): trap", "max": 4},
	{"id": &"seed_boomshroom", "label": "Boomshroom Seeds", "hint": "Throw (RMB): stun", "max": 3},
	{"id": &"seed_cluster_shroom", "label": "Cluster Shroom Seeds", "hint": "Throw (RMB): stun + 3 bombs", "max": 3},
	{"id": &"voidberry", "label": "Voidberry", "hint": "Eat: +30 health", "max": 4},
]

var _counts: Dictionary = {}
var _count_labels: Dictionary = {}
var _space_label: Label
var _planet_label: Label
var _level := 1
## Dokąd: łąka albo Grzybowy Las (na razie wersja testowa, bez odblokowania).
var _biome: StringName = &"meadow"
var _biome_buttons: Dictionary = {}
var _meal: StringName = &""
var _level_buttons: Array[Button] = []
var _meal_buttons: Dictionary = {}
var _meal_label: Label
var _level_label: Label


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -390
	offset_right = 390
	offset_top = -420
	offset_bottom = 420
	theme = NotebookTheme.theme()

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	box.add_child(_label("Expedition", 28))
	var biome_row := HBoxContainer.new()
	biome_row.add_theme_constant_override("separation", 10)
	biome_row.add_child(_label("Place", 18))
	for biome: Array in [[&"meadow", "Wild Meadow"], [&"mushroom", "Mushroom Forest"]]:
		var biome_button := _button(biome[1], _set_biome.bind(biome[0]), 16)
		biome_button.toggle_mode = true
		biome_row.add_child(biome_button)
		_biome_buttons[biome[0]] = biome_button
	box.add_child(biome_row)
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 10)
	level_row.add_child(_label("Level", 18))
	for level in [1, 2]:
		var level_button := _button("I" if level == 1 else "II", _set_level.bind(level), 16)
		level_button.toggle_mode = true
		level_row.add_child(level_button)
		_level_buttons.append(level_button)
	box.add_child(level_row)
	_level_label = _label("", 14, true)
	_level_label.label_settings = NotebookTheme.label_settings(14, NotebookTheme.MUTED, false)
	box.add_child(_level_label)
	_planet_label = _label("", 15, true)
	_planet_label.label_settings = NotebookTheme.label_settings(15, Color("b85a14"))
	box.add_child(_planet_label)

	for option: Dictionary in OPTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(_label(option["label"], 19))
		var hint := _label(option["hint"], 14)
		hint.label_settings = NotebookTheme.label_settings(14, NotebookTheme.MUTED, false)
		text.add_child(hint)
		row.add_child(text)
		row.add_child(_button("-", _change.bind(option["id"], -1)))
		var count := _label("0", 20)
		count.custom_minimum_size = Vector2(90, 0)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(count)
		_count_labels[option["id"]] = count
		row.add_child(_button("+", _change.bind(option["id"], 1)))
		box.add_child(row)

	_space_label = _label("", 17)
	box.add_child(_space_label)

	box.add_child(_label("Meal", 19))
	var meals := HFlowContainer.new()
	meals.add_theme_constant_override("h_separation", 8)
	meals.add_theme_constant_override("v_separation", 6)
	var none := _button("None", _set_meal.bind(&""), 15)
	none.toggle_mode = true
	meals.add_child(none)
	_meal_buttons[&""] = none
	for meal: Dictionary in Meals.LIST:
		var meal_button := _button(meal["name"], _set_meal.bind(meal["id"]), 15)
		meal_button.toggle_mode = true
		meals.add_child(meal_button)
		_meal_buttons[meal["id"]] = meal_button
	box.add_child(meals)
	_meal_label = _label("", 14, true)
	_meal_label.label_settings = NotebookTheme.label_settings(14, Color("2e7d4f"))
	box.add_child(_meal_label)
	box.add_child(_label("Failure loses the backpack.", 14, true))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	buttons.add_child(_button("Go", _on_depart, 20))
	buttons.add_child(_button("Rest a cycle", func() -> void: rest.emit(), 16))
	buttons.add_child(_button("Cancel", func() -> void: cancelled.emit(), 16))
	box.add_child(buttons)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()


func open() -> void:
	for option: Dictionary in OPTIONS:
		var id: StringName = option["id"]
		_counts[id] = mini(1, GameState.get_resource(id))
	_level = clampi(_level, 1, GameState.max_level())
	if not _meal_available(_meal):
		_meal = &""
	_refresh()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_center.call_deferred()


## Wysokość według treści, wyśrodkowane na ekranie.
func _center() -> void:
	var height := get_combined_minimum_size().y
	offset_top = -height * 0.5
	offset_bottom = height * 0.5


func _change(id: StringName, delta: int) -> void:
	var option: Dictionary = OPTIONS.filter(func(o: Dictionary) -> bool: return o["id"] == id)[0]
	var limit := mini(int(option["max"]), GameState.get_resource(id))
	var target := clampi(int(_counts.get(id, 0)) + delta, 0, limit)
	if delta > 0 and _used() >= GameState.backpack_capacity():
		target = int(_counts.get(id, 0))
	_counts[id] = target
	_refresh()


func _on_depart() -> void:
	depart.emit(_counts.duplicate(), {"level": 1 if _biome == &"mushroom" else _level,
		"meal": _meal if _meal_available(_meal) else &"", "biome": _biome})


## Las dostępny po odkryciu (Spore Pod); w buildzie debug (edytor) zawsze, do testów.
static func forest_open() -> bool:
	return GameState.forest_unlocked() or OS.is_debug_build()


func _set_biome(biome: StringName) -> void:
	if biome == &"mushroom" and not forest_open():
		return
	_biome = biome
	_refresh()


func _set_level(level: int) -> void:
	if level <= GameState.max_level():
		_level = level
	_refresh()


func _set_meal(id: StringName) -> void:
	if _meal_available(id):
		_meal = id
	else:
		Sfx.play(&"deny")
	_refresh()


## Danie da się ugotować z tego, co zostanie po zabraniu wyposażenia.
func _meal_available(id: StringName) -> bool:
	if id == &"":
		return true
	var stock := GameState.resources.duplicate()
	for item in _counts:
		stock[item] = int(stock.get(item, 0)) - int(_counts[item])
	return Meals.can_cook(Meals.get_meal(id), stock)


func _used() -> int:
	var total := 0
	for id in _counts:
		total += int(_counts[id])
	return total


func _refresh() -> void:
	if _biome == &"mushroom" and not forest_open():
		_biome = &"meadow"
	for id in _biome_buttons:
		(_biome_buttons[id] as Button).set_pressed_no_signal(id == _biome)
	(_biome_buttons[&"mushroom"] as Button).disabled = not forest_open()
	var forest := _biome == &"mushroom"
	for i in _level_buttons.size():
		var level := i + 1
		_level_buttons[i].set_pressed_no_signal(level == (1 if forest else _level))
		_level_buttons[i].disabled = forest or level > GameState.max_level()
	if forest:
		_level_label.text = ("Puffking defeated · Forest II coming soon" if GameState.has_upgrade(&"forest_stage2")
			else "Village · Sunbreak Glade · Spore Hollow · The Puffking")
	elif not GameState.forest_unlocked() and GameState.max_level() >= 2:
		_level_label.text = "Fog · Misty Spring · Mistbloom seed · a strange Spore Pod" if _level == 2 else "Mushroom Forest: find a Spore Pod on Meadow II"
	elif GameState.max_level() < 2:
		_level_label.text = "Level II: %d/%d database entries" % [
			Codex.discovered_count(GameState.research, 1), Codex.LEVEL2_REQUIRED]
	else:
		_level_label.text = "Fog · Misty Spring · Mistbloom seed" if _level == 2 else ""
	if not _meal_available(_meal):
		_meal = &""
	for id in _meal_buttons:
		var meal_button := _meal_buttons[id] as Button
		meal_button.set_pressed_no_signal(id == _meal)
		meal_button.disabled = not _meal_available(id)
	if _meal == &"":
		_meal_label.text = ""
	else:
		var meal := Meals.get_meal(_meal)
		_meal_label.text = "%s · %s" % [meal["desc"], Meals.cost_text(meal)]
	_planet_label.text = "Attention %d/100 · Raid in %s" % [
		GameState.planet_attention, Raid.cycles_text(Raid.cycles_until(GameState.raid_pressure, GameState.planet_attention))]
	for id in _count_labels:
		(_count_labels[id] as Label).text = "%d / %d" % [_counts.get(id, 0), GameState.get_resource(id)]
	_space_label.text = "Backpack %d/%d" % [_used(), GameState.backpack_capacity()]


func _label(text: String, size: int, wrap := false) -> Label:
	var label := Label.new()
	label.text = text
	label.label_settings = NotebookTheme.label_settings(size, NotebookTheme.TEXT, size >= 18)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(700, 0)
	return label


func _button(text: String, on_pressed: Callable, size := 20) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", size)
	button.custom_minimum_size = Vector2(48, 40)
	button.pressed.connect(on_pressed)
	return button
