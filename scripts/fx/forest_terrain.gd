class_name ForestTerrain
extends Node3D
## Nieregularny teren Grzybowego Lasu (wersja testowa), losowany przy każdej wyprawie:
##   - pagórki i grzbiety (szum), miejscami tarasy z uskokami (część da się wskoczyć, część nie),
##   - doły (zapadliska) ze stromymi ścianami i jedną rampą, którą da się wyjść,
##   - kręty kanion przez całą mapę: strome ściany, wejścia łagodnymi rampami na obu końcach,
##   - płaskie lądowisko (start i ewakuacja), na brzegach mapy wzgórza ginące we mgle.
## Kolizja: HeightMapShape3D (szybka), siatka z normalnymi z różnic wysokości.
##   - miejsca na jaskinie (bryły robi ForestCaves; tu tylko płaska podłoga pod nimi), pierwsza to Grota Zarodników,
##   - arena bossa (płaska niecka), do której grubieje grzybnia, i "serca" grzybni (puls fal w shaderze ziemi).

## Połowa boku obszaru gry (dalej teren rośnie w wysokie wzgórza i stoją ściany).
@export var half_size := 150.0
## Oczko siatki w metrach. Siatka ma zawsze 257 x 257 punktów (2^n + 1, dobre dla Jolt).
@export var cell := 2.0
## 0 = losowe ziarno przy każdej wyprawie.
@export var terrain_seed := 0
@export var hill_height := 9.0
@export var canyon_depth := 13.0
@export var canyon_floor_half := 6.0
@export var canyon_wall := 5.0
@export var pit_count := 7
## Lądowisko (start i ewakuacja): środek na płaszczyźnie XZ i promień płaskiego placu.
@export var pad_center := Vector2(0, 105)
@export var pad_radius := 9.0

const SAMPLES := 257
const BUCKET := 20.0

var canyon_points := PackedVector2Array()
## Doły: Vector4(x, z, promień, głębokość) + kąt rampy w `pit_ramps`.
var pits: Array[Vector4] = []
var pit_ramps: PackedFloat32Array = []
## Jaskinie: Vector4(x, z, promień, wysokość podłogi); kierunek wejścia (kąt w XZ) w `cave_facing`.
## Indeks 0 to Grota Zarodników (największa, pełna zarodników).
var caves: Array[Vector4] = []
var cave_facing: PackedFloat32Array = []
## Arena bossa: Vector4(x, z, promień, wysokość dna).
var arena := Vector4.ZERO
## Wioska Sporekinów (bezpieczna strefa): Vector4(x, z, promień, wysokość placu).
var village := Vector4.ZERO
## Słoneczna Polana (mini-biom, Rot Shepherd): Vector4(x, z, promień, wysokość).
var glade := Vector4.ZERO
## Serca grzybni: Vector4(x, z, zasięg, przesunięcie fazy pulsu).
var hearts: Array[Vector4] = []
var rng := RandomNumberGenerator.new()

var _hills := FastNoiseLite.new()
var _ridges := FastNoiseLite.new()
var _terrace := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _canyon_base := PackedFloat32Array()
var _canyon_cum := PackedFloat32Array()
var _canyon_length := 0.0
var _buckets: Dictionary = {}
var _pad_height := 0.0
## Wysokości węzłów siatki (po zbudowaniu): dokładna wysokość widocznej ziemi.
var _grid := PackedFloat32Array()


func _ready() -> void:
	_layout()
	var heights := _heights()
	_grid = heights
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = _build_mesh(heights)
	instance.material_override = _material()
	instance.set_meta("no_outline", true)
	add_child(instance)
	_build_collision(heights)
	_build_bounds()


# --- Układ (losowanie) ------------------------------------------------------

func _layout() -> void:
	if terrain_seed == 0:
		rng.randomize()
	else:
		rng.seed = terrain_seed
	var s := rng.randi()
	_hills.seed = s
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 0.011
	_hills.fractal_octaves = 4
	_ridges.seed = s + 1
	_ridges.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_ridges.frequency = 0.022
	_ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridges.fractal_octaves = 2
	_terrace.seed = s + 2
	_terrace.frequency = 0.008
	_detail.seed = s + 3
	_detail.frequency = 0.09
	_pad_height = _raw(pad_center.x, pad_center.y)
	_layout_canyon()
	_layout_pits()
	_layout_features()


## Kanion: krzywa z zachodu na wschód, z dala od lądowiska.
func _layout_canyon() -> void:
	var control: Array[Vector2] = []
	var span := half_size - 18.0
	var z_mid := rng.randf_range(-70.0, 30.0)
	for i in 6:
		var x := lerpf(-span, span, i / 5.0)
		var z := z_mid + rng.randf_range(-35.0, 35.0)
		z = minf(z, pad_center.y - 45.0)
		control.append(Vector2(x, z))
	canyon_points.clear()
	for i in control.size() - 1:
		var p0 := control[maxi(i - 1, 0)]
		var p1 := control[i]
		var p2 := control[i + 1]
		var p3 := control[mini(i + 2, control.size() - 1)]
		for k in 12:
			var t := k / 12.0
			canyon_points.append(_catmull(p0, p1, p2, p3, t))
	canyon_points.append(control[-1])
	_canyon_cum.resize(canyon_points.size())
	_canyon_cum[0] = 0.0
	for i in range(1, canyon_points.size()):
		_canyon_cum[i] = _canyon_cum[i - 1] + canyon_points[i].distance_to(canyon_points[i - 1])
	_canyon_length = _canyon_cum[-1]
	# Wysokość dna liczona od wygładzonego terenu wzdłuż kanionu (bez skoków).
	var raw := PackedFloat32Array()
	for p in canyon_points:
		raw.append(_raw(p.x, p.y))
	_canyon_base.resize(raw.size())
	for i in raw.size():
		var sum := 0.0
		var n := 0
		for j in range(maxi(i - 4, 0), mini(i + 5, raw.size())):
			sum += raw[j]
			n += 1
		_canyon_base[i] = sum / n
	# Kubełki odcinków po osi X (szybkie liczenie odległości od kanionu).
	_buckets.clear()
	# Zasięg z zapasem: odległość od kanionu służy też do omijania go przez doły i grzyby.
	var reach := canyon_floor_half + canyon_wall + 25.0
	for i in canyon_points.size() - 1:
		var a := canyon_points[i]
		var b := canyon_points[i + 1]
		var lo := int(floor((minf(a.x, b.x) - reach) / BUCKET))
		var hi := int(floor((maxf(a.x, b.x) + reach) / BUCKET))
		for k in range(lo, hi + 1):
			# Tablice spakowane są kopiowane przy odczycie ze słownika: dopisz i zapisz z powrotem.
			var list: PackedInt32Array = _buckets.get(k, PackedInt32Array())
			list.append(i)
			_buckets[k] = list


func _layout_pits() -> void:
	pits.clear()
	pit_ramps.clear()
	var tries := 0
	while pits.size() < pit_count and tries < 400:
		tries += 1
		var p := Vector2(rng.randf_range(-half_size + 25, half_size - 25), rng.randf_range(-half_size + 25, half_size - 25))
		var r := rng.randf_range(4.5, 8.0)
		if p.distance_to(pad_center) < pad_radius + r + 25.0:
			continue
		if canyon_info(p.x, p.y).x < canyon_floor_half + canyon_wall + r + 10.0:
			continue
		var ok := true
		for other in pits:
			if p.distance_to(Vector2(other.x, other.y)) < other.z + r + 20.0:
				ok = false
				break
		if not ok:
			continue
		pits.append(Vector4(p.x, p.y, r, rng.randf_range(5.0, 8.0)))
		pit_ramps.append(rng.randf_range(-PI, PI))


## Arena bossa, jaskinie i serca grzybni: z dala od lądowiska, kanionu, dołów i od siebie nawzajem.
func _layout_features() -> void:
	arena = Vector4.ZERO
	for attempt in 300:
		var p := Vector2(rng.randf_range(-half_size + 35, half_size - 35), rng.randf_range(-half_size + 35, half_size - 35))
		if p.distance_to(pad_center) < 120.0 or _blocked(p, 18.0 + 10.0):
			continue
		arena = Vector4(p.x, p.y, 18.0, _raw(p.x, p.y) - 1.5)
		break
	if arena == Vector4.ZERO:  # awaryjnie: naprzeciw lądowiska
		arena = Vector4(-pad_center.x, -pad_center.y * 0.8, 18.0, _raw(-pad_center.x, -pad_center.y * 0.8) - 1.5)
	village = Vector4.ZERO
	for attempt in 300:
		var p := Vector2(rng.randf_range(-half_size + 35, half_size - 35), rng.randf_range(-half_size + 35, half_size - 35))
		var dp := p.distance_to(pad_center)
		if dp < 45.0 or dp > 150.0 or _blocked(p, 20.0 + 14.0):
			continue
		if p.distance_to(Vector2(arena.x, arena.y)) < arena.z + 20.0 + 45.0:
			continue
		village = Vector4(p.x, p.y, 20.0, _raw(p.x, p.y))
		break
	glade = Vector4.ZERO
	for attempt in 300:
		var p := Vector2(rng.randf_range(-half_size + 35, half_size - 35), rng.randf_range(-half_size + 35, half_size - 35))
		if p.distance_to(pad_center) < 60.0 or _blocked(p, 16.0 + 14.0):
			continue
		if p.distance_to(Vector2(arena.x, arena.y)) < arena.z + 16.0 + 35.0:
			continue
		if village.z > 0.0 and p.distance_to(Vector2(village.x, village.y)) < village.z + 16.0 + 35.0:
			continue
		glade = Vector4(p.x, p.y, 16.0, _raw(p.x, p.y))
		break
	caves.clear()
	cave_facing.clear()
	for i in 3:
		var r := 15.0 if i == 0 else rng.randf_range(10.0, 12.0)
		for attempt in 800:
			var p := Vector2(rng.randf_range(-half_size + 30, half_size - 30), rng.randf_range(-half_size + 30, half_size - 30))
			if p.distance_to(pad_center) < 45.0 or _blocked(p, r + 22.0):  # z podjazdem (do r + 18)
				continue
			if p.distance_to(Vector2(arena.x, arena.y)) < arena.z + r + 25.0:
				continue
			if village.z > 0.0 and p.distance_to(Vector2(village.x, village.y)) < village.z + r + 25.0:
				continue
			if glade.z > 0.0 and p.distance_to(Vector2(glade.x, glade.y)) < glade.z + r + 25.0:
				continue
			var ok := true
			for c in caves:
				if p.distance_to(Vector2(c.x, c.y)) < c.z + r + 20.0:
					ok = false
			if not ok:
				continue
			caves.append(Vector4(p.x, p.y, r, _raw(p.x, p.y)))
			cave_facing.append(atan2(pad_center.y - p.y, pad_center.x - p.x) + rng.randf_range(-1.2, 1.2))
			break
	hearts.clear()
	hearts.append(Vector4(arena.x, arena.y, 40.0, 0.0))
	if not caves.is_empty():
		hearts.append(Vector4(caves[0].x, caves[0].y, caves[0].z, 2.0))
	for i in 12:
		var p := Vector2(rng.randf_range(-half_size + 15, half_size - 15), rng.randf_range(-half_size + 15, half_size - 15))
		hearts.append(Vector4(p.x, p.y, rng.randf_range(10.0, 16.0), rng.randf_range(0.0, 30.0)))


## Czy miejsce koliduje z lądowiskiem, kanionem albo dołami (promień r).
func _blocked(p: Vector2, r: float) -> bool:
	if canyon_info(p.x, p.y).x < canyon_floor_half + canyon_wall + r:
		return true
	for pit in pits:
		if p.distance_to(Vector2(pit.x, pit.y)) < pit.z + r + 6.0:
			return true
	return false


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


# --- Wysokość ----------------------------------------------------------------

## Teren bez lądowiska, dołów i kanionu: pagórki, grzbiety, tarasy.
func _raw(x: float, z: float) -> float:
	var h := _hills.get_noise_2d(x, z) * hill_height
	var ridge := _ridges.get_noise_2d(x, z) * 0.5 + 0.5
	h += ridge * ridge * 5.0
	# Tarasy tylko w części mapy: stopnie co 2,2 m ze stromym uskokiem.
	var k := smoothstep(0.15, 0.45, _terrace.get_noise_2d(x, z))
	if k > 0.0:
		var step := 2.2
		var f := h / step
		var q: float = (floorf(f) + smoothstep(0.7, 1.0, f - floorf(f))) * step
		h = lerpf(h, q, k * 0.9)
	return h


## Wysokość terenu w punkcie (x, z), z dołami, kanionem, lądowiskiem i brzegiem mapy.
func height_at(x: float, z: float) -> float:
	var h := _raw(x, z)
	# Lądowisko: płaski plac, łagodnie przechodzi w teren.
	var pd := Vector2(x, z).distance_to(pad_center)
	if pd < pad_radius + 14.0:
		h = lerpf(h, _pad_height, 1.0 - smoothstep(pad_radius, pad_radius + 14.0, pd))
	# Arena bossa: płaska niecka.
	if arena.z > 0.0:
		var ad := Vector2(x - arena.x, z - arena.y).length()
		if ad < arena.z + 14.0:
			h = lerpf(h, arena.w, 1.0 - smoothstep(arena.z * 0.85, arena.z + 14.0, ad))
	# Wioska: równy plac.
	if village.z > 0.0:
		var vd := Vector2(x - village.x, z - village.y).length()
		if vd < village.z + 12.0:
			h = lerpf(h, village.w, 1.0 - smoothstep(village.z, village.z + 12.0, vd))
	# Słoneczna Polana: równa łąka.
	if glade.z > 0.0:
		var gd := Vector2(x - glade.x, z - glade.y).length()
		if gd < glade.z + 10.0:
			h = lerpf(h, glade.w, 1.0 - smoothstep(glade.z * 0.8, glade.z + 10.0, gd))
	# Jaskinie: równa podłoga pod bryłą i płaski podjazd przed wejściem.
	for ci in caves.size():
		var c := caves[ci]
		var cd := Vector2(x - c.x, z - c.y).length()
		if cd < c.z + 8.0:
			h = lerpf(h, c.w, 1.0 - smoothstep(c.z + 1.0, c.z + 8.0, cd))
		if cd < c.z + 18.0 and ci < cave_facing.size():
			var da := absf(angle_difference(atan2(z - c.y, x - c.x), cave_facing[ci]))
			var sector := 1.0 - smoothstep(0.35, 0.7, da)
			h = lerpf(h, c.w, sector * (1.0 - smoothstep(c.z + 6.0, c.z + 18.0, cd)))
	# Doły ze stromymi ścianami i jedną rampą.
	for i in pits.size():
		var pit := pits[i]
		var d := Vector2(x - pit.x, z - pit.y).length()
		if d > pit.z * 2.6:
			continue
		var u := d / pit.z
		var profile := 1.0 - smoothstep(0.55, 1.0, u)
		var da := absf(angle_difference(atan2(z - pit.y, x - pit.x), pit_ramps[i]))
		var sector := 1.0 - smoothstep(0.22, 0.42, da)
		var ramp := 1.0 - clampf((u - 0.3) / 1.9, 0.0, 1.0)
		h -= pit.w * maxf(profile, sector * ramp)
	# Kanion.
	var info := canyon_info(x, z)
	var mask := 1.0 - smoothstep(canyon_floor_half, canyon_floor_half + canyon_wall, info.x)
	if mask > 0.0:
		var t := info.y / _canyon_length
		var ends := smoothstep(0.0, 0.13, t) * smoothstep(1.0, 0.87, t)
		var floor_h := info.z - canyon_depth * ends + _detail.get_noise_2d(x, z) * 0.25
		h = lerpf(h, minf(h, floor_h), mask)
	# Brzeg mapy: wysokie wzgórza (dalej i tak stoją ściany).
	var edge := maxf(absf(x), absf(z))
	if edge > half_size - 15.0:
		h += pow(smoothstep(half_size - 15.0, half_size + 45.0, edge), 1.5) * 45.0
	return h


## Punkt na widocznej ziemi (po zbudowaniu siatki: wysokość z jej trójkątów, jak kolizja).
func surface_point(x: float, z: float) -> Vector3:
	var y := mesh_height_at(x, z) if not _grid.is_empty() else height_at(x, z)
	return global_transform * Vector3(x, y, z)


## Wysokość na trójkątach siatki (ten sam podział co w _build_mesh: a-b-c i b-d-c).
func mesh_height_at(x: float, z: float) -> float:
	var ext := _extent()
	var fx := clampf((x + ext) / cell, 0.0, SAMPLES - 1.001)
	var fz := clampf((z + ext) / cell, 0.0, SAMPLES - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var u := fx - ix
	var v := fz - iz
	var a := _grid[iz * SAMPLES + ix]
	var b := _grid[iz * SAMPLES + ix + 1]
	var c := _grid[(iz + 1) * SAMPLES + ix]
	var d := _grid[(iz + 1) * SAMPLES + ix + 1]
	if u + v <= 1.0:
		return a + (b - a) * u + (c - a) * v
	return d + (c - d) * (1.0 - u) + (b - d) * (1.0 - v)


## Kierunek "od ściany" (w dół zbocza, poziomo) w punkcie (x, z).
func downhill(x: float, z: float) -> Vector3:
	var e := 1.0
	var dx := mesh_height_at(x + e, z) - mesh_height_at(x - e, z)
	var dz := mesh_height_at(x, z + e) - mesh_height_at(x, z - e)
	var d := Vector3(-dx, 0.0, -dz)
	return d.normalized() if d.length() > 0.001 else Vector3.FORWARD


## Miejsce na ścianie kanionu: idzie od osi w bok (side = +1 / -1), aż ściana sięgnie `above` m nad dno.
## Zwraca Transform3D: początek na ścianie, oś Z w stronę środka kanionu, Y w górę.
func canyon_wall_mount(t: float, side: float, above: float, base_y := INF) -> Transform3D:
	var floor_p := canyon_point(t)
	if base_y != INF:  # wysokość liczona od wspólnego poziomu (np. schody z półek)
		floor_p.y = base_y
	var target := clampf(t, 0.0, 1.0) * _canyon_length
	var dir := Vector2.RIGHT
	for i in canyon_points.size() - 1:
		if _canyon_cum[i + 1] >= target:
			dir = (canyon_points[i + 1] - canyon_points[i]).normalized()
			break
	var perp := Vector2(-dir.y, dir.x) * signf(side)
	var p := Vector2(floor_p.x, floor_p.z)
	var spot := Vector3(p.x, floor_p.y + above, p.y)
	for k in 80:
		var q := p + perp * (k * 0.25)
		if mesh_height_at(q.x, q.y) >= floor_p.y + above:
			spot = Vector3(q.x, floor_p.y + above, q.y)
			break
	var z := Vector3(-perp.x, 0.0, -perp.y)
	var basis := Basis(Vector3.UP.cross(z).normalized(), Vector3.UP, z)
	return Transform3D(basis, global_transform * spot)


## Odległość od osi kanionu (x), droga wzdłuż kanionu w m (y) i wysokość odniesienia dna (z).
func canyon_info(x: float, z: float) -> Vector3:
	var best := Vector3(INF, 0.0, 0.0)
	var key := int(floor(x / BUCKET))
	if not _buckets.has(key):
		return best
	var p := Vector2(x, z)
	for i: int in _buckets[key]:
		var a := canyon_points[i]
		var b := canyon_points[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best.x:
			best = Vector3(d, _canyon_cum[i] + ab.length() * t, lerpf(_canyon_base[i], _canyon_base[i + 1], t))
	return best


func canyon_length() -> float:
	return _canyon_length


## Punkt na dnie kanionu w ułamku drogi t (0..1), z przesunięciem w bok (m).
func canyon_point(t: float, side := 0.0) -> Vector3:
	var target := clampf(t, 0.0, 1.0) * _canyon_length
	for i in canyon_points.size() - 1:
		if _canyon_cum[i + 1] >= target:
			var seg := _canyon_cum[i + 1] - _canyon_cum[i]
			var k := (target - _canyon_cum[i]) / maxf(seg, 0.0001)
			var a := canyon_points[i]
			var b := canyon_points[i + 1]
			var dir := (b - a).normalized()
			var p := a.lerp(b, k) + Vector2(-dir.y, dir.x) * side
			return surface_point(p.x, p.y)
	var last := canyon_points[-1]
	return surface_point(last.x, last.y)


func in_canyon(x: float, z: float) -> bool:
	return canyon_info(x, z).x < canyon_floor_half + canyon_wall


func in_pit(x: float, z: float, margin := 0.0) -> bool:
	for pit in pits:
		if Vector2(x - pit.x, z - pit.y).length() < pit.z + margin:
			return true
	return false


## Nachylenie (0 = płasko, 1 = pion) z różnic wysokości.
func slope_at(x: float, z: float) -> float:
	var e := 0.8
	var dx := height_at(x + e, z) - height_at(x - e, z)
	var dz := height_at(x, z + e) - height_at(x, z - e)
	return 1.0 - Vector3(-dx, 2.0 * e, -dz).normalized().y


## Indeks jaskini, w której leży punkt (z zapasem `margin`), albo -1.
func cave_at(x: float, z: float, margin := 0.0) -> int:
	for i in caves.size():
		var c := caves[i]
		if Vector2(x - c.x, z - c.y).length() < c.z + margin:
			return i
	return -1


func in_village(x: float, z: float, margin := 0.0) -> bool:
	return village.z > 0.0 and Vector2(x - village.x, z - village.y).length() < village.z + margin


func village_point() -> Vector3:
	return surface_point(village.x, village.y)


func in_glade(x: float, z: float, margin := 0.0) -> bool:
	return glade.z > 0.0 and Vector2(x - glade.x, z - glade.y).length() < glade.z + margin


func glade_point() -> Vector3:
	return surface_point(glade.x, glade.y)


func in_arena(x: float, z: float, margin := 0.0) -> bool:
	return arena.z > 0.0 and Vector2(x - arena.x, z - arena.y).length() < arena.z + margin


func arena_point() -> Vector3:
	return surface_point(arena.x, arena.y)


## Punkt na ścianie: idzie od `start` w kierunku `dir`, aż teren sięgnie `base_y + above`.
## Zwraca Transform3D: początek na ścianie, oś Z z powrotem w stronę `start` (od ściany), Y w górę.
func wall_mount_along(start: Vector2, dir: Vector2, base_y: float, above: float, max_dist := 20.0) -> Transform3D:
	var d := dir.normalized()
	var spot := Vector3(start.x, base_y + above, start.y)
	var k := 0.0
	while k < max_dist:
		var q := start + d * k
		if mesh_height_at(q.x, q.y) >= base_y + above:
			spot = Vector3(q.x, base_y + above, q.y)
			break
		k += 0.25
	var z := Vector3(-d.x, 0.0, -d.y)
	return Transform3D(Basis(Vector3.UP.cross(z).normalized(), Vector3.UP, z), global_transform * spot)


## Losowy punkt w obszarze gry z dala od lądowiska (i opcjonalnie poza kanionem i dołami).
## Nigdy w jaskini ani na arenie bossa (tam rozkładają rzeczy osobne skrypty).
func random_point(r: RandomNumberGenerator, pad_clear := 14.0, avoid_canyon := true, avoid_pits := true) -> Vector3:
	var p := Vector2.ZERO
	for attempt in 40:
		p = Vector2(r.randf_range(-half_size + 12, half_size - 12), r.randf_range(-half_size + 12, half_size - 12))
		if p.distance_to(pad_center) < pad_radius + pad_clear:
			continue
		if avoid_canyon and canyon_info(p.x, p.y).x < canyon_floor_half + canyon_wall + 3.0:
			continue
		if avoid_pits and in_pit(p.x, p.y, 4.0):
			continue
		if cave_at(p.x, p.y, 7.0) >= 0 or in_arena(p.x, p.y, 2.0) or in_village(p.x, p.y, 2.0) or in_glade(p.x, p.y, 8.0):  # nic nie zastawia jaskiń i wioski
			continue
		break
	return surface_point(p.x, p.y)


func pad_point() -> Vector3:
	return surface_point(pad_center.x, pad_center.y)


# --- Siatka i kolizja ---------------------------------------------------------

func _extent() -> float:
	return (SAMPLES - 1) * cell * 0.5


func _heights() -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	heights.resize(SAMPLES * SAMPLES)
	var ext := _extent()
	for iz in SAMPLES:
		var z := -ext + iz * cell
		for ix in SAMPLES:
			heights[iz * SAMPLES + ix] = height_at(-ext + ix * cell, z)
	return heights


func _build_mesh(heights: PackedFloat32Array) -> ArrayMesh:
	var ext := _extent()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(SAMPLES * SAMPLES)
	normals.resize(SAMPLES * SAMPLES)
	for iz in SAMPLES:
		for ix in SAMPLES:
			var i := iz * SAMPLES + ix
			var hl := heights[iz * SAMPLES + maxi(ix - 1, 0)]
			var hr := heights[iz * SAMPLES + mini(ix + 1, SAMPLES - 1)]
			var hu := heights[maxi(iz - 1, 0) * SAMPLES + ix]
			var hd := heights[mini(iz + 1, SAMPLES - 1) * SAMPLES + ix]
			verts[i] = Vector3(-ext + ix * cell, heights[i], -ext + iz * cell)
			normals[i] = Vector3(-(hr - hl) / (2.0 * cell), 1.0, -(hd - hu) / (2.0 * cell)).normalized()
	var indices := PackedInt32Array()
	indices.resize((SAMPLES - 1) * (SAMPLES - 1) * 6)
	var n := 0
	for iz in SAMPLES - 1:
		for ix in SAMPLES - 1:
			var a := iz * SAMPLES + ix
			var b := a + 1
			var c := a + SAMPLES
			var d := c + 1
			indices[n] = a
			indices[n + 1] = b
			indices[n + 2] = c
			indices[n + 3] = b
			indices[n + 4] = d
			indices[n + 5] = c
			n += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Mapa wysokości ma odstęp 1 j., więc kształt jest skalowany o `cell` (równo we wszystkich osiach),
## a wysokości dzielone przez `cell`.
func _build_collision(heights: PackedFloat32Array) -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("terrain")
	add_child(body)
	var data := PackedFloat32Array()
	data.resize(heights.size())
	for i in heights.size():
		data[i] = heights[i] / cell
	var shape := HeightMapShape3D.new()
	shape.map_width = SAMPLES
	shape.map_depth = SAMPLES
	shape.map_data = data
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.scale = Vector3.ONE * cell
	body.add_child(collision)


func _build_bounds() -> void:
	var body := StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = 1
	add_child(body)
	var wall := half_size + 8.0
	for side in [Vector3(0, 0, wall), Vector3(0, 0, -wall), Vector3(wall, 0, 0), Vector3(-wall, 0, 0)]:
		var shape := BoxShape3D.new()
		shape.size = Vector3(wall * 2.0, 200.0, 1.0) if side.x == 0.0 else Vector3(1.0, 200.0, wall * 2.0)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = side
		body.add_child(collision)


func _material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://art/materials/forest_floor.gdshader")
	m.set_shader_parameter("noise_tex", preload("res://art/materials/ground_noise.tres"))
	var hv: Array[Vector4] = []
	for h in hearts:
		hv.append(h)
	while hv.size() < 16:
		hv.append(Vector4(0, 0, 0, 0))
	m.set_shader_parameter("hearts", hv.slice(0, 16))
	m.set_shader_parameter("heart_count", mini(hearts.size(), 16))
	m.set_shader_parameter("arena", arena)
	m.set_shader_parameter("glade", glade)
	var cv: Array[Vector4] = []
	for c in caves:
		cv.append(c)
	while cv.size() < 4:
		cv.append(Vector4(0, 0, 0, 0))
	m.set_shader_parameter("caves", cv.slice(0, 4))
	m.set_shader_parameter("cave_count", mini(caves.size(), 4))
	return m
