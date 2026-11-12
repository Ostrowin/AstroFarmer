class_name PlayerInteraction
extends Node
## Celowanie środkiem ekranu, pasek narzędzi (nasiona, konewka, nawóz, płot),
## podgląd sadzenia z powodem odmowy, podlewanie, zbiór, warsztat i drzwi wyprawy.

signal prompt_changed(text: String, ok: bool)
signal hotbar_changed(index: int)
signal notify(text: String)
signal gate_used
signal workbench_used
signal codex_used

const RAY_LENGTH := 12.0
## Warstwy: 1 world + 3 plants.
const RAY_MASK := 1 | 4

## Pasek narzędzi. "seed" sadzi gatunek, "can" to konewka,
## "fertilizer" przyspiesza wzrost, "fence" stawia słupek płotu.
const SLOTS := [
	{"kind": "seed", "plant": &"voidberry"},
	{"kind": "seed", "plant": &"crystal_bloom"},
	{"kind": "seed", "plant": &"snapper"},
	{"kind": "seed", "plant": &"boomshroom"},
	{"kind": "seed", "plant": &"mistbloom"},
	{"kind": "can"},
	{"kind": "fertilizer"},
	{"kind": "fence"},
]

var farm: Farm
var selected := 0

var _target := {}
var _ghost: Node3D
var _grid: MeshInstance3D
var _grid_cell := Vector2i(999999, 999999)
var _ghost_ok: StandardMaterial3D
var _ghost_bad: StandardMaterial3D
var _last_prompt := ""

@onready var _player: Player = get_parent()


func _ready() -> void:
	_build_ghost()


func _physics_process(_delta: float) -> void:
	_update_target()


func _unhandled_input(event: InputEvent) -> void:
	if not _player.is_mouse_captured() or not _player.input_enabled:
		return
	for i in SLOTS.size():
		if event.is_action_pressed("slot_%d" % (i + 1)):
			select_slot(i)
			return
	if event.is_action_pressed("hotbar_next"):
		select_slot((selected + 1) % SLOTS.size())
	elif event.is_action_pressed("hotbar_prev"):
		select_slot((selected - 1 + SLOTS.size()) % SLOTS.size())
	elif event.is_action_pressed("use_tool"):
		_use_tool()
	elif event.is_action_pressed("interact"):
		_interact()


func select_slot(index: int) -> void:
	selected = index
	hotbar_changed.emit(selected)


# --- Opisy slotów dla HUD ----------------------------------------------------

func slot_count() -> int:
	return SLOTS.size()


func slot_title(index: int) -> String:
	var slot: Dictionary = SLOTS[index]
	match slot["kind"]:
		"seed":
			return PlantCatalog.get_plant(slot["plant"]).display_name
		"fertilizer":
			return "Nawóz"
		"fence":
			return "Płot"
	return "Konewka"


func slot_detail(index: int) -> String:
	var slot: Dictionary = SLOTS[index]
	match slot["kind"]:
		"seed":
			var data := PlantCatalog.get_plant(slot["plant"])
			return "nasiona: %d" % GameState.get_resource(data.seed_item())
		"fertilizer":
			return "porcje: %d" % GameState.get_resource(&"fertilizer")
		"fence":
			return "słupki: %d" % GameState.get_resource(&"fence_post")
	return "woda: %d/%d" % [GameState.get_resource(&"water"), GameState.water_capacity()]


func slot_color(index: int) -> Color:
	var slot: Dictionary = SLOTS[index]
	match slot["kind"]:
		"seed":
			return PlantCatalog.get_plant(slot["plant"]).accent_color
		"fertilizer":
			return RaidMarks.FERTILIZER_COLOR.lightened(0.3)
		"fence":
			return FencePost.WOOD
	return Color(0.35, 0.7, 1.0)


# --- Celowanie ---------------------------------------------------------------

func _update_target() -> void:
	if farm == null:
		return
	var camera := _player.camera
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * RAY_LENGTH, RAY_MASK, [_player.get_rid()])
	_target = _player.get_world_3d().direct_space_state.intersect_ray(query)
	_ghost.visible = false
	_grid.visible = false

	var collider: Object = _target.get("collider")
	var slot: Dictionary = SLOTS[selected]
	if collider is Plant:
		var plant := collider as Plant
		if not _in_reach(plant.global_position):
			_set_prompt("%s · podejdź bliżej" % plant.data.display_name, false)
		elif plant.is_ripe():
			_set_prompt("[E] Zbierz: %s" % plant.data.display_name, true)
		elif slot["kind"] == "can" and plant.is_thirsty() and plant.needs_sprout_item():
			var have := GameState.get_resource(plant.data.sprout_item)
			if have > 0:
				_set_prompt("[LPM] Podlej wodą z Mglistego źródła (masz %d) · %s" % [have, plant.status_text()], true)
			else:
				_set_prompt("%s · brak wody z Mglistego źródła (poziom 2 łąki)" % plant.status_text(), false)
		elif slot["kind"] == "can" and plant.is_thirsty():
			if GameState.get_resource(&"water") > 0:
				_set_prompt("[LPM] Podlej · %s" % plant.status_text(), true)
			else:
				_set_prompt("Konewka pusta: napełnij w stawie", false)
		elif slot["kind"] == "fertilizer":
			if GameState.get_resource(&"fertilizer") > 0:
				_set_prompt("[LPM] Nawóź: +1 cykl wzrostu od razu · %s" % plant.status_text(), true)
			else:
				_set_prompt("Brak nawozu: zostawiają go przegonione Chrupiki", false)
		else:
			_set_prompt(plant.status_text(), true)
		return
	if collider is FencePost:
		var post := collider as FencePost
		_set_prompt(post.get_status() if _in_reach(post.global_position) else "Słupek płotu · podejdź bliżej", true)
		return
	if collider is Node and (collider as Node).is_in_group("codex"):
		if _in_reach(_target["position"], 4.5):
			_set_prompt("[E] Komputer w chatce: baza danych (%d%%)" % Codex.completion(GameState.research, GameState.max_level()), true)
		else:
			_set_prompt("Chatka", true)
		return
	if collider is Node and (collider as Node).is_in_group("workbench"):
		if _in_reach(_target["position"], 4.0):
			_set_prompt("[E] Warsztat: ulepszenia i płot", true)
		else:
			_set_prompt("Warsztat", true)
		return
	if collider is Node and (collider as Node).is_in_group("gate"):
		if _in_reach(_target["position"], 5.0):
			_set_prompt("[E] Drzwi wyprawy: przygotowanie", true)
		else:
			_set_prompt("Drzwi wyprawy", true)
		return
	if collider is Node and (collider as Node).is_in_group("water") and slot["kind"] == "can":
		if not _in_reach(_target["position"]):
			_set_prompt("Staw · podejdź bliżej", false)
		elif GameState.get_resource(&"water") >= GameState.water_capacity():
			_set_prompt("Konewka pełna", true)
		else:
			_set_prompt("[LPM] Napełnij konewkę", true)
		return
	if slot["kind"] == "seed" and collider != null:
		var data := PlantCatalog.get_plant(slot["plant"])
		var problem := farm.placement_problem(data, _target["position"], _target["normal"], collider, _player.global_position)
		_show_ghost(_target["position"], problem == "")
		if problem == "":
			_set_prompt("[LPM] Posadź: %s" % data.display_name, true)
		else:
			_set_prompt(problem, false)
		return
	if slot["kind"] == "fence" and collider != null:
		var problem := farm.post_problem(_target["position"], _target["normal"], collider, _player.global_position)
		_show_ghost(_target["position"], problem == "")
		_set_prompt("[LPM] Postaw słupek płotu" if problem == "" else problem, problem == "")
		return
	match slot["kind"]:
		"can":
			_set_prompt("Konewka · celuj w spragnioną roślinę albo w staw", true)
			return
		"fertilizer":
			_set_prompt("Nawóz · celuj w rosnącą roślinę", true)
			return
	_set_prompt("", true)


## Podgląd na siatce: zielone/czerwone pole + kratki dookoła.
func _show_ghost(point: Vector3, ok: bool) -> void:
	var snapped := Farm.snap(point)
	_ghost.visible = true
	_ghost.global_position = snapped
	_set_ghost_ok(ok)
	_grid.visible = true
	var cell := Farm.cell_of(point)
	if cell != _grid_cell:
		_grid_cell = cell
		_rebuild_grid(cell, point.y)


func _rebuild_grid(center: Vector2i, y: float) -> void:
	const RADIUS := 3
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var lo := Farm.cell_center(center - Vector2i(RADIUS, RADIUS)) - Vector3(Farm.CELL, 0, Farm.CELL) * 0.5
	var size := (RADIUS * 2 + 1) * Farm.CELL
	var h := y + 0.03
	for i in RADIUS * 2 + 2:
		var offset := i * Farm.CELL
		mesh.surface_add_vertex(Vector3(lo.x + offset, h, lo.z))
		mesh.surface_add_vertex(Vector3(lo.x + offset, h, lo.z + size))
		mesh.surface_add_vertex(Vector3(lo.x, h, lo.z + offset))
		mesh.surface_add_vertex(Vector3(lo.x + size, h, lo.z + offset))
	mesh.surface_end()
	_grid.mesh = mesh


func _in_reach(point: Vector3, reach := Farm.REACH) -> bool:
	var from := _player.global_position
	return Vector2(point.x - from.x, point.z - from.z).length() <= reach


# --- Akcje -------------------------------------------------------------------

func _use_tool() -> void:
	var collider: Object = _target.get("collider")
	var slot: Dictionary = SLOTS[selected]
	if slot["kind"] == "seed":
		if collider == null or collider is Plant:
			return
		var data := PlantCatalog.get_plant(slot["plant"])
		var point: Vector3 = _target["position"]
		var problem := farm.placement_problem(data, point, _target["normal"], collider, _player.global_position)
		if problem != "":
			Sfx.play(&"deny")
			notify.emit(problem)
			return
		farm.plant_seed(data, point)
		Sfx.play(&"plant", point)
		Effects.burst(farm, point + Vector3(0, 0.1, 0), Color(0.55, 0.42, 0.3), 10)
		return
	if slot["kind"] == "fence":
		if collider == null or collider is Plant or collider is FencePost:
			return
		var problem := farm.post_problem(_target["position"], _target["normal"], collider, _player.global_position)
		if problem != "":
			Sfx.play(&"deny")
			notify.emit(problem)
			return
		farm.place_post(_target["position"])
		Sfx.play(&"craft", _target["position"])
		Effects.burst(farm, _target["position"] + Vector3(0, 0.1, 0), FencePost.WOOD, 10)
		return
	if slot["kind"] == "fertilizer":
		if not (collider is Plant) or not _in_reach((collider as Plant).global_position):
			return
		var target := collider as Plant
		if target.is_ripe():
			return
		if not farm.fertilize(target):
			Sfx.play(&"deny")
			notify.emit("Brak nawozu")
			return
		Sfx.play(&"plant", target.global_position)
		Effects.burst(farm, target.global_position + Vector3(0, 0.3, 0), RaidMarks.FERTILIZER_COLOR.lightened(0.3), 16)
		notify.emit("Nawóz: %s rośnie szybciej (i chętniej mutuje)" % target.data.display_name)
		return

	# Konewka
	if collider is Plant:
		var plant := collider as Plant
		if not _in_reach(plant.global_position) or not plant.is_thirsty():
			return
		var problem := farm.water_plant(plant)
		if problem != "":
			Sfx.play(&"deny")
			notify.emit(problem)
			return
		Sfx.play(&"water", plant.global_position)
		Effects.burst(farm, plant.global_position + Vector3(0, 0.6, 0), Color(0.35, 0.7, 1.0), 14)
	elif collider is Node and (collider as Node).is_in_group("water") and _in_reach(_target["position"]):
		var missing := GameState.water_capacity() - GameState.get_resource(&"water")
		if missing > 0:
			GameState.add_resource(&"water", missing)
			Sfx.play(&"fill", _target["position"])
			notify.emit("Konewka napełniona (%d/%d)" % [GameState.water_capacity(), GameState.water_capacity()])


func _interact() -> void:
	var collider: Object = _target.get("collider")
	if collider is Plant:
		var plant := collider as Plant
		if not plant.is_ripe() or not _in_reach(plant.global_position):
			return
		var pos := plant.global_position
		var color := plant.data.accent_color
		var gained := farm.harvest(plant)
		Sfx.play(&"harvest", pos)
		Effects.burst(farm, pos + Vector3(0, 0.5, 0), color)
		var delay := 0.0
		for item in gained:
			for i in mini(gained[item], 4):
				Effects.fly_to(farm, pos + Vector3(0, 0.5, 0), _player, color, delay)
				delay += 0.06
		notify.emit(_describe_gain(gained))
	elif collider is FencePost and _in_reach((collider as FencePost).global_position):
		farm.remove_post(collider as FencePost)
		Sfx.play(&"pickup", _player.global_position)
		notify.emit("Słupek wrócił do magazynu")
	elif collider is Node and (collider as Node).is_in_group("workbench") and _in_reach(_target["position"], 4.0):
		workbench_used.emit()
	elif collider is Node and (collider as Node).is_in_group("codex") and _in_reach(_target["position"], 4.5):
		codex_used.emit()
	elif collider is Node and (collider as Node).is_in_group("gate") and _in_reach(_target["position"], 5.0):
		gate_used.emit()


static func _describe_gain(gained: Dictionary) -> String:
	var parts: Array[String] = []
	for item in gained:
		parts.append("+%d %s" % [gained[item], PlantCatalog.item_name(item)])
	return ", ".join(parts)


# --- Podgląd sadzenia --------------------------------------------------------

func _build_ghost() -> void:
	_ghost_ok = _ghost_material(Color(0.4, 1.0, 0.5, 0.45))
	_ghost_bad = _ghost_material(Color(1.0, 0.35, 0.3, 0.45))
	_ghost = Node3D.new()
	_ghost.top_level = true
	var tile := MeshInstance3D.new()
	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(Farm.CELL * 0.94, 0.03, Farm.CELL * 0.94)
	tile.mesh = tile_mesh
	tile.position.y = 0.02
	_ghost.add_child(tile)
	var sprout := MeshInstance3D.new()
	var sprout_mesh := CylinderMesh.new()
	sprout_mesh.top_radius = 0.0
	sprout_mesh.bottom_radius = 0.08
	sprout_mesh.height = 0.35
	sprout_mesh.radial_segments = 5
	sprout.mesh = sprout_mesh
	sprout.position.y = 0.2
	_ghost.add_child(sprout)
	add_child(_ghost)
	_set_ghost_ok(true)
	_grid = MeshInstance3D.new()
	_grid.top_level = true
	var grid_material := StandardMaterial3D.new()
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_material.albedo_color = Color(1, 1, 1, 0.35)
	_grid.material_override = grid_material
	add_child(_grid)


func _ghost_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat


func _set_ghost_ok(ok: bool) -> void:
	for child in _ghost.get_children():
		(child as MeshInstance3D).material_override = _ghost_ok if ok else _ghost_bad


func _set_prompt(text: String, ok: bool) -> void:
	var key := "%s|%s" % [text, ok]
	if key == _last_prompt:
		return
	_last_prompt = key
	prompt_changed.emit(text, ok)
