class_name PauseMenu
extends UiPanel
## Menu pod Esc (baza i wyprawa): pauza gry, głośność, pełny ekran, wyjście do menu głównego
## albo z gry. Wyjście wysyła scenie NOTIFICATION_WM_CLOSE_REQUEST, więc baza zapisuje grę,
## a wyprawa kończy się jak przy zamknięciu okna (porażka, ratunek). Na wyprawie
## wyjście trzeba potwierdzić drugim kliknięciem.

const MENU_SCENE := "res://scenes/menu.tscn"
const WIDTH := 460.0

var _settings: SettingsBox
var _menu_button: Button
var _quit_button: Button
var _confirm := ""


func _ready() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_box.add_theme_constant_override("separation", 12)
	_box.add_child(label("Paused", 26))
	var resume := button("Resume", close, 20)
	resume.custom_minimum_size = Vector2(0, 46)
	_box.add_child(resume)
	_box.add_child(HSeparator.new())
	_settings = SettingsBox.new()
	_box.add_child(_settings)
	_box.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_menu_button = button("Main Menu", _to_menu)
	_quit_button = button("Quit", _quit)
	for b in [_menu_button, _quit_button]:
		(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	_box.add_child(row)


func open() -> void:
	_confirm = ""
	_menu_button.text = "Main Menu"
	_quit_button.text = "Quit"
	open_panel(WIDTH, 0)
	_settings.refresh()
	_center.call_deferred()
	get_tree().paused = true


func close() -> void:
	if not visible:
		return
	get_tree().paused = false
	super()


## Na wyprawie wyjście przerywa ją (porażka), więc pytamy drugi raz.
func _needs_confirm(action: String, button_node: Button) -> bool:
	if GameState.run == null or _confirm == action:
		return false
	_confirm = action
	button_node.text = "Run is lost. Sure?"
	return true


func _to_menu() -> void:
	if _needs_confirm("menu", _menu_button):
		return
	_leave()
	get_tree().change_scene_to_file(MENU_SCENE)


func _quit() -> void:
	if _needs_confirm("quit", _quit_button):
		return
	_leave()
	get_tree().quit()


func _leave() -> void:
	get_tree().paused = false
	visible = false
	get_tree().current_scene.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
