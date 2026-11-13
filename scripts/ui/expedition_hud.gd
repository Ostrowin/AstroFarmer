class_name ExpeditionHud
extends Hud
## HUD wyprawy: paski Kondycji i Przebudzenia, plecak, odliczanie burzy i ewakuacji.

var _health_bar: ProgressBar
var _health_label: Label
var _awake_bar: ProgressBar
var _awake_label: Label
var _alert: Label
var _offhand_panel: PanelContainer
var _offhand_label: Label


func _ready() -> void:
	super()
	_offhand_panel = PanelContainer.new()
	_offhand_panel.anchor_left = 0.5
	_offhand_panel.anchor_right = 0.5
	_offhand_panel.anchor_top = 1.0
	_offhand_panel.anchor_bottom = 1.0
	_offhand_panel.offset_left = 180
	_offhand_panel.offset_right = 380
	_offhand_panel.offset_top = -96
	_offhand_panel.offset_bottom = -26
	_offhand_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offhand_label = _make_label(16)
	_offhand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_offhand_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_offhand_panel.add_child(_offhand_label)
	_root.add_child(_offhand_panel)
	var bars := VBoxContainer.new()
	bars.anchor_left = 0.5
	bars.anchor_right = 0.5
	bars.offset_left = -220
	bars.offset_right = 220
	bars.offset_top = 10
	bars.add_theme_constant_override("separation", 2)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bars)

	_health_label = _make_label(16)
	bars.add_child(_health_label)
	_health_bar = _make_bar(Color(0.95, 0.35, 0.35))
	bars.add_child(_health_bar)
	_awake_label = _make_label(16)
	bars.add_child(_awake_label)
	_awake_bar = _make_bar(Color(0.7, 0.4, 1.0))
	bars.add_child(_awake_bar)

	_alert = _make_label(26)
	_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert.modulate = Color(1, 0.45, 0.4)
	_alert.anchor_left = 0.5
	_alert.anchor_right = 0.5
	_alert.offset_left = -500
	_alert.offset_right = 500
	_alert.offset_top = 128
	_root.add_child(_alert)
	set_awakening(0.0)


func refresh() -> void:
	super()
	if _offhand_label == null or _interaction == null or not _interaction.has_method("offhand_text"):
		return
	_offhand_label.text = _interaction.offhand_text()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.14, 0.6)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = _interaction.offhand_color()
	style.content_margin_left = 8
	style.content_margin_right = 8
	_offhand_panel.add_theme_stylebox_override("panel", style)


func set_player(player: Player) -> void:
	track_player(player)
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.max_health)


func set_awakening(value: float) -> void:
	_awake_bar.value = value
	_awake_label.text = "Awakening %d" % int(value)


func set_alert(text: String) -> void:
	_alert.text = text


func _on_health_changed(health: float, max_health: float) -> void:
	_health_bar.max_value = max_health
	_health_bar.value = health
	_health_label.text = "Health %d/%d" % [ceili(health), int(max_health)]


func _status_text() -> String:
	return GameState.clock_text(GameState.time_of_day)


func _inventory_text() -> String:
	var run := GameState.run
	if run == null:
		return ""
	return "Backpack %d/%d" % [run.used_space(), run.capacity]


## Na wyprawie licznik plecaka jest zawsze widoczny (Tab otwiera pełny plecak).
func details_visible() -> bool:
	return not modal


func _make_bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(440, 16)
	bar.show_percentage = false
	bar.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.03, 0.1, 0.65)
	bg.set_corner_radius_all(6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar
