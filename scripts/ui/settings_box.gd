class_name SettingsBox
extends VBoxContainer
## Ustawienia gracza: głośność muzyki, efektów i tła (suwaki 0-100%) oraz pełny ekran.
## Wspólne dla menu głównego i menu pauzy (Esc). Zmiany zapisują się od razu.

## Szyna -> etykieta w grze.
const ROWS := [[&"Music", "Music"], [&"SFX", "Sounds"], [&"Ambient", "Ambience"]]

var sliders := {}
var fullscreen: CheckButton


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	for row: Array in ROWS:
		_add_slider(row[0], row[1])
	fullscreen = CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.add_theme_font_size_override("font_size", 18)
	fullscreen.button_pressed = Display.is_fullscreen()
	fullscreen.toggled.connect(func(on: bool) -> void: Display.set_fullscreen(on))
	Display.fullscreen_changed.connect(_on_fullscreen_changed)
	add_child(fullscreen)


func _exit_tree() -> void:
	if Display.fullscreen_changed.is_connected(_on_fullscreen_changed):
		Display.fullscreen_changed.disconnect(_on_fullscreen_changed)


## Odświeża wartości (np. po F11 albo zmianie w drugim menu).
func refresh() -> void:
	for bus: StringName in sliders:
		(sliders[bus] as HSlider).set_value_no_signal(Sfx.bus_volume(bus) * 100.0)
	if fullscreen:
		fullscreen.set_pressed_no_signal(Display.is_fullscreen())


func _add_slider(bus: StringName, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size = Vector2(110, 0)
	name_label.label_settings = NotebookTheme.label_settings(18)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.custom_minimum_size = Vector2(220, 28)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value = Sfx.bus_volume(bus) * 100.0
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(52, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.label_settings = NotebookTheme.label_settings(16)
	value_label.text = "%d%%" % slider.value
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float) -> void:
		Sfx.set_bus_volume(bus, value / 100.0)
		value_label.text = "%d%%" % value
		if bus == &"SFX":
			Sfx.play(&"ui_click"))
	sliders[bus] = slider
	add_child(row)


func _on_fullscreen_changed(on: bool) -> void:
	if fullscreen:
		fullscreen.set_pressed_no_signal(on)
