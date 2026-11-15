extends Control
## Odsłuchownia dźwięków: każde zdarzenie gry w jednym wierszu, przy nim
## kandydaci (a, b, c). Klik na kandydacie = odsłuch (losowa wersja), "Use" =
## wybór. "Save" zapisuje wybór do audio/sfx/picks.json, gra czyta go przy starcie.
## Tła (amb_*) grają w pętli, dopóki nie klikniesz Stop.
## Uruchom:
##   Godot_v4.7.2-stable_win64.exe --path . res://tests/sound_board.tscn

const GROUPS := [
	["Farm", ["plant", "harvest", "water", "fill", "craft", "chime", "land"]],
	["Player", ["step_grass", "step_soil", "step_run", "dash", "hurt", "eat", "pickup", "throw", "shot", "scan", "flashlight"]],
	["Creatures", ["roar", "bite", "stun", "death", "snap"]],
	["World", ["boom", "alarm", "evac"]],
	["Interface", ["ui_click", "ui_hover", "deny"]],
	["Ambience (loops)", ["amb_valley_day", "amb_valley_night", "amb_meadow_day", "amb_meadow_night"]],
]

## Utwory: nazwa, opis, plik.
const MUSIC := [
	["star_rodeo (menu)", "orchestra + country", "res://audio/music/star_rodeo.ogg"],
	["homestead (base)", "calm banjo, strings", "res://audio/music/homestead.ogg"],
	["boss_rodeo (boss, later)", "electro + country", "res://audio/music/boss_rodeo.ogg"],
	["rodeo_rave (boss, later)", "hard rave + country", "res://audio/music/rodeo_rave.ogg"],
	["stampede (boss, later)", "hard electro, sub bass", "res://audio/music/stampede.ogg"],
	["hoedown_circuit", "clear beat + banjo country", "res://audio/music/hoedown_circuit.ogg"],
	["heavy_pulse", "60 BPM, rhythm + deep 808", "res://audio/music/heavy_pulse.ogg"],
]

var _notes: Dictionary = {}
var _use_buttons: Dictionary = {}  # event -> {letter: Button}
var _loop: AudioStreamPlayer
var _status: Label


func _ready() -> void:
	theme = NotebookTheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("2b2420")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_loop = AudioStreamPlayer.new()
	_loop.bus = &"Ambient"
	add_child(_loop)
	if FileAccess.file_exists("res://audio/sfx/candidates.json"):
		_notes = JSON.parse_string(FileAccess.get_file_as_string("res://audio/sfx/candidates.json"))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", NotebookTheme.card(NotebookTheme.PANEL, NotebookTheme.BORDER, 3, 1.0, 18))
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.offset_left = 24
	card.offset_top = 24
	card.offset_right = -24
	card.offset_bottom = -24
	add_child(card)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	card.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	top.add_child(_label("Sound board", 28))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	_status = _label("Click a sound to hear it. Use = pick.", 15, NotebookTheme.MUTED, false)
	top.add_child(_status)
	top.add_child(_button("Stop", func() -> void: _stop_all()))
	top.add_child(_button("Save", _save, true))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for group: Array in GROUPS:
		list.add_child(_label(group[0], 20, NotebookTheme.ACCENT))
		for event: String in group[1]:
			if Sfx.candidates(StringName(event)).is_empty():
				continue
			list.add_child(_row(event))
	list.add_child(_label("Music", 20, NotebookTheme.ACCENT))
	for track: Array in MUSIC:
		var music := HBoxContainer.new()
		music.add_theme_constant_override("separation", 10)
		var music_name := _label(track[0], 16)
		music_name.custom_minimum_size = Vector2(190, 0)
		music.add_child(music_name)
		var play_music := _button("Play · " + track[1], func() -> void:
			_loop.stream = load(track[2])
			_loop.play()
			_status.text = "Playing %s. Stop to end." % track[0])
		play_music.custom_minimum_size = Vector2(230, 34)
		music.add_child(play_music)
		list.add_child(music)


func _row(event: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name := _label(event, 16)
	name.custom_minimum_size = Vector2(190, 0)
	row.add_child(name)
	_use_buttons[event] = {}
	for letter in Sfx.candidates(StringName(event)):
		var note: String = _notes.get(event, {}).get(letter, {}).get("note", "")
		var count := Sfx.streams(StringName(event), letter).size()
		var play := _button("%s · %s%s" % [letter, note, "  (%d)" % count if count > 1 else ""],
			_play.bind(event, letter))
		play.custom_minimum_size = Vector2(230, 34)
		row.add_child(play)
		var use := _button("Use", _use.bind(event, letter))
		use.toggle_mode = true
		use.custom_minimum_size = Vector2(64, 34)
		row.add_child(use)
		_use_buttons[event][letter] = use
	_refresh(event)
	return row


func _play(event: String, letter: String) -> void:
	if event.begins_with("amb_") or event.begins_with("music_"):
		var variants := Sfx.streams(StringName(event), letter)
		if variants.is_empty():
			return
		_loop.stream = variants[0]
		_loop.play()
		_status.text = "Playing %s / %s (loop). Stop to end." % [event, letter]
		return
	Sfx.play_candidate(StringName(event), letter)
	_status.text = "%s / %s" % [event, letter]


func _use(event: String, letter: String) -> void:
	Sfx.set_pick(StringName(event), letter)
	_refresh(event)
	_status.text = "%s uses %s (not saved yet)" % [event, letter]


func _refresh(event: String) -> void:
	var pick: String = Sfx.picks.get(event, "a")
	for letter: String in _use_buttons[event]:
		var b: Button = _use_buttons[event][letter]
		b.set_pressed_no_signal(letter == pick)
		var style := NotebookTheme.card(NotebookTheme.ACCENT2 if letter == pick else NotebookTheme.SLOT,
			NotebookTheme.ACCENT2.darkened(0.3) if letter == pick else NotebookTheme.SLOT_BORDER, 2, 1.0, 4)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, style)
		b.add_theme_color_override("font_color", Color.WHITE if letter == pick else NotebookTheme.TEXT)
		b.add_theme_color_override("font_pressed_color", Color.WHITE if letter == pick else NotebookTheme.TEXT)


func _save() -> void:
	_status.text = "Saved to audio/sfx/picks.json" if Sfx.save_picks() else "Could not save picks.json"


func _stop_all() -> void:
	_loop.stop()
	_status.text = "Stopped."


func _label(text: String, size: int, color := NotebookTheme.TEXT, heavy := true) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = NotebookTheme.label_settings(size, color, heavy)
	return l


func _button(text: String, on_pressed: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.set_meta("no_ui_sound", true)
	b.add_theme_font_size_override("font_size", 14)
	if accent:
		b.add_theme_stylebox_override("normal", NotebookTheme.card(NotebookTheme.ACCENT, NotebookTheme.ACCENT.darkened(0.3), 2, 1.0, 6))
		b.add_theme_color_override("font_color", Color.WHITE)
	b.pressed.connect(on_pressed)
	return b
