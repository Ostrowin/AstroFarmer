extends Node
## Ustawienia (głośność, pełny ekran) i menu pauzy pod Esc.
## Uruchom:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_settings.tscn

const TEST_SAVE := "user://test_settings_save.json"
const TEST_SETTINGS := "user://test_settings.cfg"

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var real_settings := Sfx.settings_path
	var real_volumes: Dictionary = Sfx.volumes.duplicate()
	Sfx.settings_path = TEST_SETTINGS
	GameState.save_path = TEST_SAVE
	_test_volumes()
	await _test_pause()
	for bus in real_volumes:
		Sfx.set_bus_volume(bus, real_volumes[bus], false)
	Sfx.settings_path = real_settings
	GameState.save_path = GameState.SAVE_PATH
	for path in [TEST_SAVE, TEST_SETTINGS]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_finish()


func _test_volumes() -> void:
	Sfx.set_bus_volume(&"Music", 0.5)
	var music := AudioServer.get_bus_index(&"Music")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(music), linear_to_db(0.5)), "suwak muzyki zmienia szynę Music")
	Sfx.set_bus_volume(&"SFX", 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "0% wycisza efekty")
	Sfx.volumes[&"Music"] = 1.0
	Sfx.volumes[&"SFX"] = 1.0
	Sfx._load_volumes()
	_check(is_equal_approx(Sfx.bus_volume(&"Music"), 0.5) and Sfx.bus_volume(&"SFX") == 0.0, "głośność zapisana w ustawieniach")
	Sfx.set_bus_volume(&"SFX", 1.0)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "podgłośnienie zdejmuje wyciszenie")
	Display.set_fullscreen(false)
	var config := ConfigFile.new()
	config.load(TEST_SETTINGS)
	_check(config.get_value("display", "fullscreen", true) == false, "wybór pełnego ekranu zapisany")
	var box := SettingsBox.new()
	add_child(box)
	_check(box.sliders.size() == 3 and is_equal_approx((box.sliders[&"Music"] as HSlider).value, 50.0), "panel ustawień pokazuje zapisane wartości")
	(box.sliders[&"Ambient"] as HSlider).value = 30
	_check(is_equal_approx(Sfx.bus_volume(&"Ambient"), 0.3), "przesunięcie suwaka zmienia głośność")
	box.queue_free()


func _test_pause() -> void:
	GameState.new_game()
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(5)
	var hud := main.get_node("HUD") as Hud
	_press_escape()
	await _frames(2)
	_check(hud.pause_menu.visible and get_tree().paused, "Esc otwiera menu i pauzuje grę")
	_press_escape()
	await _frames(2)
	_check(not hud.pause_menu.visible and not get_tree().paused and not hud.modal, "drugi Esc wraca do gry")
	hud.modal = true
	_press_escape()
	await _frames(2)
	_check(not hud.pause_menu.visible, "przy otwartym oknie Esc nie otwiera pauzy")
	hud.modal = false
	GameState.start_run({})
	hud.open_pause()
	hud.pause_menu._to_menu()
	_check(hud.pause_menu.visible and hud.pause_menu._menu_button.text != "Main Menu", "na wyprawie wyjście trzeba potwierdzić")
	hud.pause_menu.close()
	GameState.run = null
	main.queue_free()
	await _frames(2)


func _press_escape() -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = &"ui_cancel"
	Input.parse_input_event(release)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _finish() -> void:
	if _failures == 0:
		print("TESTY OK")
	else:
		printerr("TESTY: %d błędów" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		printerr("  FAIL ", label)
