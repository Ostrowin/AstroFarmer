class_name TradePanel
extends UiPanel
## Okno handlu ze Sporekinem (na wyprawie): lista ofert, koszt z plecaka, przycisk Trade.

signal traded(id: StringName)

const ICONS := {
	&"plan_spore_mask": &"spore_mask", &"plan_fungicide": &"fungicide", &"mushroom_log": &"mushroom_log",
	&"boomshroom_seeds": &"seed_boomshroom", &"glowmoss": &"sample_glowmoss",
}

var run: RunState


func open(r: RunState) -> void:
	run = r
	_rebuild()
	open_panel(620, 0)
	_center.call_deferred()


func _rebuild() -> void:
	clear()
	_box.add_child(label("Sporekin Trader", 28))
	for offer: Dictionary in Trades.LIST:
		_box.add_child(_row(offer))
	_box.add_child(label("Backpack %d/%d" % [run.used_space(), run.capacity], 15, 0.0, NotebookTheme.MUTED))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(button("Close", close))
	_box.add_child(buttons)


func _row(offer: Dictionary) -> Control:
	var problem := Trades.problem(offer, run)
	var known := problem == "Known"
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", NotebookTheme.card(NotebookTheme.SLOT,
		NotebookTheme.ACCENT2 if known else (NotebookTheme.ACCENT if problem == "" else NotebookTheme.SLOT_BORDER), 2, 1.0, 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(52, 52)
	icon.texture = NotebookTheme.icon(ICONS.get(offer["id"], &""))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(label(offer["name"], 18))
	text.add_child(label(offer["desc"] if known else Trades.cost_text(offer), 13, 330,
		NotebookTheme.BAD if problem.begins_with("Missing") or problem == "Backpack full" else NotebookTheme.MUTED))
	row.add_child(text)
	var action := button("Known" if known else "Trade", _buy.bind(offer["id"]), 15)
	action.disabled = problem != ""
	action.tooltip_text = offer["desc"] + ("\n" + problem if problem != "" and not known else "")
	row.add_child(action)
	return card


func _buy(id: StringName) -> void:
	if not Trades.buy(id, run):
		Sfx.play(&"deny")
		return
	Sfx.play(&"craft")
	traded.emit(id)
	_rebuild()
