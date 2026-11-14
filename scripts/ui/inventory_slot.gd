class_name InventorySlot
extends PanelContainer
## Jedno pole w oknie plecaka. Rodzaje:
##   "item"    przedmiot z plecaka (przeciągnij; PPM wyrzuca 1 sztukę),
##   "offhand" druga ręka (upuść tu nasiono do rzucania),
##   "trash"   wyrzucanie (upuść tu, żeby wyrzucić cały stos).

var kind := "item"
var item_id: StringName = &""
var amount := 0
## Okno plecaka, które obsługuje upuszczenie i wyrzucanie.
var panel: InventoryPanel

var _label: Label
var _icon: TextureRect


func _init() -> void:
	custom_minimum_size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.label_settings = NotebookTheme.label_settings(14)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func setup(slot_kind: String, id: StringName, count: int, title: String, color: Color) -> void:
	kind = slot_kind
	item_id = id
	amount = count
	# Z ikoną: sama ilość w rogu (nazwa w dymku); bez ikony: nazwa i ilość.
	var tex := NotebookTheme.icon(id)
	_icon.texture = tex
	_label.text = ("×%d" % count if count > 0 else "") if tex else title
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if tex else HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if tex else VERTICAL_ALIGNMENT_CENTER
	_label.size_flags_vertical = Control.SIZE_SHRINK_END if tex else Control.SIZE_FILL
	if tex and tooltip_text.is_empty():
		tooltip_text = PlantCatalog.item_name(id)
	var empty := id == &"" and kind == "item"
	var border := NotebookTheme.BAD if kind == "trash" else (NotebookTheme.ACCENT if kind == "offhand" else NotebookTheme.SLOT_BORDER)
	var style := NotebookTheme.card(NotebookTheme.SLOT if not empty else NotebookTheme.PANEL_DARK, border, 2, 1.0 if not empty else 0.6, 6)
	style.shadow_offset = Vector2(0, 3) if not empty else Vector2.ZERO
	add_theme_stylebox_override("panel", style)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if kind != "item" or item_id == &"":
		return null
	var preview := Label.new()
	preview.text = "%s ×%d" % [PlantCatalog.item_name(item_id), amount]
	preview.add_theme_font_size_override("font_size", 16)
	set_drag_preview(preview)
	return {"item": item_id, "amount": amount}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("item"):
		return false
	match kind:
		"offhand":
			return RunState.THROWABLES.has(data["item"])
		"trash":
			return true
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	panel.handle_drop(kind, data["item"], int(data["amount"]))


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if kind == "item" and item_id != &"" and button.button_index == MOUSE_BUTTON_RIGHT:
		panel.handle_drop("trash", item_id, 1)
		accept_event()
	elif kind == "item" and item_id != &"" and button.button_index == MOUSE_BUTTON_LEFT and button.double_click:
		if RunState.THROWABLES.has(item_id):
			panel.handle_drop("offhand", item_id, amount)
			accept_event()
