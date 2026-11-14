class_name Hud
extends CanvasLayer
## Interfejs zbudowany w kodzie: status, magazyn, celownik, podpowiedź,
## pasek narzędzi, powiadomienia i zaciemnienie przy przejściu na wyprawę.
## Styl "Field Notebook" (NotebookTheme): kremowe karty z brązową ramką.

const NOTIFY_SECONDS := 3.0
## Najwięcej naraz widocznych powiadomień.
const MAX_NOTIFICATIONS := 4
const COLOR_OK := NotebookTheme.TEXT
const COLOR_BAD := NotebookTheme.BAD
const SLOT_SIZE := Vector2(70, 70)

## Dostawca slotów i podpowiedzi: PlayerInteraction albo ExpeditionInteraction.
## Musi mieć slot_count/slot_title/slot_detail/slot_color, `selected` i sygnały
## prompt_changed, hotbar_changed, notify.
var _interaction = null
var _root: Control
var _status: Label
var _status_sub: Label
var _status_card: PanelContainer
var _inventory: Label
var _inventory_card: PanelContainer
var _prompt: Label
var _prompt_card: PanelContainer
var _prompt_key: PanelContainer
var _slot_title: Label
var _hotbar: HBoxContainer
var _slots: Array[PanelContainer] = []
var _notifications: VBoxContainer
var _fade: ColorRect
var _fade_label: Label
var _click_hint: Label
var _crosshair: Control
var _move_label: Label
## Gracz, którego dash i bieg pokazuje HUD (track_player).
var _tracked: Player


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root = root

	# Zegar i cykl: karta w lewym górnym rogu.
	_status_card = PanelContainer.new()
	_status_card.add_theme_stylebox_override("panel", NotebookTheme.card(NotebookTheme.PANEL, NotebookTheme.BORDER, 3, 0.94, 12))
	_status_card.position = Vector2(16, 16)
	_status_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_status_card)
	var status_box := VBoxContainer.new()
	status_box.add_theme_constant_override("separation", -2)
	status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_card.add_child(status_box)
	_status = Label.new()
	_status.label_settings = NotebookTheme.label_settings(28)
	status_box.add_child(_status)
	_status_sub = Label.new()
	_status_sub.label_settings = NotebookTheme.label_settings(14, NotebookTheme.MUTED, false)
	status_box.add_child(_status_sub)

	# Magazyn / plecak: karta w prawym górnym rogu.
	_inventory_card = PanelContainer.new()
	_inventory_card.add_theme_stylebox_override("panel", NotebookTheme.card(NotebookTheme.PANEL, NotebookTheme.BORDER, 3, 0.94, 12))
	_inventory_card.anchor_left = 1.0
	_inventory_card.anchor_right = 1.0
	_inventory_card.offset_right = -16
	_inventory_card.offset_left = -16
	_inventory_card.offset_top = 16
	_inventory_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_inventory_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_inventory_card)
	_inventory = Label.new()
	_inventory.label_settings = NotebookTheme.label_settings(17)
	_inventory.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_inventory_card.add_child(_inventory)

	# Celownik: biała kropka z ciemną obwódką.
	var crosshair := Panel.new()
	_crosshair = crosshair
	var dot := StyleBoxFlat.new()
	dot.bg_color = Color(1, 1, 1, 0.95)
	dot.set_corner_radius_all(5)
	dot.border_color = Color(NotebookTheme.TEXT, 0.6)
	dot.set_border_width_all(1)
	crosshair.add_theme_stylebox_override("panel", dot)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -4
	crosshair.offset_right = 4
	crosshair.offset_top = -4
	crosshair.offset_bottom = 4
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

	# Podpowiedź pod celownikiem: karta z klawiszem [E] i krótkim napisem.
	var prompt_anchor := CenterContainer.new()
	prompt_anchor.set_anchors_preset(Control.PRESET_CENTER)
	prompt_anchor.offset_left = -500
	prompt_anchor.offset_right = 500
	prompt_anchor.offset_top = 30
	prompt_anchor.offset_bottom = 80
	prompt_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt_anchor)
	_prompt_card = PanelContainer.new()
	_prompt_card.add_theme_stylebox_override("panel", NotebookTheme.card(NotebookTheme.PANEL, NotebookTheme.ACCENT, 3, 0.94, 8))
	_prompt_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_anchor.add_child(_prompt_card)
	var prompt_row := HBoxContainer.new()
	prompt_row.add_theme_constant_override("separation", 8)
	prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_card.add_child(prompt_row)
	_prompt_key = NotebookTheme.key_badge("E")
	prompt_row.add_child(_prompt_key)
	_prompt = Label.new()
	_prompt.label_settings = NotebookTheme.label_settings(19)
	prompt_row.add_child(_prompt)
	_prompt_card.visible = false

	# Pasek narzędzi: kwadratowe sloty z ikoną; nazwa wybranego nad paskiem.
	_hotbar = HBoxContainer.new()
	_hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	_hotbar.add_theme_constant_override("separation", 8)
	_hotbar.anchor_left = 0.5
	_hotbar.anchor_right = 0.5
	_hotbar.anchor_top = 1.0
	_hotbar.anchor_bottom = 1.0
	_hotbar.offset_left = -600
	_hotbar.offset_right = 600
	_hotbar.offset_top = -94
	_hotbar.offset_bottom = -20
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hotbar)
	_slot_title = Label.new()
	_slot_title.label_settings = NotebookTheme.world_label_settings(18)
	_slot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_title.anchor_left = 0.5
	_slot_title.anchor_right = 0.5
	_slot_title.anchor_top = 1.0
	_slot_title.anchor_bottom = 1.0
	_slot_title.offset_left = -300
	_slot_title.offset_right = 300
	_slot_title.offset_top = -126
	_slot_title.offset_bottom = -98
	_slot_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_slot_title)

	_notifications = VBoxContainer.new()
	_notifications.alignment = BoxContainer.ALIGNMENT_END
	_notifications.anchor_left = 1.0
	_notifications.anchor_right = 1.0
	_notifications.anchor_top = 0.3
	_notifications.anchor_bottom = 0.75
	_notifications.offset_left = -420
	_notifications.offset_right = -16
	_notifications.add_theme_constant_override("separation", 8)
	_notifications.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_notifications)

	_click_hint = _make_label(24)
	_click_hint.text = "Click to play"
	_click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_click_hint.set_anchors_preset(Control.PRESET_CENTER)
	_click_hint.offset_left = -400
	_click_hint.offset_right = 400
	_click_hint.offset_top = -80
	_click_hint.offset_bottom = -40
	root.add_child(_click_hint)

	_move_label = _make_label(15)
	_move_label.anchor_top = 1.0
	_move_label.anchor_bottom = 1.0
	_move_label.offset_left = 16
	_move_label.offset_top = -132
	_move_label.offset_right = 520
	_move_label.offset_bottom = -106
	root.add_child(_move_label)

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
	GameState.research_added.connect(_on_research)
	GameState.level_unlocked.connect(_on_level_unlocked)
	GameState.cycle_advanced.connect(func(_c: int) -> void: refresh())


## true, gdy otwarte jest okno (np. przygotowanie wyprawy): chowa podpowiedź kliknięcia.
var modal := false


func _process(_delta: float) -> void:
	_click_hint.visible = not modal and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and _fade.modulate.a < 0.01
	if _tracked and is_instance_valid(_tracked):
		# Tylko kiedy dash się ładuje; gotowy dash nie potrzebuje napisu.
		_move_label.text = "Dash %.1fs" % _tracked.dash_cooldown_left if _tracked.dash_cooldown_left > 0.0 else ""
	# Szczegóły (magazyn / plecak) tylko przy przytrzymanym Tab.
	_inventory_card.visible = details_visible() and not _inventory.text.is_empty()
	# Zegar płynie co klatkę; reszta statusu i tak się nie zmienia między odświeżeniami.
	_show_status()


## Czy pokazać listę magazynu: tylko przy przytrzymanym Tab (na wyprawie Tab otwiera plecak).
func details_visible() -> bool:
	return InputMap.has_action("inventory") and Input.is_action_pressed("inventory") and not modal


## Pokazuje stan dasha i biegu gracza.
func track_player(player: Player) -> void:
	_tracked = player


func bind(interaction) -> void:
	_interaction = interaction
	for child in _hotbar.get_children():
		child.queue_free()
	_slots.clear()
	for i in interaction.slot_count():
		_hotbar.add_child(_make_slot(i))
	interaction.prompt_changed.connect(set_prompt)
	interaction.hotbar_changed.connect(func(_i: int) -> void: refresh())
	interaction.notify.connect(notify)
	refresh()


func refresh() -> void:
	_show_status()
	_inventory.text = _inventory_text()
	if _interaction == null:
		return
	for i in _slots.size():
		var holder := _slots[i].get_child(0)
		var selected: bool = i == _interaction.selected
		(holder.get_node("Icon") as Panel).add_theme_stylebox_override("panel", _icon_style(_interaction.slot_color(i)))
		(holder.get_node("Count") as Label).text = _interaction.slot_detail(i)
		_slots[i].add_theme_stylebox_override("panel", _slot_style(selected, _interaction.slot_color(i)))
		if selected:
			_slot_title.text = _interaction.slot_title(i)


## Pierwsza linia statusu to zegar (duży), reszta drobnym drukiem pod spodem.
func _show_status() -> void:
	var lines := _status_text().split("\n")
	_status.text = lines[0]
	var rest := lines.slice(1)
	_status_sub.text = "  ·  ".join(rest)
	_status_sub.visible = not rest.is_empty()


## Nadpisywane w HUD wyprawy.
func _status_text() -> String:
	var raid_in := Raid.cycles_until(GameState.raid_pressure, GameState.planet_attention)
	return "%s\nCycle %d\nRaid in %s" % [GameState.clock_text(GameState.time_of_day), GameState.cycle, Raid.cycles_text(raid_in)]


## Nadpisywane w HUD wyprawy.
func _inventory_text() -> String:
	return "Storage\n" + item_lines(GameState.resources, [&"water"])


static func item_lines(items: Dictionary, skip: Array = []) -> String:
	var lines: Array[String] = []
	for id in items:
		if skip.has(id):
			continue
		lines.append("%s: %d" % [PlantCatalog.item_name(id), items[id]])
	lines.sort()
	return "\n".join(lines) if not lines.is_empty() else "(empty)"


func _on_research(id: StringName, text: String, count: int) -> void:
	if count == 1:
		notify("New entry: %s" % Codex.entry_name(id))
	else:
		notify("%s %d/%d" % [Codex.entry_name(id), count, Codex.fact_count(id)])
	refresh()


func _on_level_unlocked(_biome: StringName, level: int) -> void:
	Sfx.play(&"chime")
	notify("Meadow level %d unlocked" % level)


## Chowa/pokazuje interfejs gry (np. na czas przerywnika z lądowaniem).
func show_overlay(show: bool) -> void:
	for control: Control in [_status_card, _inventory_card, _prompt_card, _hotbar, _slot_title, _crosshair, _move_label]:
		control.visible = show and (control != _prompt_card or not _prompt.text.is_empty())


## "[E] Harvest" -> klawisz w znaczku + napis; bez klawisza sam napis (np. "Too far" na czerwono).
func set_prompt(text: String, ok: bool) -> void:
	var key := ""
	var body := text
	if text.begins_with("[") and text.find("]") > 0:
		key = text.substr(1, text.find("]") - 1)
		body = text.substr(text.find("]") + 1).strip_edges()
	_prompt.text = body
	_prompt.label_settings.font_color = COLOR_OK if ok else COLOR_BAD
	_prompt_key.visible = not key.is_empty()
	if not key.is_empty():
		(_prompt_key.get_child(0) as Label).text = key
	_prompt_card.visible = not text.is_empty()


func notify(text: String) -> void:
	if text.is_empty():
		return
	# Karta przyklejona do prawej krawędzi; szerokość według tekstu.
	var label := PanelContainer.new()
	label.add_theme_stylebox_override("panel", NotebookTheme.card(NotebookTheme.PANEL, NotebookTheme.ACCENT2, 3, 0.94, 9))
	label.size_flags_horizontal = Control.SIZE_SHRINK_END
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_label := Label.new()
	text_label.text = text
	text_label.label_settings = NotebookTheme.label_settings(17)
	text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_child(text_label)
	_notifications.add_child(label)
	while _notifications.get_child_count() > MAX_NOTIFICATIONS:
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


## Napis na tle świata (bez karty): jasny z ciemną obwódką.
func _make_label(size: int) -> Label:
	var label := Label.new()
	label.label_settings = NotebookTheme.world_label_settings(size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Slot paska: numer klawisza w rogu, ikona (kolor przedmiotu) i ilość.
func _make_slot(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = SLOT_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(holder)
	var key := Label.new()
	key.name = "Key"
	key.text = str(index + 1)
	key.label_settings = NotebookTheme.label_settings(13, NotebookTheme.MUTED)
	key.position = Vector2(2, -2)
	holder.add_child(key)
	var icon := Panel.new()
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -13
	icon.offset_right = 13
	icon.offset_top = -17
	icon.offset_bottom = 9
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon)
	var count := Label.new()
	count.name = "Count"
	count.label_settings = NotebookTheme.label_settings(14)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.anchor_left = 0.0
	count.anchor_right = 1.0
	count.anchor_top = 1.0
	count.anchor_bottom = 1.0
	count.offset_top = -20
	count.offset_bottom = 2
	count.offset_right = 2
	holder.add_child(count)
	_slots.append(panel)
	return panel


func _slot_style(is_selected: bool, _accent: Color) -> StyleBoxFlat:
	var style := NotebookTheme.card(NotebookTheme.SLOT, NotebookTheme.ACCENT if is_selected else NotebookTheme.SLOT_BORDER,
		4 if is_selected else 2, 0.95, 6)
	if is_selected:
		style.shadow_offset = Vector2(0, 7)
	return style


func _icon_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(13)
	s.border_color = color.darkened(0.45)
	s.set_border_width_all(2)
	return s
