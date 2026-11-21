class_name MainMenu
extends Node3D
## Ekran startowy: nocna dolina w tle (wolny przelot kamery), logo i przyciski
## Continue / New Game / Settings / Quit w stylu Field Notebook.
## Settings rozwija obok kartę z głośnością i pełnym ekranem (SettingsBox).

const GAME_SCENE := "res://scenes/main.tscn"
const ORBIT_CENTER := Vector3(-2, 1.5, -2)
const ORBIT_RADIUS := 15.0
## „Star Rodeo”: orkiestra i country, skomponowane w SoundCraft (tools/audio/star_rodeo.py).
const MUSIC := "res://audio/music/star_rodeo.ogg"

var _camera: Camera3D
var _time := 0.0
var _confirm_new := false
var _new_button: Button
var _settings_card: PanelContainer


func _ready() -> void:
	# Tło: dolina nocą, z bioluminescencją. Zegar stoi w miejscu, gra jeszcze nie ruszyła.
	var main := (load(GAME_SCENE) as PackedScene).instantiate()
	for name in ["WorldEnvironment", "Sun"]:
		var node := main.get_node(name)
		node.owner = null
		main.remove_child(node)
		add_child(node)
	main.free()
	var we := get_node("WorldEnvironment") as WorldEnvironment
	we.environment = we.environment.duplicate(true)
	add_child((load("res://scenes/levels/valley.tscn") as PackedScene).instantiate())
	# Stan z zapisu (do opisu pod przyciskami); gra i tak wczyta go jeszcze raz po starcie.
	GameState.load_game()
	GameState.time_of_day = 0.02
	var day_night := DayNight.new()
	day_night.drive_clock = false
	add_child(day_night)
	day_night.setup(we.environment, get_node("Sun") as DirectionalLight3D)
	Sfx.set_ambience(&"valley")
	Sfx.play_music(MUSIC, -9.0)
	_camera = Camera3D.new()
	_camera.far = 400
	add_child(_camera)
	_camera.current = true
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	_time += delta * 0.04
	_camera.position = ORBIT_CENTER + Vector3(cos(_time) * ORBIT_RADIUS, 8.0, sin(_time) * ORBIT_RADIUS)
	_camera.look_at(ORBIT_CENTER)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = NotebookTheme.theme()
	layer.add_child(root)

	var box := VBoxContainer.new()
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = 90
	box.offset_top = -230
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)

	var title := VBoxContainer.new()
	title.add_theme_constant_override("separation", -18)
	box.add_child(title)
	title.add_child(_title_label("ASTRO", Color.WHITE))
	title.add_child(_title_label("FARMER", NotebookTheme.ACCENT))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)

	var has_save := FileAccess.file_exists(GameState.save_path)
	if has_save:
		box.add_child(_button("Continue", _continue, true))
	_new_button = _button("New Game", _new_game, not has_save)
	box.add_child(_new_button)
	box.add_child(_button("Settings", _toggle_settings, false))
	box.add_child(_button("Quit", func() -> void: get_tree().quit(), false))

	if has_save:
		var info := Label.new()
		info.text = "Cycle %d  ·  Database %d%%" % [GameState.cycle, Codex.completion(GameState.research, GameState.max_level(), GameState.forest_unlocked())]
		info.label_settings = NotebookTheme.world_label_settings(16)
		box.add_child(info)

	_settings_card = PanelContainer.new()
	_settings_card.add_theme_stylebox_override("panel", NotebookTheme.card(NotebookTheme.PANEL, NotebookTheme.BORDER, 3, 0.96, 16))
	_settings_card.anchor_top = 0.5
	_settings_card.anchor_bottom = 0.5
	_settings_card.offset_left = 460
	_settings_card.offset_top = -40
	_settings_card.custom_minimum_size = Vector2(440, 0)
	_settings_card.add_child(SettingsBox.new())
	_settings_card.visible = false
	root.add_child(_settings_card)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _settings_card.visible:
		_settings_card.visible = false


func _toggle_settings() -> void:
	_settings_card.visible = not _settings_card.visible
	if _settings_card.visible:
		(_settings_card.get_child(0) as SettingsBox).refresh()


func _title_label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	var ls := NotebookTheme.label_settings(84, color)
	ls.outline_size = 14
	ls.outline_color = NotebookTheme.TEXT
	ls.shadow_size = 0
	ls.shadow_color = Color(0, 0, 0, 0.45)
	ls.shadow_offset = Vector2(0, 6)
	l.label_settings = ls
	return l


func _button(text: String, on_pressed: Callable, main := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 54)
	b.add_theme_font_size_override("font_size", 22)
	if main:
		var accent := NotebookTheme.card(NotebookTheme.ACCENT, NotebookTheme.ACCENT.darkened(0.35), 3, 1.0, 8)
		b.add_theme_stylebox_override("normal", accent)
		var hover := accent.duplicate() as StyleBoxFlat
		hover.bg_color = NotebookTheme.ACCENT.lightened(0.12)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.pressed.connect(on_pressed)
	return b


func _continue() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


## Nowa gra kasuje postęp, więc przy istniejącym zapisie trzeba kliknąć drugi raz.
func _new_game() -> void:
	if FileAccess.file_exists(GameState.save_path) and not _confirm_new:
		_confirm_new = true
		_new_button.text = "Erase save?  Click again"
		return
	GameState.new_game()
	GameState.save_game()
	get_tree().change_scene_to_file(GAME_SCENE)
