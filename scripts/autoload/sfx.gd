extends Node
## Dźwięki gry z plików (autoload "Sfx").
##
## Każde zdarzenie (np. &"roar") ma w audio/sfx/<zdarzenie>/ 2-3 kandydatów (a, b, c),
## a każdy kandydat kilka wersji dźwięku: przy odtworzeniu gra losuje jedną
## i lekko zmienia wysokość, żeby się nie nudziło. Który kandydat gra, mówi
## audio/sfx/picks.json (jedna linia na zdarzenie; zmienia go też odsłuchownia
## tests/sound_board.tscn). Pliki składa tools/audio/build_sounds.py.
##
## Szyny głośności: SFX (efekty i interfejs), Ambient (tła), Music.
## Tła: set_ambience(&"valley" / &"meadow") gra pętlę dnia i nocy, przenikające
## się razem z zegarem (noc ciszej).

const SFX_DIR := "res://audio/sfx/"
const PICKS_PATH := "res://audio/sfx/picks.json"
const POOL_SIZE := 16
const BUSES := [&"SFX", &"Ambient", &"Music"]
## Głośność (dB) i rozrzut wysokości zdarzeń; reszta: 0 dB, ±6%.
const SETTINGS := {
	&"step_grass": {"db": -15.0, "pitch": 0.1}, &"step_soil": {"db": -13.0, "pitch": 0.1},
	&"step_run": {"db": -11.0, "pitch": 0.1}, &"ui_hover": {"db": -20.0, "pitch": 0.04},
	&"ui_click": {"db": -9.0, "pitch": 0.04}, &"flashlight": {"db": -8.0, "pitch": 0.03},
	&"deny": {"db": -7.0, "pitch": 0.0}, &"chime": {"db": -5.0, "pitch": 0.0}, &"alarm": {"db": -4.0, "pitch": 0.0},
	&"plant": {"db": -4.0}, &"harvest": {"db": -3.0}, &"water": {"db": -6.0}, &"fill": {"db": -6.0},
	&"pickup": {"db": -5.0}, &"scan": {"db": -8.0}, &"shot": {"db": -8.0, "pitch": 0.08},
	&"throw": {"db": -6.0}, &"dash": {"db": -6.0}, &"eat": {"db": -4.0}, &"hurt": {"db": -3.0},
	&"roar": {"db": 0.0, "pitch": 0.1}, &"death": {"db": -2.0, "pitch": 0.1}, &"boom": {"db": 0.0},
}
## Tło: głośność dnia i nocy (dB) na szynie Ambient.
const AMBIENCE_DAY_DB := -6.0
const AMBIENCE_NIGHT_DB := -10.0
const AMBIENCE_FADE := 2.5

var picks: Dictionary = {}
var _streams: Dictionary = {}  # "event/letter" -> Array[AudioStream]
var _players: Array[AudioStreamPlayer3D] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _next := 0
var _next_ui := 0
var _hover_cooldown := 0.0
var _ambience := &""
var _amb_day: AudioStreamPlayer
var _amb_night: AudioStreamPlayer
var _amb_fade := 0.0
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	picks = _load_picks()
	for i in POOL_SIZE:
		var player := AudioStreamPlayer3D.new()
		player.unit_size = 6.0
		player.max_distance = 60.0
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)
	for i in 4:
		var ui := AudioStreamPlayer.new()
		ui.bus = &"SFX"
		add_child(ui)
		_ui_players.append(ui)
	_amb_day = _make_loop_player(&"Ambient")
	_amb_night = _make_loop_player(&"Ambient")
	_music = _make_loop_player(&"Music")
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	_hover_cooldown -= delta
	if _ambience == &"":
		return
	_amb_fade = minf(1.0, _amb_fade + delta / AMBIENCE_FADE)
	var night := GameState.night_amount(GameState.time_of_day)
	_amb_day.volume_db = AMBIENCE_DAY_DB + linear_to_db(maxf((1.0 - night) * _amb_fade, 0.0001))
	_amb_night.volume_db = AMBIENCE_NIGHT_DB + linear_to_db(maxf(night * _amb_fade, 0.0001))


# --- Efekty ------------------------------------------------------------------

## Odtwarza dźwięk zdarzenia. Z pozycją: w świecie (3D), bez: interfejs.
## `pitch_jitter` < 0 = rozrzut z SETTINGS.
func play(id: StringName, position = null, pitch_jitter := -1.0) -> void:
	play_candidate(id, picks.get(String(id), "a"), position, pitch_jitter)


func play_candidate(id: StringName, letter: String, position = null, pitch_jitter := -1.0) -> void:
	var variants := streams(id, letter)
	if variants.is_empty():
		return
	var settings: Dictionary = SETTINGS.get(id, {})
	var jitter: float = pitch_jitter if pitch_jitter >= 0.0 else float(settings.get("pitch", 0.06))
	var stream: AudioStream = variants.pick_random()
	var pitch := 1.0 + randf_range(-jitter, jitter)
	var db: float = settings.get("db", 0.0)
	if position == null:
		var ui := _ui_players[_next_ui]
		_next_ui = (_next_ui + 1) % _ui_players.size()
		ui.stream = stream
		ui.volume_db = db
		ui.pitch_scale = pitch
		ui.play()
		return
	var player := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = stream
	player.global_position = position
	player.volume_db = db
	player.pitch_scale = pitch
	player.play()


## Kandydaci zdarzenia (litery folderów: a, b, c).
func candidates(id: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for name in _list(SFX_DIR + String(id) + "/"):
		if name.ends_with("/"):
			out.append(name.trim_suffix("/"))
	out.sort()
	return out


## Wszystkie zdarzenia, które mają pliki.
func events() -> PackedStringArray:
	var out := PackedStringArray()
	for name in _list(SFX_DIR):
		if name.ends_with("/"):
			out.append(name.trim_suffix("/"))
	out.sort()
	return out


## Wersje dźwięku kandydata (wczytywane przy pierwszym użyciu).
func streams(id: StringName, letter: String) -> Array:
	var key := "%s/%s" % [id, letter]
	if _streams.has(key):
		return _streams[key]
	var list: Array = []
	var dir := SFX_DIR + key + "/"
	for name in _list(dir):
		if name.get_extension() in ["ogg", "wav", "mp3"]:
			var stream := load(dir + name) as AudioStream
			if stream:
				if String(id).begins_with("amb_") and stream is AudioStreamOggVorbis:
					(stream as AudioStreamOggVorbis).loop = true
				list.append(stream)
	_streams[key] = list
	return list


func set_pick(id: StringName, letter: String) -> void:
	picks[String(id)] = letter
	if String(id).begins_with("amb_") and _ambience != &"":
		var level := _ambience
		_ambience = &""
		set_ambience(level)


## Zapisuje wybór do audio/sfx/picks.json (działa przy uruchomieniu z projektu).
func save_picks() -> bool:
	var file := FileAccess.open(PICKS_PATH, FileAccess.WRITE)
	if file == null:
		return false
	var keys := picks.keys()
	keys.sort()
	var lines: PackedStringArray = []
	for key in keys:
		lines.append(' "%s": "%s"' % [key, picks[key]])
	file.store_string("{\n" + ",\n".join(lines) + "\n}")
	return true


# --- Tło i muzyka ------------------------------------------------------------

## Tło poziomu: &"valley", &"meadow" albo &"" (cisza).
func set_ambience(level: StringName) -> void:
	if level == _ambience:
		return
	_ambience = level
	_amb_fade = 0.0
	for pair in [[_amb_day, "day"], [_amb_night, "night"]]:
		var player: AudioStreamPlayer = pair[0]
		player.stop()
		if level == &"":
			continue
		var id := StringName("amb_%s_%s" % [level, pair[1]])
		var variants := streams(id, picks.get(String(id), "a"))
		if variants.is_empty():
			continue
		player.stream = variants[0]
		player.volume_db = -80.0
		player.play(randf() * 10.0)


func ambience() -> StringName:
	return _ambience


## Muzyka w pętli na szynie Music (pusta ścieżka = cisza).
func play_music(path: String, volume_db := -8.0) -> void:
	if path == "":
		_music.stop()
		return
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music.stream = stream
	_music.volume_db = -40.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", volume_db, 2.0)


func music_playing() -> bool:
	return _music.playing


# --- Pomocnicze --------------------------------------------------------------

## Każdy przycisk w grze klika (i cicho szumi pod myszą).
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		# Meta "no_ui_sound" wycisza przycisk (np. w odsłuchowni).
		button.pressed.connect(func() -> void:
			if not button.has_meta("no_ui_sound"):
				play(&"ui_click"))
		button.mouse_entered.connect(func() -> void:
			if _hover_cooldown <= 0.0 and not button.disabled and not button.has_meta("no_ui_sound"):
				_hover_cooldown = 0.06
				play(&"ui_hover"))


func _make_loop_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


func _ensure_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, &"Master")


func _load_picks() -> Dictionary:
	if not FileAccess.file_exists(PICKS_PATH):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(PICKS_PATH))
	return data if data is Dictionary else {}


## Zawartość folderu res:// (działa też w wyeksportowanej grze).
func _list(path: String) -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(path):
		return PackedStringArray()
	return ResourceLoader.list_directory(path)
