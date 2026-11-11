class_name PlayerInteraction
extends Node
## Celowanie środkiem ekranu, pasek narzędzi (nasiona, konewka),
## podgląd sadzenia z powodem odmowy, podlewanie, zbiór i drzwi wyprawy.

signal prompt_changed(text: String, ok: bool)
signal hotbar_changed(index: int)
signal notify(text: String)
signal gate_used

const RAY_LENGTH := 12.0
## Warstwy: 1 world + 3 plants.
const RAY_MASK := 1 | 4

## Pasek narzędzi. "seed" sadzi gatunek, "can" to konewka.
const SLOTS := [
	{"kind": "seed", "plant": &"voidberry"},
	{"kind": "seed", "plant": &"crystal_bloom"},
	{"kind": "seed", "plant": &"snapper"},
	{"kind": "can"},
]

var farm: Farm
var selected := 0

var _target := {}
var _ghost: Node3D
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
	if slot["kind"] == "seed":
		return PlantCatalog.get_plant(slot["plant"]).display_name
	return "Konewka"


func slot_detail(index: int) -> String:
	var slot: Dictionary = SLOTS[index]
	if slot["kind"] == "seed":
		var data := PlantCatalog.get_plant(slot["plant"])
		return "nasiona: %d" % GameState.get_resource(data.seed_item())
	return "woda: %d/%d" % [GameState.get_resource(&"water"), GameState.WATER_CAPACITY]


func slot_color(index: int) -> Color:
	var slot: Dictionary = SLOTS[index]
	if slot["kind"] == "seed":
		return PlantCatalog.get_plant(slot["plant"]).accent_color
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

	var collider: Object = _target.get("collider")
	var slot: Dictionary = SLOTS[selected]
	if collider is Plant:
		var plant := collider as Plant
		if not _in_reach(plant.global_position):
			_set_prompt("%s · podejdź bliżej" % plant.data.display_name, false)
		elif plant.is_ripe():
			_set_prompt("[E] Zbierz: %s" % plant.data.display_name, true)
		elif slot["kind"] == "can" and plant.is_thirsty():
			if GameState.get_resource(&"water") > 0:
				_set_prompt("[LPM] Podlej · %s" % plant.status_text(), true)
			else:
				_set_prompt("Konewka pusta: napełnij w stawie", false)
		else:
			_set_prompt(plant.status_text(), true)
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
		elif GameState.get_resource(&"water") >= GameState.WATER_CAPACITY:
			_set_prompt("Konewka pełna", true)
		else:
			_set_prompt("[LPM] Napełnij konewkę", true)
		return
	if slot["kind"] == "seed" and collider != null:
		var data := PlantCatalog.get_plant(slot["plant"])
		var problem := farm.placement_problem(data, _target["position"], _target["normal"], collider, _player.global_position)
		_ghost.visible = true
		_ghost.global_position = _target["position"]
		_set_ghost_ok(problem == "")
		if problem == "":
			_set_prompt("[LPM] Posadź: %s" % data.display_name, true)
		else:
			_set_prompt(problem, false)
		return
	if slot["kind"] == "can":
		_set_prompt("Konewka · celuj w spragnioną roślinę albo w staw", true)
		return
	_set_prompt("", true)


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

	# Konewka
	if collider is Plant:
		var plant := collider as Plant
		if not _in_reach(plant.global_position) or not plant.is_thirsty():
			return
		if not GameState.spend_resource(&"water", 1):
			Sfx.play(&"deny")
			notify.emit("Konewka pusta: napełnij w stawie")
			return
		plant.water()
		farm.changed.emit()
		Sfx.play(&"water", plant.global_position)
		Effects.burst(farm, plant.global_position + Vector3(0, 0.6, 0), Color(0.35, 0.7, 1.0), 14)
	elif collider is Node and (collider as Node).is_in_group("water") and _in_reach(_target["position"]):
		var missing := GameState.WATER_CAPACITY - GameState.get_resource(&"water")
		if missing > 0:
			GameState.add_resource(&"water", missing)
			Sfx.play(&"fill", _target["position"])
			notify.emit("Konewka napełniona (%d/%d)" % [GameState.WATER_CAPACITY, GameState.WATER_CAPACITY])


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
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.4
	ring_mesh.bottom_radius = 0.4
	ring_mesh.height = 0.03
	ring_mesh.radial_segments = 16
	ring.mesh = ring_mesh
	ring.position.y = 0.02
	_ghost.add_child(ring)
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
