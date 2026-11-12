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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.14, 0.94)
	style.set_corner_radius_all(14)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.95, 1, 0.8)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)
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


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func clear() -> void:
	for child in _box.get_children():
		child.queue_free()


func label(text: String, size: int, wrap_width := 0.0, color := Color.WHITE) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.modulate = color
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
