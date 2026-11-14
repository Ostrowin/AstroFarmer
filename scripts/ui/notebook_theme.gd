class_name NotebookTheme
extends RefCounted
## Styl UI "Field Notebook" (wybrany 2026-11-14, plansza: art/source/sketches/ui_style_A_field_notebook.png):
## kremowe karty z brązową ramką i twardym cieniem jak naklejka, pomarańczowe akcenty, font Lato.

const PANEL := Color("f4e9d2")
const PANEL_DARK := Color("e6d5b3")
const BORDER := Color("6b4a2b")
const TEXT := Color("3b2a1a")
const MUTED := Color("7a6248")
const ACCENT := Color("e8792b")
const ACCENT2 := Color("2fa59a")
const HEALTH := Color("e0574a")
const AWAKE := Color("8a5cd6")
const SLOT := Color("fbf5e8")
const SLOT_BORDER := Color("b8946a")
const BAD := Color("c0392b")
const SHADOW := Color(0, 0, 0, 0.35)
const RADIUS := 12
const BORDER_W := 3

static var _bold: FontFile
static var _regular: FontFile


static func bold() -> Font:
	if _bold == null:
		_bold = load("res://art/fonts/Lato-Bold.ttf")
	return _bold


static func regular() -> Font:
	if _regular == null:
		_regular = load("res://art/fonts/Lato-Regular.ttf")
	return _regular


## Karta: kremowe tło, brązowa ramka, twardy cień przesunięty w dół.
static func card(bg := PANEL, border := BORDER, border_w := BORDER_W, alpha := 0.94, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(bg, alpha)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(RADIUS)
	s.shadow_color = SHADOW
	s.shadow_size = 0
	s.shadow_offset = Vector2(0, 5)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s


## Pasek (tło lub wypełnienie).
static func bar(color: Color, border := false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(10)
	if border:
		s.border_color = BORDER
		s.set_border_width_all(2)
		s.set_expand_margin_all(3)
	return s


static func label_settings(size: int, color := TEXT, heavy := true) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = bold() if heavy else regular()
	ls.font_size = size
	ls.font_color = color
	return ls


## Napis na tle świata (bez karty): jasny z ciemną obwódką, żeby był czytelny wszędzie.
static func world_label_settings(size: int) -> LabelSettings:
	var ls := label_settings(size, Color.WHITE)
	ls.outline_size = 6
	ls.outline_color = Color(TEXT, 0.85)
	return ls


## Mały kwadrat z literą klawisza, np. [E].
static func key_badge(key: String, size := 18) -> PanelContainer:
	var badge := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = ACCENT
	s.set_corner_radius_all(6)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	badge.add_theme_stylebox_override("panel", s)
	var l := Label.new()
	l.text = key
	l.label_settings = label_settings(size, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(l)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return badge
