class_name WorkbenchPanel
extends UiPanel
## Okno warsztatu jako drzewko ulepszeń: karty receptur połączone liniami.
## Linie pokazują kolejność rozwoju (wizualnie, bez blokowania): pierwszy rząd
## z kryształów, drugi z rzadszych materiałów, na dole nocne materiały.
## Karta: ikona, nazwa, koszt, stan (Owned / Craft / Missing).

signal crafted(id: StringName)

const NODE_SIZE := Vector2(320, 104)
const TREE_SIZE := Vector2(720, 390)
## Pozycje kart w drzewku (lewy górny róg).
const LAYOUT := {
	&"fence": Vector2(20, 10), &"can_mk2": Vector2(380, 10),
	&"backpack_mk2": Vector2(20, 145), &"pistol_mk2": Vector2(380, 145),
	&"lamp_mk2": Vector2(200, 280),
}
const LINKS := [[&"fence", &"backpack_mk2"], [&"can_mk2", &"pistol_mk2"], [&"backpack_mk2", &"lamp_mk2"], [&"pistol_mk2", &"lamp_mk2"]]
const ICONS := {
	&"fence": &"fence_post", &"can_mk2": &"water_misty", &"backpack_mk2": &"sample_glowmoss",
	&"pistol_mk2": &"thorn", &"lamp_mk2": &"glow_spores",
}


## Linie między kartami drzewka.
class Links:
	extends Control
	var segments: Array = []

	func _draw() -> void:
		for seg: Array in segments:
			draw_line(seg[0], seg[1], seg[2], 4.0, true)


func open() -> void:
	_rebuild()
	open_panel(780, 0)
	_center.call_deferred()


func _rebuild() -> void:
	clear()
	_box.add_child(label("Workbench", 28))
	var tree := Control.new()
	tree.custom_minimum_size = TREE_SIZE
	_box.add_child(tree)
	var links := Links.new()
	links.set_anchors_preset(Control.PRESET_FULL_RECT)
	links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.add_child(links)
	for pair: Array in LINKS:
		var a: Vector2 = LAYOUT[pair[0]] + Vector2(NODE_SIZE.x * 0.5, NODE_SIZE.y)
		var b: Vector2 = LAYOUT[pair[1]] + Vector2(NODE_SIZE.x * 0.5, 0)
		var done: bool = _state(Recipes.get_recipe(pair[0])) == "owned"
		links.segments.append([a, b, NotebookTheme.ACCENT2 if done else NotebookTheme.SLOT_BORDER])
	for recipe: Dictionary in Recipes.LIST:
		var at: Vector2 = LAYOUT.get(recipe["id"], Vector2(20, 10 + 150 * Recipes.LIST.find(recipe)))
		var card := _node(recipe)
		card.position = at
		tree.add_child(card)
	_box.add_child(label(_stock_text(), 15, 700, NotebookTheme.MUTED))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(button("Close", close))
	_box.add_child(buttons)


## "owned" (ulepszenie już jest), "ready" (stać nas), "missing" (brakuje materiałów).
static func _state(recipe: Dictionary) -> String:
	if recipe.get("upgrade", false) and GameState.has_upgrade(recipe["id"]):
		return "owned"
	return "ready" if Recipes.problem(recipe) == "" else "missing"


func _node(recipe: Dictionary) -> Control:
	var state := _state(recipe)
	var color: Color = {"owned": NotebookTheme.ACCENT2, "ready": NotebookTheme.ACCENT, "missing": NotebookTheme.SLOT_BORDER}[state]
	var card := PanelContainer.new()
	card.size = NODE_SIZE
	card.custom_minimum_size = NODE_SIZE
	var style := NotebookTheme.card(NotebookTheme.SLOT, color, 3, 1.0, 10)
	card.add_theme_stylebox_override("panel", style)
	card.tooltip_text = recipe["desc"] + ("\n" + Recipes.problem(recipe) if state == "missing" else "")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(62, 62)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(color, 0.25)
	badge_style.border_color = color
	badge_style.set_border_width_all(2)
	badge_style.set_corner_radius_all(31)
	badge.add_theme_stylebox_override("panel", badge_style)
	var icon := TextureRect.new()
	icon.texture = NotebookTheme.icon(ICONS.get(recipe["id"], &""))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.add_child(icon)
	row.add_child(badge)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(label(recipe["name"], 18))
	var cost := label(Recipes.cost_text(recipe) if state != "owned" else recipe["desc"], 13, 220,
		NotebookTheme.MUTED if state != "missing" else NotebookTheme.BAD)
	text.add_child(cost)
	var action := Button.new()
	action.text = {"owned": "Owned", "ready": "Craft", "missing": "Missing"}[state]
	action.custom_minimum_size = Vector2(96, 30)
	action.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	action.disabled = state != "ready"
	action.add_theme_font_size_override("font_size", 14)
	if state == "ready":
		var accent := NotebookTheme.card(NotebookTheme.ACCENT, NotebookTheme.ACCENT.darkened(0.3), 2, 1.0, 4)
		accent.shadow_offset = Vector2(0, 2)
		action.add_theme_stylebox_override("normal", accent)
		action.add_theme_color_override("font_color", Color.WHITE)
	elif state == "owned":
		var owned := NotebookTheme.card(NotebookTheme.ACCENT2, NotebookTheme.ACCENT2.darkened(0.3), 2, 1.0, 4)
		owned.shadow_offset = Vector2.ZERO
		action.add_theme_stylebox_override("disabled", owned)
		action.add_theme_color_override("font_disabled_color", Color.WHITE)
	action.pressed.connect(_craft.bind(recipe["id"]))
	text.add_child(action)
	return card


func _craft(id: StringName) -> void:
	if not Recipes.craft(id):
		Sfx.play(&"deny")
		return
	Sfx.play(&"craft")
	crafted.emit(id)
	_rebuild()


static func _stock_text() -> String:
	var parts: Array[String] = []
	for id in [&"crystal", &"sample_glowmoss", &"thorn", &"lumen_dust", &"glow_spores", &"starfall_shard", &"fence_post"]:
		var count := GameState.get_resource(id)
		if count > 0 or id in [&"crystal", &"fence_post"]:
			parts.append("%s %d" % [PlantCatalog.item_name(id), count])
	return "Storage: " + "  ·  ".join(parts)
