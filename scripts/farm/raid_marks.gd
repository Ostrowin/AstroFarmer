class_name RaidMarks
extends Node3D
## Ślady ostatniego najazdu w bazie: kupki nawozu przy obrońcach
## i ogryzki przy obgryzionych uprawach. Tylko wizualne, znikają
## w następnym cyklu (nie są zapisywane).

const FERTILIZER_COLOR := Color(0.36, 0.25, 0.16)
const CRUMB_COLOR := Color(0.85, 0.75, 0.45)


func show_raid(result: Dictionary) -> void:
	clear()
	var index := 0
	for pos: Vector3 in result.get("defender_hits", []):
		_pile(pos + _scatter(index, 0.9))
		index += 1
	for pos: Vector3 in result.get("bites", []):
		_crumbs(pos + _scatter(index, 0.25))
		index += 1


func clear() -> void:
	for child in get_children():
		child.queue_free()


## Stałe "losowe" przesunięcie, żeby kupki nie leżały jedna na drugiej.
static func _scatter(index: int, radius: float) -> Vector3:
	var angle := index * 2.399
	return Vector3(cos(angle), 0.0, sin(angle)) * radius * (0.6 + 0.4 * fposmod(index * 0.37, 1.0))


func _pile(pos: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = Vector3(pos.x, 0.0, pos.z)
	for i in 3:
		var lump := SphereMesh.new()
		lump.radius = 0.13 - i * 0.03
		lump.height = lump.radius * 1.3
		lump.radial_segments = 7
		lump.rings = 3
		var mesh := MeshInstance3D.new()
		mesh.mesh = lump
		mesh.position = Vector3(0, 0.05 + i * 0.08, 0)
		mesh.material_override = PlantVisuals.material(FERTILIZER_COLOR.lightened(i * 0.08))
		root.add_child(mesh)


func _crumbs(pos: Vector3) -> void:
	for i in 4:
		var bit := BoxMesh.new()
		bit.size = Vector3(0.06, 0.03, 0.04)
		var mesh := MeshInstance3D.new()
		mesh.mesh = bit
		add_child(mesh)
		var offset := _scatter(i + 7, 0.45)
		mesh.global_position = Vector3(pos.x + offset.x, 0.02, pos.z + offset.z)
		mesh.rotation.y = i * 1.3
		mesh.material_override = PlantVisuals.material(CRUMB_COLOR)
