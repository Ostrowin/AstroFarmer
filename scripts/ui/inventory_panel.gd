class_name InventoryPanel
extends UiPanel
## Plecak na wyprawie (Tab): siatka przedmiotów, druga ręka (PPM) i wyrzucanie.
## Gra toczy się dalej, kiedy plecak jest otwarty.

## Gracz chce wyrzucić przedmioty na ziemię.
signal drop_requested(id: StringName, amount: int)

const COLUMNS := 5
const DESCRIPTIONS := {
	&"seed_snapper": "Throw (RMB): trap",
	&"seed_boomshroom": "Throw (RMB): stun",
	&"voidberry": "Eat: +30 health",
	&"water_misty": "Wakes a Mistbloom seed",
	&"sample_glowmoss": "Rare · workbench",
	&"crystal": "Workbench",
	&"thorn": "Workbench: Pistol Mk2",
	&"pollen": "Meal: Pollen Cookies",
	&"fertilizer": "+1 growth cycle",
}

var _run: RunState


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if visible and event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		close()


func open(run: RunState) -> void:
	if _run != run:
		if _run and _run.changed.is_connected(_on_run_changed):
			_run.changed.disconnect(_on_run_changed)
		_run = run
		_run.changed.connect(_on_run_changed)
	_rebuild()
	open_panel(860, 0)
	_center.call_deferred()


func _on_run_changed() -> void:
	if visible:
		_rebuild()


func handle_drop(target: String, id: StringName, amount: int) -> void:
	if _run == null:
		return
	match target:
		"offhand":
			if _run.set_offhand(id):
				Sfx.play(&"pickup")
		"trash":
			drop_requested.emit(id, amount)
	_rebuild()


func _rebuild() -> void:
	clear()
	if _run == null:
		return
	_box.add_child(label("Backpack %d/%d" % [_run.used_space(), _run.capacity], 26))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	_box.add_child(columns)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	columns.add_child(grid)
	var ids := _run.backpack.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return PlantCatalog.item_name(a) < PlantCatalog.item_name(b))
	for id: StringName in ids:
		var slot := _slot("item", id, _run.count(id), "%s\n×%d" % [PlantCatalog.item_name(id), _run.count(id)], Pickup.entry_for(id)["color"])
		slot.tooltip_text = DESCRIPTIONS.get(id, "")
		grid.add_child(slot)
	for i in maxi(0, COLUMNS * 2 - ids.size()):
		grid.add_child(_slot("item", &"", 0, "", Color(0.3, 0.3, 0.4)))

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	columns.add_child(side)
	side.add_child(label("RMB hand", 16))
	var hand_title := "empty"
	var hand_color := Color(0.5, 0.5, 0.6)
	if _run.offhand != &"":
		hand_title = "%s\n×%d" % [PlantCatalog.item_name(_run.offhand), _run.count(_run.offhand)]
		hand_color = Pickup.entry_for(_run.offhand)["color"]
	side.add_child(_slot("offhand", _run.offhand, _run.count(_run.offhand), hand_title, hand_color))
	side.add_child(label("Drop", 16))
	side.add_child(_slot("trash", &"", 0, "", Color(1.0, 0.45, 0.4)))

	_box.add_child(label("Drag seeds to the hand · RMB drops one", 14, 800, Color(0.8, 0.8, 0.9)))


func _slot(slot_kind: String, id: StringName, count: int, title: String, color: Color) -> InventorySlot:
	var slot := InventorySlot.new()
	slot.panel = self
	slot.setup(slot_kind, id, count, title, color)
	return slot


func _center() -> void:
	var height := get_combined_minimum_size().y
	offset_top = -height * 0.5
	offset_bottom = height * 0.5
