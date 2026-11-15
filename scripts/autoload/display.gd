extends Node
## Okno gry (autoload "Display"). Domyślnie pełny ekran; wybór gracza (F11, Alt+Enter
## albo przełącznik w ustawieniach) zapisuje się w user://settings.cfg.

signal fullscreen_changed(on: bool)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	config.load(Sfx.settings_path)
	set_fullscreen(bool(config.get_value("display", "fullscreen", true)), false)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func toggle_fullscreen() -> void:
	set_fullscreen(not is_fullscreen())


func set_fullscreen(on: bool, save := true) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	if save:
		var config := ConfigFile.new()
		config.load(Sfx.settings_path)
		config.set_value("display", "fullscreen", on)
		config.save(Sfx.settings_path)
	fullscreen_changed.emit(on)
