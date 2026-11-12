class_name ExpeditionPrep
extends PanelContainer
## Okno przygotowania wyprawy: poziom łąki, wyposażenie z magazynu (zajmuje plecak)
## i danie z kuchni ekspedycyjnej (jedno, zjadane przy wyjściu).

## options: {"level": int, "meal": StringName}
signal depart(loadout: Dictionary, options: Dictionary)
signal rest
signal cancelled

const OPTIONS := [
	{"id": &"seed_snapper", "label": "Nasiona Snappera", "hint": "rzucone wyrastają w pułapkę na drapieżnika", "max": 4},
	{"id": &"seed_boomshroom", "label": "Nasiona Boomshrooma", "hint": "rzucone robią puff: ogłuszają wszystko w 4 m", "max": 3},
	{"id": &"voidberry", "label": "Voidberry (owoc)", "hint": "zjedzony leczy 30 Kondycji", "max": 4},
]

var _counts: Dictionary = {}
var _count_labels: Dictionary = {}
var _space_label: Label
var _planet_label: Label
var _level := 1
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.14, 0.94)
	style.set_corner_radius_all(14)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.95, 1, 0.8)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	box.add_child(_label("Przygotowanie wyprawy", 28))
	box.add_child(_label("Cel: Dzika łąka. Zbierz nasiona, próbki i kryształy, zeskanuj, co nowe, i wróć na lądowisko, zanim planeta się obudzi.", 16, true))
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 10)
	level_row.add_child(_label("Poziom łąki:", 18))
	for level in [1, 2]:
		var level_button := _button("Poziom %d" % level, _set_level.bind(level), 16)
		level_button.toggle_mode = true
		level_row.add_child(level_button)
		_level_buttons.append(level_button)
	box.add_child(level_row)
	_level_label = _label("", 14, true)
	_level_label.modulate = Color(0.8, 0.9, 1.0)
	box.add_child(_level_label)
	box.add_child(_label("Ogłuszacz jest zawsze w wyposażeniu.", 16))
	_planet_label = _label("", 15, true)
	_planet_label.modulate = Color(1.0, 0.85, 0.6)
	box.add_child(_planet_label)

	for option: Dictionary in OPTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(_label(option["label"], 19))
		var hint := _label(option["hint"], 14)
		hint.modulate = Color(0.8, 0.8, 0.9)
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

	box.add_child(_label("Kuchnia ekspedycyjna: jedno danie przed wyjściem", 19))
	var meals := HFlowContainer.new()
	meals.add_theme_constant_override("h_separation", 8)
	meals.add_theme_constant_override("v_separation", 6)
	var none := _button("Bez dania", _set_meal.bind(&""), 15)
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
	_meal_label.modulate = Color(0.8, 1.0, 0.8)
	box.add_child(_meal_label)
	box.add_child(_label("Uwaga: przy porażce cały plecak przepada (także wyposażenie). Odkrycia ze skanera zostają zawsze.", 14, true))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	buttons.add_child(_button("Wyrusz", _on_depart, 20))
	buttons.add_child(_button("Przeczekaj cykl", func() -> void: rest.emit(), 16))
	buttons.add_child(_button("Anuluj", func() -> void: cancelled.emit(), 16))
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


func _change(id: StringName, delta: int) -> void:
	var option: Dictionary = OPTIONS.filter(func(o: Dictionary) -> bool: return o["id"] == id)[0]
	var limit := mini(int(option["max"]), GameState.get_resource(id))
	var target := clampi(int(_counts.get(id, 0)) + delta, 0, limit)
	if delta > 0 and _used() >= GameState.backpack_capacity():
		target = int(_counts.get(id, 0))
	_counts[id] = target
	_refresh()


func _on_depart() -> void:
	depart.emit(_counts.duplicate(), {"level": _level, "meal": _meal if _meal_available(_meal) else &""})


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
	for i in _level_buttons.size():
		var level := i + 1
		_level_buttons[i].set_pressed_no_signal(level == _level)
		_level_buttons[i].disabled = level > GameState.max_level()
	if GameState.max_level() < 2:
		_level_label.text = "Poziom 2 (mgła, Mgliste źródło, nasiono-zagadka): odkryj %d z %d wpisów bazy danych (masz %d)." % [
			Codex.LEVEL2_REQUIRED, Codex.entry_count(1), Codex.discovered_count(GameState.research, 1)]
	else:
		_level_label.text = "Poziom 2: gęsta mgła, Przebudzenie od 10, Mgliste źródło i nasiono Mgielnika." if _level == 2 else "Poziom 1: zwykła łąka."
	if not _meal_available(_meal):
		_meal = &""
	for id in _meal_buttons:
		var meal_button := _meal_buttons[id] as Button
		meal_button.set_pressed_no_signal(id == _meal)
		meal_button.disabled = not _meal_available(id)
	if _meal == &"":
		_meal_label.text = "Dania robi się z upraw: Sałatka (3 Voidberry), Herbatka (kryształ + Voidberry), Ciastka (pyłek + Voidberry), Napar (Mgielny owoc)."
	else:
		var meal := Meals.get_meal(_meal)
		_meal_label.text = "%s: %s · zużyje %s" % [meal["name"], meal["desc"], Meals.cost_text(meal)]
	_planet_label.text = "Uwaga planety: %d/100. Rzadkie łupy (Lśniący mech +10, kryształ +1) ją podnoszą, a wtedy najazdy na bazę są częstsze. Niepokój fauny: %d%%, najazd za ok. %s." % [
		GameState.planet_attention, GameState.raid_pressure, Raid.cycles_text(Raid.cycles_until(GameState.raid_pressure, GameState.planet_attention))]
	for id in _count_labels:
		(_count_labels[id] as Label).text = "%d / %d" % [_counts.get(id, 0), GameState.get_resource(id)]
	_space_label.text = "Plecak: %d/%d zajęte przez wyposażenie · na łup zostaje %d" % [_used(), GameState.backpack_capacity(), GameState.backpack_capacity() - _used()]


func _label(text: String, size: int, wrap := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
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
