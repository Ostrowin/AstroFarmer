class_name CodexPanel
extends UiPanel
## Baza danych (komputer w chatce) jako ekran terminala: zakładki kategorii,
## lista wpisów z postępem i karta wybranego wpisu (fakty i podpowiedzi).
## Na górze kompletność i postęp do poziomu 2 doliny.

const SCREEN := Color("22352f")
const SCREEN_TEXT := Color("c8f5d4")
const SCREEN_DIM := Color(0.78, 0.96, 0.83, 0.5)
## Ikona wpisu: przedmiot, który go przypomina.
const ICONS := {
	&"voidberry": &"voidberry", &"crystal_bloom": &"seed_crystal_bloom", &"snapper": &"seed_snapper",
	&"boomshroom": &"seed_boomshroom", &"mistbloom": &"seed_mistbloom", &"moonpetal": &"seed_moonpetal",
	&"glowcap": &"glow_spores", &"pollenbug": &"pollen", &"chrupik": &"fertilizer", &"thornback": &"thorn",
	&"lumimoth": &"lumen_dust", &"glowmoss": &"sample_glowmoss", &"crystal_vein": &"crystal",
	&"misty_spring": &"water_misty", &"starfall": &"starfall_shard",
	&"spore_pod": &"spore_pod", &"mycelium_fiber": &"mycelium_fiber", &"glade_bloom": &"seed_glade_bloom",
	&"cluster_shroom": &"seed_cluster_shroom", &"mushroom_log": &"mushroom_log", &"sporekin": &"spore_mask",
	&"spore_tick": &"glow_spores", &"rotling": &"mycelium_fiber", &"sporebat": &"mycelium_fiber",
	&"rot_thornback": &"mycelium_fiber", &"rot_shepherd": &"seed_glade_bloom", &"puffking": &"seed_cluster_shroom",
	&"hammer_cap": &"mushroom",
}

var _category := "Plants"
var _selected: StringName = &""


func open() -> void:
	_rebuild()
	open_panel(900, 0)
	_center.call_deferred()


func _rebuild() -> void:
	clear()
	var research := GameState.research
	var max_level := GameState.max_level()
	if _selected == &"" or not Codex.ENTRIES.has(_selected) or Codex.ENTRIES[_selected]["category"] != _category:
		_selected = _first_in(_category)

	# Obudowa komputera: ciemny ekran w kremowej ramce.
	var screen := PanelContainer.new()
	var screen_style := NotebookTheme.card(SCREEN, NotebookTheme.BORDER, 2, 1.0, 18)
	screen_style.shadow_offset = Vector2.ZERO
	screen_style.set_corner_radius_all(8)
	screen.add_theme_stylebox_override("panel", screen_style)
	_box.add_child(screen)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	screen.add_child(content)

	# Zakładki i kompletność.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	content.add_child(top)
	for category: String in Codex.CATEGORIES:
		top.add_child(_tab(category))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	var percent := Label.new()
	percent.text = "%d%%" % Codex.completion(research, max_level, GameState.forest_unlocked())
	percent.label_settings = NotebookTheme.label_settings(30, SCREEN_TEXT)
	top.add_child(percent)

	var found := Codex.discovered_count(research, 1)
	var progress := "Meadow II: %d/%d entries" % [found, Codex.LEVEL2_REQUIRED] if max_level < 2 else "Meadow II unlocked"
	content.add_child(_screen_label(progress, 14, SCREEN_DIM, false))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	content.add_child(columns)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.custom_minimum_size = Vector2(260, 0)
	columns.add_child(list)
	for id in Codex.ENTRIES:
		if Codex.ENTRIES[id]["category"] == _category:
			list.add_child(_entry_row(id, research, max_level))
	columns.add_child(_detail(_selected, research, max_level))

	content.add_child(_screen_label("> scanning ...", 13, SCREEN_DIM, false))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(button("Close", close))
	_box.add_child(buttons)
	# Inna zakładka = inna wysokość listy: okno dopasowuje się od nowa,
	# gdy stara zawartość już zniknie (clear() usuwa ją pod koniec klatki).
	_recenter()


func _first_in(category: String) -> StringName:
	for id in Codex.ENTRIES:
		if Codex.ENTRIES[id]["category"] == category:
			return id
	return &""


func _tab(category: String) -> Button:
	var b := Button.new()
	b.text = category
	b.custom_minimum_size = Vector2(130, 36)
	var on := category == _category
	var style := StyleBoxFlat.new()
	style.bg_color = NotebookTheme.ACCENT if on else Color(0, 0, 0, 0)
	style.border_color = SCREEN_TEXT if not on else NotebookTheme.ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(4)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, style)
	var font_color := Color.WHITE if on else SCREEN_TEXT
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, font_color)
	b.pressed.connect(func() -> void:
		_category = category
		_rebuild())
	return b


func _entry_row(id: StringName, research: Dictionary, max_level: int) -> Control:
	var known := Codex.known_count(research, id)
	var locked := _locked(id, max_level)
	var b := Button.new()
	b.custom_minimum_size = Vector2(260, 50)
	var on := id == _selected
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.08) if on else Color(0, 0, 0, 0)
	style.border_color = SCREEN_TEXT
	style.set_border_width_all(2 if on else 0)
	style.set_corner_radius_all(8)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, style)
	b.pressed.connect(func() -> void:
		_selected = id
		_rebuild())
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = NotebookTheme.icon(ICONS.get(id, &"")) if known > 0 else null
	icon.modulate = Color.WHITE if known > 0 else Color(1, 1, 1, 0.3)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 3)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var name_text := "???" if known == 0 or locked else Codex.entry_name(id)
	text.add_child(_screen_label(name_text, 16, SCREEN_TEXT if known > 0 and not locked else SCREEN_DIM))
	text.add_child(_dots(known, Codex.fact_count(id)))
	return b


## Postęp wpisu jako kropki (pełne = odkryte fakty).
func _dots(known: int, total: int) -> HBoxContainer:
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 6)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in total:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(9, 9)
		var s := StyleBoxFlat.new()
		s.bg_color = SCREEN_TEXT if i < known else Color(0, 0, 0, 0)
		s.border_color = SCREEN_TEXT
		s.set_border_width_all(1)
		s.set_corner_radius_all(5)
		dot.add_theme_stylebox_override("panel", s)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(dot)
	return dots


static func _locked(id: StringName, max_level: int) -> bool:
	if Codex.is_forest(id):
		return not GameState.forest_unlocked()
	return int(Codex.ENTRIES[id]["level"]) > max_level


func _detail(id: StringName, research: Dictionary, max_level: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if id == &"":
		return box
	var entry: Dictionary = Codex.ENTRIES[id]
	var known: Array = research.get(id, [])
	if _locked(id, max_level):
		box.add_child(_screen_label("???", 28, SCREEN_TEXT))
		box.add_child(_screen_label("Found in the Mushroom Forest." if Codex.is_forest(id) else "Found on Meadow II.", 15, SCREEN_DIM, false))
		return box
	box.add_child(_screen_label(entry["name"] if not known.is_empty() else "???", 28, SCREEN_TEXT))
	box.add_child(_screen_label("%s · %d / %d facts" % [entry["category"], known.size(), Codex.fact_count(id)], 14, SCREEN_DIM, false))
	for item: Dictionary in entry["facts"]:
		var have := known.has(item["how"])
		var card := PanelContainer.new()
		var s := StyleBoxFlat.new()
		s.bg_color = Color(1, 1, 1, 0.07) if have else Color(0, 0, 0, 0)
		s.border_color = SCREEN_TEXT if have else SCREEN_DIM
		s.set_border_width_all(1)
		s.set_corner_radius_all(8)
		s.set_content_margin_all(12)
		card.add_theme_stylebox_override("panel", s)
		var text := String(item["text"]) if have else "??? Hint: %s" % item["hint"]
		var l := _screen_label(text, 15, SCREEN_TEXT if have else SCREEN_DIM, false)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(500, 0)
		card.add_child(l)
		box.add_child(card)
	return box


func _screen_label(text: String, size: int, color: Color, heavy := true) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = NotebookTheme.label_settings(size, color, heavy)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _recenter() -> void:
	await get_tree().process_frame
	if is_inside_tree():
		_center()
