extends Node3D
## Scena bazy: dolina, farma, gracz i HUD.
## Pętla: sadzisz → podlewasz → wyprawa przez drzwi (albo przeczekanie cyklu)
## → po powrocie rośliny rosną → zbierasz → masz nasiona → sadzisz znowu.

const EXPEDITION_SCENE := "res://scenes/levels/expedition_meadow.tscn"

@onready var _farm: Farm = $Farm
@onready var _player: Player = $Player
@onready var _hud: Hud = $HUD
@onready var _spawn: Marker3D = $Valley/PlayerSpawn

var _busy := false
var _prep: ExpeditionPrep
var _interaction: PlayerInteraction


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
	_hud.bind(_interaction)
	_farm.cycle_report.connect(_on_cycle_report)
	_farm.changed.connect(_save)

	_prep = ExpeditionPrep.new()
	_hud.add_child(_prep)
	_prep.depart.connect(_depart)
	_prep.rest.connect(_rest)
	_prep.cancelled.connect(_close_prep)

	if returning:
		_hud.cover()
	_process_pending_cycles()
	_save()

	if returning:
		_show_run_report(report)
		_hud.fade_in()
	elif GameState.cycle == 0 and _farm.plant_count() == 0:
		_hud.notify("Nowa gra. Posadź nasiona (1-3, LPM), podlej konewką (4).")
		_hud.notify("Potem idź do drzwi wyprawy na północy (E).")
	else:
		_hud.notify("Wczytano zapis · cykl %d · roślin: %d" % [GameState.cycle, _farm.plant_count()])
	print("Astro Farmer | Godot %s | cykl %d | roślin %d" % [Engine.get_version_info().string, GameState.cycle, _farm.plant_count()])


func _unhandled_input(event: InputEvent) -> void:
	if _busy or _prep.visible:
		return
	if event.is_action_pressed("debug_next_cycle"):
		GameState.advance_cycle()
	elif event.is_action_pressed("debug_new_game"):
		GameState.new_game()
		_farm.load_from_state()
		_save()
		_hud.refresh()
		_hud.notify("Debug: nowa gra")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


# --- Drzwi wyprawy -----------------------------------------------------------

func _open_prep() -> void:
	if _busy:
		return
	_player.input_enabled = false
	_hud.modal = true
	_prep.open()


func _close_prep() -> void:
	_prep.visible = false
	_hud.modal = false
	_player.input_enabled = true
	_player.capture_mouse()


func _depart(loadout: Dictionary) -> void:
	_prep.visible = false
	_hud.modal = false
	_busy = true
	GameState.start_run(loadout)
	_save()
	_player.capture_mouse()
	await _hud.fade_out("Lot na Dziką łąkę...")
	get_tree().change_scene_to_file(EXPEDITION_SCENE)


func _rest() -> void:
	_close_prep()
	_busy = true
	_player.input_enabled = false
	await _hud.fade_out("Odpoczywasz w bazie...\nMija 1 cykl")
	GameState.advance_cycle()
	await get_tree().create_timer(0.8).timeout
	await _hud.fade_in()
	_player.input_enabled = true
	_busy = false


# --- Cykle i raporty ---------------------------------------------------------

func _process_pending_cycles() -> void:
	while GameState.pending_cycles > 0:
		GameState.pending_cycles -= 1
		GameState.advance_cycle()


func _on_cycle_report(lines: Array) -> void:
	Sfx.play(&"chime")
	_hud.notify("Minął cykl. Teraz: %d" % GameState.cycle)
	for line in lines:
		_hud.notify(line)


func _show_run_report(report: Dictionary) -> void:
	var discoveries: Array = report.get("discoveries", [])
	if report.get("success", false):
		var items: Dictionary = report.get("items", {})
		_hud.notify("Wyprawa udana! Przywiozłeś: %s" % (_describe(items) if not items.is_empty() else "nic"))
	else:
		_hud.notify("Kapsuła ratunkowa przywiozła cię nieprzytomnego. %s" % report.get("cause", ""))
		var lost: Dictionary = report.get("lost", {})
		if not lost.is_empty():
			_hud.notify("Stracony plecak: %s" % _describe(lost))
	if not discoveries.is_empty():
		_hud.notify("Nowe odkrycia zachowane: %d" % discoveries.size())


static func _describe(items: Dictionary) -> String:
	var parts: Array[String] = []
	for id in items:
		parts.append("%d× %s" % [items[id], PlantCatalog.item_name(id)])
	return ", ".join(parts)


func _save() -> void:
	var error := GameState.save_game()
	if error != OK:
		push_warning("Nie udało się zapisać gry: %s" % error_string(error))
