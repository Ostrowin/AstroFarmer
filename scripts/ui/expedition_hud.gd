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
## Znacznik latarni ewakuacyjnej (romb nad nią albo strzałka przy krawędzi ekranu).
var beacon_marker: BeaconMarker
var _overlay_shown := true


func _ready() -> void:
	super()
	_offhand_panel = PanelContainer.new()
	_offhand_panel.anchor_left = 0.5
	_offhand_panel.anchor_right = 0.5
	_offhand_panel.anchor_top = 1.0
	_offhand_panel.anchor_bottom = 1.0
	_offhand_panel.offset_left = 100
	_offhand_panel.offset_right = 260
	_offhand_panel.offset_top = -94
	_offhand_panel.offset_bottom = -24
	_offhand_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offhand_label = Label.new()
	_offhand_label.label_settings = NotebookTheme.label_settings(15)
	_offhand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_offhand_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_offhand_panel.add_child(_offhand_label)
	_root.add_child(_offhand_panel)
	var bars := VBoxContainer.new()
	bars.anchor_left = 0.5
	bars.anchor_right = 0.5
	bars.offset_left = -200
	bars.offset_right = 200
	bars.offset_top = 14
	bars.add_theme_constant_override("separation", 4)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bars)

	_health_label = _make_label(16)
	bars.add_child(_health_label)
	_health_bar = _make_bar(NotebookTheme.HEALTH, 20)
	bars.add_child(_health_bar)
	_awake_label = _make_label(16)
	bars.add_child(_awake_label)
	_awake_bar = _make_bar(NotebookTheme.AWAKE, 14)
	bars.add_child(_awake_bar)

	_alert = _make_label(26)
	_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert.label_settings.font_color = Color(1, 0.55, 0.45)
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
	_offhand_panel.add_theme_stylebox_override("panel",
		NotebookTheme.card(NotebookTheme.SLOT, _interaction.offhand_color().darkened(0.2), 3, 0.95, 6))


func set_player(player: Player) -> void:
	track_player(player)
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.max_health)


## Pokazuje drogę do latarni ewakuacyjnej (znacznik / strzałka z odległością).
func track_beacon(beacon: Node3D, player: Node3D) -> void:
	beacon_marker = BeaconMarker.new()
	beacon_marker.name = "BeaconMarker"
	beacon_marker.target = beacon
	beacon_marker.player = player
	_root.add_child(beacon_marker)
	_root.move_child(beacon_marker, 0)  # pod kartami HUD


func _process(delta: float) -> void:
	super(delta)
	if beacon_marker:
		beacon_marker.visible = _overlay_shown and not modal and _fade.modulate.a < 0.01


func show_overlay(show: bool) -> void:
	super(show)
	_overlay_shown = show


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


func _make_bar(fill: Color, height := 16) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(400, height)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.add_theme_stylebox_override("background", NotebookTheme.bar(Color(NotebookTheme.PANEL_DARK, 0.9), true))
	bar.add_theme_stylebox_override("fill", NotebookTheme.bar(fill))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar
