class_name CodexPanel
extends UiPanel
## Baza danych (komputer w chatce): wpisy z odkrytymi faktami, podpowiedzi
## do brakujących, kompletność i postęp do poziomu 2 doliny.


func open() -> void:
	_rebuild()
	open_panel(820, 720)


func _rebuild() -> void:
	clear()
	var research := GameState.research
	var max_level := GameState.max_level()
	_box.add_child(label("Database %d%%" % Codex.completion(research, max_level), 26))
	var found := Codex.discovered_count(research, 1)
	if max_level < 2:
		_box.add_child(label("Meadow II: %d/%d entries" % [found, Codex.LEVEL2_REQUIRED], 15, 760, Color(1.0, 0.85, 0.6)))
	else:
		_box.add_child(label("Meadow II unlocked", 15, 760, Color(0.6, 1.0, 0.6)))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(770, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for category: String in Codex.CATEGORIES:
		list.add_child(label(category, 21, 0.0, Color(0.5, 0.95, 1.0)))
		for id in Codex.ENTRIES:
			var entry: Dictionary = Codex.ENTRIES[id]
			if entry["category"] == category:
				_add_entry(list, id, entry, research, max_level)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(button("Close", close))
	_box.add_child(buttons)


func _add_entry(list: VBoxContainer, id: StringName, entry: Dictionary, research: Dictionary, max_level: int) -> void:
	var known: Array = research.get(id, [])
	var total := Codex.fact_count(id)
	var stars := "★".repeat(known.size()) + "☆".repeat(total - known.size())
	if int(entry["level"]) > max_level:
		list.add_child(label("  ???  · Meadow II", 17, 0.0, Color(0.6, 0.6, 0.7)))
		return
	var title := "%s  %s" % [entry["name"] if not known.is_empty() else "???", stars]
	list.add_child(label("  " + title, 18, 0.0, Color.WHITE if not known.is_empty() else Color(0.7, 0.7, 0.8)))
	for item: Dictionary in entry["facts"]:
		if known.has(item["how"]):
			list.add_child(label("      · " + String(item["text"]), 15, 720))
		else:
			list.add_child(label("      · ??? (%s)" % item["hint"], 15, 720, Color(0.65, 0.65, 0.75)))
