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


static var _theme: Theme


## Ikona przedmiotu (art/ui/icons/<id>.png) albo null.
static func icon(id: StringName) -> Texture2D:
	if id == &"":
		return null
	var path := "res://art/ui/icons/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null


## Jasne kolory z dawnego ciemnego UI -> czytelne odpowiedniki na kremowym tle.
static func ink(color: Color) -> Color:
	if color.get_luminance() < 0.55:
		return color
	if color.s < 0.2:
		return MUTED if color.v < 0.97 else TEXT
	var h := color.h
	if h < 0.06 or h > 0.92:
		return BAD
	if h < 0.17:
		return Color("b85a14")
	if h < 0.42:
		return Color("2e7d4f")
	if h < 0.72:
		return Color("1f6f8b")
	return AWAKE.darkened(0.2)


## Motyw okien: karty, przyciski, suwaki i dymki w stylu notesu.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = regular()
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	t.set_font("font", "Button", bold())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.6))
	var normal := card(SLOT, SLOT_BORDER, 2, 1.0, 8)
	normal.shadow_offset = Vector2(0, 3)
	var hover := card(SLOT, ACCENT, 2, 1.0, 8)
	hover.shadow_offset = Vector2(0, 3)
	var pressed := card(ACCENT, ACCENT.darkened(0.3), 2, 1.0, 8)
	pressed.shadow_offset = Vector2(0, 1)
	var disabled := card(PANEL_DARK, SLOT_BORDER, 2, 0.6, 8)
	disabled.shadow_offset = Vector2.ZERO
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", card(PANEL, BORDER, BORDER_W, 0.97, 24))
	t.set_stylebox("panel", "TooltipPanel", card(PANEL, BORDER, 2, 1.0, 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font("font", "TooltipLabel", regular())
	t.set_stylebox("grabber", "VScrollBar", bar(SLOT_BORDER))
	t.set_stylebox("grabber_highlight", "VScrollBar", bar(ACCENT))
	t.set_stylebox("grabber_pressed", "VScrollBar", bar(ACCENT))
	t.set_stylebox("scroll", "VScrollBar", bar(Color(PANEL_DARK, 0.8)))
	_theme = t
	return t
