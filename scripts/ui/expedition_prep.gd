class_name ExpeditionPrep
extends PanelContainer
## Okno przygotowania wyprawy: wybór wyposażenia z magazynu (zajmuje plecak).

signal depart(loadout: Dictionary)
signal rest
signal cancelled

const OPTIONS := [
	{"id": &"seed_snapper", "label": "Nasiona Snappera", "hint": "rzucone wyrastają w pułapkę na drapieżnika", "max": 4},
	{"id": &"voidberry", "label": "Voidberry (owoc)", "hint": "zjedzony leczy 30 Kondycji", "max": 4},
]

var _counts: Dictionary = {}
var _count_labels: Dictionary = {}
var _space_label: Label


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -330
	offset_right = 330
	offset_top = -250
	offset_bottom = 250
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
	box.add_child(_label("Ogłuszacz jest zawsze w wyposażeniu.", 16))

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
	box.add_child(_label("Uwaga: przy porażce cały plecak przepada (także wyposażenie). Odkrycia ze skanera zostają zawsze.", 14, true))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	buttons.add_child(_button("Wyrusz", func() -> void: depart.emit(_counts.duplicate()), 20))
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
	_refresh()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _change(id: StringName, delta: int) -> void:
	var option: Dictionary = OPTIONS.filter(func(o: Dictionary) -> bool: return o["id"] == id)[0]
	var limit := mini(int(option["max"]), GameState.get_resource(id))
	var target := clampi(int(_counts.get(id, 0)) + delta, 0, limit)
	if delta > 0 and _used() >= RunState.BACKPACK_CAPACITY:
		target = int(_counts.get(id, 0))
	_counts[id] = target
	_refresh()


func _used() -> int:
	var total := 0
	for id in _counts:
		total += int(_counts[id])
	return total


func _refresh() -> void:
	for id in _count_labels:
		(_count_labels[id] as Label).text = "%d / %d" % [_counts.get(id, 0), GameState.get_resource(id)]
	_space_label.text = "Plecak: %d/%d zajęte przez wyposażenie · na łup zostaje %d" % [_used(), RunState.BACKPACK_CAPACITY, RunState.BACKPACK_CAPACITY - _used()]


func _label(text: String, size: int, wrap := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(560, 0)
	return label


func _button(text: String, on_pressed: Callable, size := 20) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", size)
	button.custom_minimum_size = Vector2(48, 40)
	button.pressed.connect(on_pressed)
	return button
