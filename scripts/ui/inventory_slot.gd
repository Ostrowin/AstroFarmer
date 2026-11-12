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


func _init() -> void:
	custom_minimum_size = Vector2(120, 84)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 14)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func setup(slot_kind: String, id: StringName, count: int, title: String, color: Color) -> void:
	kind = slot_kind
	item_id = id
	amount = count
	_label.text = title
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.2, 0.9) if id != &"" or kind != "item" else Color(0.1, 0.08, 0.15, 0.5)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = color
	style.set_content_margin_all(6)
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
