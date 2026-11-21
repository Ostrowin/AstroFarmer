class_name BeaconMarker
extends Control
## Znacznik celu na HUD (latarnia ewakuacyjna): turkusowy romb nad celem z odległością;
## gdy cel jest poza ekranem albo za plecami, strzałka przy krawędzi ekranu w jego stronę.
## Tuż przy celu znika (wtedy widać samą latarnię).

const COLOR := NotebookTheme.ACCENT2
## Bliżej niż tyle metrów znacznik się chowa.
const HIDE_DISTANCE := 12.0
## Odstęp strzałki od krawędzi ekranu.
const MARGIN := 60.0
## Romb wisi tyle metrów nad celem.
const LIFT := 4.5
## Strzałki przy krawędzi omijają górne paski i pasek narzędzi na dole (piksele).
const TOP_RESERVED := 130.0
const BOTTOM_RESERVED := 170.0

var target: Node3D
var player: Node3D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


## Odległość w poziomie od gracza do celu (m).
func distance() -> float:
	if not is_instance_valid(target) or not is_instance_valid(player):
		return INF
	var d := target.global_position - player.global_position
	return Vector2(d.x, d.z).length()


## "on_screen", "edge" albo "hidden" (dla testów i HUD).
func mode() -> String:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not visible or distance() < HIDE_DISTANCE:
		return "hidden"
	var point := target.global_position + Vector3(0, LIFT, 0)
	var screen := get_viewport_rect().size
	if camera.is_position_behind(point):
		return "edge"
	var inner := Rect2(Vector2(MARGIN, MARGIN), screen - Vector2(MARGIN, MARGIN) * 2.0)
	return "on_screen" if inner.has_point(camera.unproject_position(point)) else "edge"


func _draw() -> void:
	var state := mode()
	if state == "hidden":
		return
	var camera := get_viewport().get_camera_3d()
	var point := target.global_position + Vector3(0, LIFT, 0)
	var screen := get_viewport_rect().size
	var label := "%d m" % int(distance())
	var at := camera.unproject_position(point)
	if state == "on_screen":
		var diamond := PackedVector2Array([at + Vector2(0, -14), at + Vector2(12, 0), at + Vector2(0, 14), at + Vector2(-12, 0)])
		_shape(diamond)
		_text(label, at + Vector2(0, 36))
		return
	# Kierunek w układzie kamery; za plecami strzałka w bok (w stronę krótszego obrotu).
	var local := camera.global_basis.inverse() * (point - camera.global_position)
	var dir := Vector2(local.x, -local.y)
	if local.z > 0.0:
		dir = Vector2(signf(local.x) if absf(local.x) > 0.01 else 1.0, 0.0)
	dir = dir.normalized()
	# Pas na strzałki: bez górnych pasków i bez paska narzędzi na dole.
	var band := Rect2(Vector2(MARGIN, TOP_RESERVED), screen - Vector2(MARGIN * 2.0, TOP_RESERVED + BOTTOM_RESERVED))
	var center := band.get_center()
	var half := band.size * 0.5
	var t := minf(absf(half.x / dir.x) if absf(dir.x) > 0.001 else INF, absf(half.y / dir.y) if absf(dir.y) > 0.001 else INF)
	var pos := center + dir * t
	var arrow := Transform2D(dir.angle(), pos) * PackedVector2Array([Vector2(22, 0), Vector2(-12, -14), Vector2(-6, 0), Vector2(-12, 14)])
	_shape(arrow)
	_text(label, pos - dir * 46 + Vector2(0, 6))


func _shape(points: PackedVector2Array) -> void:
	draw_colored_polygon(points, COLOR)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, NotebookTheme.BORDER, 3.0)


func _text(text: String, center_bottom: Vector2) -> void:
	var font := NotebookTheme.bold()
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	var at := center_bottom - Vector2(size.x * 0.5, 0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, NotebookTheme.TEXT)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
