class_name ScatterGrid
extends RefCounted
## Siatka przestrzenna dla rozsiewania obiektów po dużej mapie: "czy w promieniu r
## od punktu coś już stoi?" sprawdza tylko sąsiednie komórki zamiast całej listy.
## Punkty to koła na płaszczyźnie XZ: (x, z, promień zajęcia).

var _cell: float
var _cells := {}
var _max_radius := 0.0


func _init(cell_size := 8.0) -> void:
	_cell = cell_size


func add(x: float, z: float, radius: float) -> void:
	var key := Vector2i(floori(x / _cell), floori(z / _cell))
	# Packed*Array to typ wartościowy: odczyt ze słownika daje kopię, więc zapisujemy z powrotem.
	var points: PackedVector3Array = _cells.get(key, PackedVector3Array())
	points.append(Vector3(x, z, radius))
	_cells[key] = points
	_max_radius = maxf(_max_radius, radius)


## Czy koło (x, z, radius) nie nachodzi na żadne zapisane (odstęp = suma promieni,
## albo `min_gap`, jeśli większy).
func is_free(x: float, z: float, radius := 0.0, min_gap := 0.0) -> bool:
	var reach := maxf(radius + _max_radius, min_gap)
	var span := int(ceil(reach / _cell))
	var cx := floori(x / _cell)
	var cz := floori(z / _cell)
	for gx in range(cx - span, cx + span + 1):
		for gz in range(cz - span, cz + span + 1):
			var key := Vector2i(gx, gz)
			if not _cells.has(key):
				continue
			for p: Vector3 in _cells[key]:
				var need := maxf(radius + p.z, min_gap)
				var dx := x - p.x
				var dz := z - p.y
				if dx * dx + dz * dz < need * need:
					return false
	return true
