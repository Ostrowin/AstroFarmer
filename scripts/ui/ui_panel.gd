class_name UiPanel
extends PanelContainer
## Wspólna baza okien w bazie (warsztat, raport): wygląd, etykiety, przyciski,
## zamykanie Esc. Pokazuje kursor przy otwarciu.

signal closed

var _box: VBoxContainer


func _init() -> void:
	visible = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	theme = NotebookTheme.theme()
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	add_child(_box)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open_panel(width: float, height: float) -> void:
	offset_left = -width * 0.5
	offset_right = width * 0.5
	offset_top = -height * 0.5
	offset_bottom = height * 0.5
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Wysokość według treści, wyśrodkowane na ekranie.
func _center() -> void:
	var height := get_combined_minimum_size().y
	offset_top = -height * 0.5
	offset_bottom = height * 0.5


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func clear() -> void:
	for child in _box.get_children():
		child.queue_free()


## Tytuły (od 18 px) pogrubione; kolor przechodzi przez NotebookTheme.ink (czytelny na kremowym tle).
func label(text: String, size: int, wrap_width := 0.0, color := Color.WHITE) -> Label:
	var result := Label.new()
	result.text = text
	result.label_settings = NotebookTheme.label_settings(size, NotebookTheme.ink(color), size >= 18)
	if wrap_width > 0.0:
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result.custom_minimum_size = Vector2(wrap_width, 0)
	return result


func button(text: String, on_pressed: Callable, size := 18) -> Button:
	var result := Button.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.custom_minimum_size = Vector2(110, 38)
	result.pressed.connect(on_pressed)
	return result
