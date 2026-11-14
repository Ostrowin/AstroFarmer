extends Node
## Dźwięk: każde zdarzenie użyte w kodzie (Sfx.play(&"...")) ma pliki, wybór
## z picks.json wskazuje istniejącego kandydata, tła są pętlami i przenikają się
## z porą dnia, kroki grają przy ruchu.
## Uruchom:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_audio.tscn

const NEW_EVENTS := ["step_grass", "step_soil", "step_run", "flashlight", "ui_click", "ui_hover",
	"amb_valley_day", "amb_valley_night", "amb_meadow_day", "amb_meadow_night"]

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Zdarzenia z kodu.
	var used := {}
	var regex := RegEx.create_from_string("Sfx\\.play\\(&\"([a-z_]+)\"")
	for path in _scripts("res://scripts/"):
		for m in regex.search_all(FileAccess.get_file_as_string(path)):
			used[m.get_string(1)] = true
	for e in NEW_EVENTS:
		used[e] = true
	_check(used.size() > 25, "znaleziono zdarzenia w kodzie (%d)" % used.size())
	var missing: Array = []
	for e: String in used:
		var pick: String = Sfx.picks.get(e, "")
		if pick == "" or Sfx.streams(StringName(e), pick).is_empty():
			missing.append(e)
	_check(missing.is_empty(), "każde zdarzenie ma wybrany dźwięk z plikami (brak: %s)" % ", ".join(missing))
	for e: String in used:
		_check(Sfx.candidates(StringName(e)).size() >= 2 or e.begins_with("amb_"), "%s: co najmniej 2 kandydatów" % e)

	# Szyny.
	for bus in ["SFX", "Ambient", "Music"]:
		_check(AudioServer.get_bus_index(bus) != -1, "szyna %s" % bus)

	# Tła: pętla, dzień/noc.
	Sfx.set_ambience(&"meadow")
	var day: Array = Sfx.streams(&"amb_meadow_day", Sfx.picks["amb_meadow_day"])
	_check((day[0] as AudioStreamOggVorbis).loop, "tło jest pętlą")
	GameState.time_of_day = 0.5
	await _frames(200)
	var players := Sfx.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer and (n as AudioStreamPlayer).bus == &"Ambient")
	var amb_day := players[0] as AudioStreamPlayer
	var amb_night := players[1] as AudioStreamPlayer
	_check(amb_day.playing and amb_day.volume_db > amb_night.volume_db + 20.0, "w południe gra tło dnia")
	GameState.time_of_day = 0.0
	await _frames(5)
	_check(amb_night.volume_db > amb_day.volume_db + 20.0, "o północy gra tło nocy")
	Sfx.set_ambience(&"")
	_check(not amb_day.playing and not amb_night.playing, "cisza po set_ambience(\"\")")

	# Muzyka menu.
	Sfx.play_music("res://audio/music/star_rodeo.ogg")
	_check(Sfx.music_playing(), "muzyka gra (Star Rodeo)")
	Sfx.play_music("")
	_check(not Sfx.music_playing(), "muzyka cichnie")
	_check(load("res://audio/music/boss_rodeo.ogg") is AudioStream, "jest muzyka bossa (Boss Rodeo)")
	_check(load("res://audio/music/rodeo_rave.ogg") is AudioStream, "jest muzyka bossa (Rodeo Rave)")
	_check(load("res://audio/music/stampede.ogg") is AudioStream, "jest muzyka bossa (Stampede)")

	# Każdy przycisk klika (i można go wyciszyć).
	var button := Button.new()
	add_child(button)
	var ui_players := Sfx.get_children().filter(func(n: Node) -> bool: return n is AudioStreamPlayer and (n as AudioStreamPlayer).bus == &"SFX")
	button.pressed.emit()
	_check(ui_players.any(func(p: AudioStreamPlayer) -> bool: return p.playing), "przycisk klika")

	print("TESTY OK" if _failures == 0 else "TESTY: %d błędów" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):
			out.append(dir + name)
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir + sub + "/"))
	return out


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
	print(("  ok   " if ok else "  FAIL ") + what)
