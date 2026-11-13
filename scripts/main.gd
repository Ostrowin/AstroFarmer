extends Node3D
## Scena bazy: dolina, farma, gracz i HUD.
## Pętla: sadzisz → podlewasz → wyprawa przez drzwi (albo przeczekanie cyklu)
## → rytuał powrotu (kapsuła ląduje) → raport: wyprawa, farma, najazd, planeta
## → zbierasz, bronisz się, ulepszasz w warsztacie → znowu w drogę.

const EXPEDITION_SCENE := "res://scenes/levels/expedition_meadow.tscn"

@onready var _farm: Farm = $Farm
@onready var _player: Player = $Player
@onready var _hud: Hud = $HUD
@onready var _spawn: Marker3D = $Valley/PlayerSpawn
@onready var _pod: LandingPod = $Valley/LandingPod
@onready var _landing_camera: Camera3D = $Valley/LandingCamera
@onready var _landing_exit: Marker3D = $Valley/LandingExit

var _busy := false
var _prep: ExpeditionPrep
var _workbench: WorkbenchPanel
var _report: ReportPanel
var _codex: CodexPanel
var _interaction: PlayerInteraction
## Gdy true, raporty cykli i najazdów są zbierane do panelu zamiast powiadomień.
var _collecting := false
var _farm_lines: Array[String] = []
var _raids: Array[Dictionary] = []


func _ready() -> void:
	var report: Dictionary = GameState.last_run_report
	var returning := not report.is_empty()
	GameState.last_run_report = {}
	if not returning:
		# Start gry: wczytaj zapis. Po powrocie z wyprawy stan jest już w pamięci.
		if not GameState.load_game():
			GameState.new_game()
	_farm.load_from_state()
	_player.global_position = _spawn.global_position

	_interaction = _player.interaction as PlayerInteraction
	_interaction.farm = _farm
	_interaction.gate_used.connect(_open_prep)
	_interaction.workbench_used.connect(_open_workbench)
	_interaction.codex_used.connect(_open_codex)
	_hud.bind(_interaction)
	_hud.track_player(_player)
	_farm.cycle_report.connect(_on_cycle_report)
	_farm.raid_resolved.connect(_on_raid)
	_farm.changed.connect(_save)
	GameState.planet_attention_changed.connect(func(_v: int) -> void: _hud.refresh())

	_prep = ExpeditionPrep.new()
	_hud.add_child(_prep)
	_prep.depart.connect(_depart)
	_prep.rest.connect(_rest)
	_prep.cancelled.connect(_close_modal.bind(_prep))
	_workbench = WorkbenchPanel.new()
	_hud.add_child(_workbench)
	_workbench.closed.connect(_close_modal.bind(_workbench))
	_workbench.crafted.connect(_on_crafted)
	_codex = CodexPanel.new()
	_hud.add_child(_codex)
	_codex.closed.connect(_close_modal.bind(_codex))
	_report = ReportPanel.new()
	_hud.add_child(_report)
	_report.closed.connect(_close_modal.bind(_report))

	if returning:
		_hud.cover()
	var cycles := GameState.pending_cycles
	_begin_collecting()
	_process_pending_cycles()
	_collecting = false
	_save()

	if returning:
		await _landing_ritual()
		_show_report("Back at base", _run_sections(report) + _cycle_sections(cycles))
	elif GameState.cycle == 0 and _farm.plant_count() == 0:
		_hud.notify("Plant seeds, then head to the gate")
	print("Astro Farmer | Godot %s | cycle %d | plants %d" % [Engine.get_version_info().string, GameState.cycle, _farm.plant_count()])


func _unhandled_input(event: InputEvent) -> void:
	if _busy or _hud.modal:
		return
	if event.is_action_pressed("debug_next_cycle"):
		GameState.advance_cycle()
	elif event.is_action_pressed("debug_new_game"):
		GameState.new_game()
		_farm.load_from_state()
		_save()
		_hud.refresh()
		_hud.notify("Debug: new game")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


# --- Okna --------------------------------------------------------------------

func _open_modal() -> void:
	_player.input_enabled = false
	_hud.modal = true


func _close_modal(panel: Control) -> void:
	panel.visible = false
	_hud.modal = false
	_player.input_enabled = true
	_player.capture_mouse()


func _open_prep() -> void:
	if _busy or _hud.modal:
		return
	_open_modal()
	_prep.open()


func _open_workbench() -> void:
	if _busy or _hud.modal:
		return
	_open_modal()
	_workbench.open()


func _open_codex() -> void:
	if _busy or _hud.modal:
		return
	_open_modal()
	_codex.open()


func _on_crafted(id: StringName) -> void:
	_hud.refresh()
	_save()
	var recipe := Recipes.get_recipe(id)
	_hud.notify("Zrobione: %s" % recipe.get("name", id))


func _show_report(title: String, sections: Array) -> void:
	_open_modal()
	_report.show_report(title, sections)


# --- Wyprawa i odpoczynek ----------------------------------------------------

func _depart(loadout: Dictionary, options: Dictionary = {}) -> void:
	_prep.visible = false
	_hud.modal = false
	_busy = true
	GameState.start_run(loadout, options)
	_save()
	_player.capture_mouse()
	await _hud.fade_out("Wild Meadow%s" % (" II" if GameState.run.level >= 2 else ""))
	get_tree().change_scene_to_file(EXPEDITION_SCENE)


func _rest() -> void:
	_close_modal(_prep)
	_busy = true
	_player.input_enabled = false
	await _hud.fade_out("Resting...")
	_begin_collecting()
	GameState.advance_cycle()
	_collecting = false
	await get_tree().create_timer(0.8).timeout
	await _hud.fade_in()
	_busy = false
	_show_report("A cycle passed", _cycle_sections(1))


## Rytuał powrotu: kamera na lądowisko, kapsuła opada z nieba, farmer wysiada.
func _landing_ritual() -> void:
	_busy = true
	_player.input_enabled = false
	_player.visible = false
	_hud.show_overlay(false)
	_landing_camera.current = true
	_hud.fade_in()
	await _pod.land()
	await get_tree().create_timer(0.5).timeout
	_player.global_position = _landing_exit.global_position
	_player.visible = true
	_player.camera.current = true
	_hud.show_overlay(true)
	_player.input_enabled = true
	_busy = false


# --- Cykle i raporty ---------------------------------------------------------

func _process_pending_cycles() -> void:
	while GameState.pending_cycles > 0:
		GameState.pending_cycles -= 1
		GameState.advance_cycle()


func _begin_collecting() -> void:
	_collecting = true
	_farm_lines.clear()
	_raids.clear()


func _on_cycle_report(lines: Array) -> void:
	if _collecting:
		for line in lines:
			if not _farm_lines.has(line):
				_farm_lines.append(line)
		return
	Sfx.play(&"chime")
	_hud.notify("Cycle %d" % GameState.cycle)
	for line in lines:
		_hud.notify(line)


func _on_raid(result: Dictionary) -> void:
	Sfx.play(&"alarm")
	if _collecting:
		_raids.append(result)
		return
	for line in result["lines"]:
		_hud.notify(line)


func _run_sections(report: Dictionary) -> Array:
	var lines: Array[String] = []
	var success: bool = report.get("success", false)
	if success:
		var items: Dictionary = report.get("items", {})
		lines.append(_describe(items) if not items.is_empty() else "Nothing brought back")
	else:
		lines.append("Rescued. %s" % report.get("cause", ""))
		var lost: Dictionary = report.get("lost", {})
		if not lost.is_empty():
			lines.append("Lost: %s" % _describe(lost))
	var discoveries: Array = report.get("discoveries", [])
	if not discoveries.is_empty():
		lines.append("New entries: %d" % discoveries.size())
	return [{"title": "Expedition" if success else "Expedition failed", "lines": lines, "tone": "good" if success else "bad"}, _planet_section(int(report.get("attention", 0)), success)]


func _cycle_sections(cycles: int) -> Array:
	var sections: Array = []
	var farm_lines: Array[String] = _farm_lines.duplicate()
	if farm_lines.is_empty():
		farm_lines.append("No changes")
	sections.append({"title": "Farm · cycle %d" % GameState.cycle, "lines": farm_lines, "tone": "info"})
	for raid in _raids:
		sections.append({"title": "Raid!", "lines": raid["lines"], "tone": "raid"})
	if _raids.is_empty():
		sections.append({"title": "", "lines": [_pressure_line()], "tone": "info"})
	return sections


func _planet_section(delta: int, success: bool) -> Dictionary:
	var lines: Array[String] = []
	var reason := "rare loot" if delta > 0 else ("quiet trip" if success else "nothing taken")
	lines.append("Attention %+d (%s) · %d/100" % [delta, reason, GameState.planet_attention])
	if GameState.planet_attention >= Raid.ATTENTION_HIGH:
		lines.append("High attention: bigger raids")
	lines.append(_pressure_line())
	return {"title": "Planet", "lines": lines, "tone": "bad" if delta > 0 else "info"}


static func _pressure_line() -> String:
	var cycles := Raid.cycles_until(GameState.raid_pressure, GameState.planet_attention)
	return "Next raid in %s" % Raid.cycles_text(cycles)


static func _describe(items: Dictionary) -> String:
	var parts: Array[String] = []
	for id in items:
		parts.append("%d× %s" % [items[id], PlantCatalog.item_name(id)])
	return ", ".join(parts)


func _save() -> void:
	var error := GameState.save_game()
	if error != OK:
		push_warning("Could not save the game: %s" % error_string(error))
