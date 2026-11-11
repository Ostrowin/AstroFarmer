class_name Hud
extends CanvasLayer
## Interfejs zbudowany w kodzie: status, magazyn, celownik, podpowiedź,
## pasek narzędzi, powiadomienia i zaciemnienie przy przejściu na wyprawę.

const NOTIFY_SECONDS := 3.5
const COLOR_OK := Color(1, 1, 1)
const COLOR_BAD := Color(1, 0.55, 0.5)

## Dostawca slotów i podpowiedzi: PlayerInteraction albo ExpeditionInteraction.
## Musi mieć slot_count/slot_title/slot_detail/slot_color, `selected` i sygnały
## prompt_changed, hotbar_changed, notify.
var _interaction = null
var _root: Control
var _status: Label
var _inventory: Label
var _prompt: Label
var _hotbar: HBoxContainer
var _slots: Array[PanelContainer] = []
var _notifications: VBoxContainer
var _fade: ColorRect
var _fade_label: Label
var _click_hint: Label


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root = root

	_status = _make_label(20)
	_status.position = Vector2(16, 12)
	root.add_child(_status)

	_inventory = _make_label(18)
	_inventory.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_inventory.anchor_left = 1.0
	_inventory.anchor_right = 1.0
	_inventory.offset_left = -420
	_inventory.offset_right = -16
	_inventory.offset_top = 12
	root.add_child(_inventory)

	var crosshair := ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.85)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -3
	crosshair.offset_right = 3
	crosshair.offset_top = -3
	crosshair.offset_bottom = 3
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

	_prompt = _make_label(22)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.offset_left = -500
	_prompt.offset_right = 500
	_prompt.offset_top = 28
	_prompt.offset_bottom = 64
	root.add_child(_prompt)

	_hotbar = HBoxContainer.new()
	_hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	_hotbar.add_theme_constant_override("separation", 10)
	_hotbar.anchor_left = 0.5
	_hotbar.anchor_right = 0.5
	_hotbar.anchor_top = 1.0
	_hotbar.anchor_bottom = 1.0
	_hotbar.offset_left = -400
	_hotbar.offset_right = 400
	_hotbar.offset_top = -96
	_hotbar.offset_bottom = -20
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hotbar)

	_notifications = VBoxContainer.new()
	_notifications.alignment = BoxContainer.ALIGNMENT_END
	_notifications.anchor_left = 1.0
	_notifications.anchor_right = 1.0
	_notifications.anchor_top = 0.3
	_notifications.anchor_bottom = 0.75
	_notifications.offset_left = -520
	_notifications.offset_right = -16
	_notifications.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_notifications)

	_click_hint = _make_label(24)
	_click_hint.text = "Kliknij, aby grać  ·  Esc zwalnia mysz"
	_click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_click_hint.set_anchors_preset(Control.PRESET_CENTER)
	_click_hint.offset_left = -400
	_click_hint.offset_right = 400
	_click_hint.offset_top = -80
	_click_hint.offset_bottom = -40
	root.add_child(_click_hint)

	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.03, 0.1, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	root.add_child(_fade)
	_fade_label = _make_label(32)
	_fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fade_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.add_child(_fade_label)

	GameState.resources_changed.connect(refresh)
	GameState.cycle_advanced.connect(func(_c: int) -> void: refresh())


## true, gdy otwarte jest okno (np. przygotowanie wyprawy): chowa podpowiedź kliknięcia.
var modal := false


func _process(_delta: float) -> void:
	_click_hint.visible = not modal and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and _fade.modulate.a < 0.01


func bind(interaction) -> void:
	_interaction = interaction
	for child in _hotbar.get_children():
		child.queue_free()
	_slots.clear()
	for i in interaction.slot_count():
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(150, 70)
		var label := _make_label(17)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(label)
		_hotbar.add_child(panel)
		_slots.append(panel)
	interaction.prompt_changed.connect(set_prompt)
	interaction.hotbar_changed.connect(func(_i: int) -> void: refresh())
	interaction.notify.connect(notify)
	refresh()


func refresh() -> void:
	_status.text = _status_text()
	_inventory.text = _inventory_text()
	if _interaction == null:
		return
	for i in _slots.size():
		var label := _slots[i].get_child(0) as Label
		label.text = "%d · %s\n%s" % [i + 1, _interaction.slot_title(i), _interaction.slot_detail(i)]
		_slots[i].add_theme_stylebox_override("panel", _slot_style(i == _interaction.selected, _interaction.slot_color(i)))


## Nadpisywane w HUD wyprawy.
func _status_text() -> String:
	return "Astro Farmer · Zielona dolina\nCykl: %d · Odkrycia: %d" % [GameState.cycle, GameState.discoveries.size()]


## Nadpisywane w HUD wyprawy.
func _inventory_text() -> String:
	return "Magazyn\n" + item_lines(GameState.resources, [&"water"])


static func item_lines(items: Dictionary, skip: Array = []) -> String:
	var lines: Array[String] = []
	for id in items:
		if skip.has(id):
			continue
		lines.append("%s: %d" % [PlantCatalog.item_name(id), items[id]])
	lines.sort()
	return "\n".join(lines) if not lines.is_empty() else "(pusto)"


func set_prompt(text: String, ok: bool) -> void:
	_prompt.text = text
	_prompt.modulate = COLOR_OK if ok else COLOR_BAD


func notify(text: String) -> void:
	if text.is_empty():
		return
	var label := _make_label(19)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notifications.add_child(label)
	while _notifications.get_child_count() > 6:
		_notifications.get_child(0).free()
	var tween := label.create_tween()
	tween.tween_interval(NOTIFY_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


func fade_out(text: String) -> void:
	_fade_label.text = text
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, 0.5)
	await tween.finished


## Natychmiast zasłania ekran (np. zaraz po wczytaniu sceny po wyprawie).
func cover(text := "") -> void:
	_fade_label.text = text
	_fade.modulate.a = 1.0


func fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 0.0, 0.6)
	await tween.finished


func _make_label(size: int) -> Label:
	var label := Label.new()
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.outline_size = 6
	settings.outline_color = Color(0, 0, 0, 0.65)
	label.label_settings = settings
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _slot_style(is_selected: bool, accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.14, 0.6)
	style.set_corner_radius_all(10)
	style.set_border_width_all(3 if is_selected else 2)
	style.border_color = Color(1, 0.85, 0.35) if is_selected else accent.darkened(0.3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style
