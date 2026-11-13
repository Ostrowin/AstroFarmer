class_name ExpeditionInteraction
extends Node
## Sterowanie na wyprawie (jak w Risk of Rain 2):
##   LPM: przedmiot z paska (1-2): pistolet (przytrzymaj = seria) albo jedzenie.
##   PPM: druga ręka, czyli rzucane nasiono (Snapper, Boomshroom); R zmienia.
##   E podnosi / je / nabiera wody / wzywa ewakuację, Q skanuje, Tab otwiera plecak.
## Akcje odkrywają fakty w bazie danych (GameState.learn).

signal prompt_changed(text: String, ok: bool)
signal hotbar_changed(index: int)
signal notify(text: String)
signal evac_requested
signal inventory_requested

const RAY_LENGTH := 40.0
const RAY_MASK := 1 | 4
const REACH := 3.0
const EVAC_REACH := 4.5
const SCAN_RANGE := 18.0
const PISTOL_RANGE := 30.0
const PISTOL_DAMAGE := 10.0
const PISTOL_INTERVAL := 0.28
## Pistolet Mk2 z warsztatu.
const PISTOL_DAMAGE_MK2 := 15.0
const PISTOL_INTERVAL_MK2 := 0.2
const THROW_RANGE := 12.0
const FOOD_HEAL := 30.0
const AWAKENING_COMMON := 2.0
const AWAKENING_RARE := 12.0
const THROWABLE_NAMES := {&"seed_snapper": "Snapper", &"seed_boomshroom": "Boomshroom"}

## Pasek pod LPM.
const SLOTS := [
	{"kind": "pistol"},
	{"kind": "food", "item": &"voidberry"},
]

var selected := 0

var _target := {}
var _shot_cooldown := 0.0
var _last_prompt := ""
var _outline := Outline.Tracker.new()

@onready var _player: Player = get_parent()


func _physics_process(delta: float) -> void:
	_shot_cooldown -= delta
	_update_target()
	# Seria z pistoletu przy przytrzymanym LPM.
	if SLOTS[selected]["kind"] == "pistol" and _can_act() and Input.is_action_pressed("use_tool") and _shot_cooldown <= 0.0:
		_fire()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and _player.input_enabled:
		get_viewport().set_input_as_handled()
		inventory_requested.emit()
		return
	if not _can_act():
		return
	for i in SLOTS.size():
		if event.is_action_pressed("slot_%d" % (i + 1)):
			select_slot(i)
			return
	if event.is_action_pressed("hotbar_next"):
		select_slot((selected + 1) % SLOTS.size())
	elif event.is_action_pressed("hotbar_prev"):
		select_slot((selected - 1 + SLOTS.size()) % SLOTS.size())
	elif event.is_action_pressed("use_tool") and SLOTS[selected]["kind"] == "food":
		_eat()
	elif event.is_action_pressed("use_offhand"):
		_throw()
	elif event.is_action_pressed("cycle_offhand"):
		_cycle_offhand()
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("scan"):
		_scan()


## Węzeł sceny wyprawy, do którego trafiają efekty, rzucone rośliny i wyrzucone rzeczy.
func _world() -> Node:
	return _player.get_parent()


func _can_act() -> bool:
	return _player.is_mouse_captured() and _player.input_enabled


func select_slot(index: int) -> void:
	selected = index
	hotbar_changed.emit(selected)


# --- Sloty dla HUD -----------------------------------------------------------

func slot_count() -> int:
	return SLOTS.size()


func slot_title(index: int) -> String:
	return "Pistol" + (" Mk2" if GameState.has_upgrade(&"pistol_mk2") else "") if SLOTS[index]["kind"] == "pistol" else "Voidberry"


func slot_detail(index: int) -> String:
	var slot: Dictionary = SLOTS[index]
	if slot["kind"] == "pistol":
		return "LMB"
	return "×%d" % _run_count(slot["item"])


func slot_color(index: int) -> Color:
	return Color(1, 0.9, 0.4) if SLOTS[index]["kind"] == "pistol" else Color(0.62, 0.3, 0.95)


## Opis drugiej ręki dla HUD.
func offhand_text() -> String:
	var run := GameState.run
	if run == null or run.offhand == &"":
		return "RMB\n—"
	return "RMB %s\n×%d" % [THROWABLE_NAMES.get(run.offhand, PlantCatalog.item_name(run.offhand)), run.count(run.offhand)]


func offhand_color() -> Color:
	var run := GameState.run
	if run == null or run.offhand == &"":
		return Color(0.5, 0.5, 0.6)
	return Color(0.9, 0.25, 0.3) if run.offhand == &"seed_snapper" else Color(1, 0.45, 0.2)


# --- Celowanie ---------------------------------------------------------------

func _update_target() -> void:
	var camera := _player.camera
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * RAY_LENGTH, RAY_MASK, [_player.get_rid()])
	_target = _player.get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Object = _target.get("collider")
	var scan_hint := _scan_hint(collider)
	var hint := ("  " + scan_hint) if scan_hint != "" else ""
	var highlight: Node = null
	var run := GameState.run
	var has_space := run != null and run.free_space() > 0

	if collider is Creature or collider is Critter:
		_set_prompt(String(collider.call("get_scan_info")["name"]) + hint, true)
	elif collider is MistySpring:
		if _in_reach(_target["position"], EVAC_REACH) and has_space:
			_set_prompt("[E] Collect water" + hint, true)
			highlight = collider as Node
		else:
			_set_prompt(("Backpack full" if not has_space else "") + hint, has_space)
	elif collider is Pickup:
		var pickup := collider as Pickup
		if not _in_reach(pickup.global_position):
			_set_prompt(pickup.display_name() + hint, true)
		elif pickup.kind == "artifact":
			_set_prompt("[E] %s" % pickup.display_name(), true)
			highlight = pickup
		elif not has_space:
			_set_prompt("Backpack full" + hint, false)
		else:
			_set_prompt("[E] %s ×%d%s" % [pickup.display_name(), pickup.amount, hint], true)
			highlight = pickup
	elif collider is WildBush:
		var bush := collider as WildBush
		if _in_reach(bush.global_position) and not bush.eaten:
			_set_prompt("[E] Eat" + hint, true)
			highlight = bush
		else:
			_set_prompt(hint.strip_edges(), true)
	elif collider is Node and (collider as Node).is_in_group("evac"):
		if _in_reach(_target["position"], EVAC_REACH):
			_set_prompt("[E] Evacuate", true)
			highlight = collider as Node
		else:
			_set_prompt("", true)
	elif SLOTS[selected]["kind"] == "food" and _run_count(&"voidberry") > 0 and _player.health < _player.max_health:
		_set_prompt("[LMB] Eat", true)
	else:
		_set_prompt("", true)
	_outline.set_target(highlight)


func _scan_hint(collider: Object) -> String:
	var info := _scan_info(collider)
	if info.is_empty():
		return ""
	var id: StringName = info["id"]
	if GameState.knows(id, "scan") if Codex.has_entry(id) else GameState.has_discovery(id):
		return ""
	return "[Q] Scan" if _distance_to(_target["position"]) <= SCAN_RANGE else ""


static func _scan_info(collider: Object) -> Dictionary:
	if collider == null or not collider.has_method("get_scan_info"):
		return {}
	return collider.call("get_scan_info")


func _in_reach(point: Vector3, reach := REACH) -> bool:
	return _distance_to(point) <= reach


func _distance_to(point: Vector3) -> float:
	var from := _player.global_position
	return Vector2(point.x - from.x, point.z - from.z).length()


func _run_count(item: StringName) -> int:
	return GameState.run.count(item) if GameState.run else 0


# --- Akcje -------------------------------------------------------------------

func _pistol_damage() -> float:
	return PISTOL_DAMAGE_MK2 if GameState.has_upgrade(&"pistol_mk2") else PISTOL_DAMAGE


func _pistol_interval() -> float:
	return PISTOL_INTERVAL_MK2 if GameState.has_upgrade(&"pistol_mk2") else PISTOL_INTERVAL


## Strzał z pistoletu: promień ze środka ekranu, smuga od lufy do celu.
func _fire() -> void:
	_shot_cooldown = _pistol_interval()
	_player.stop_sprint()
	_player.play_shoot()
	var camera := _player.camera
	var muzzle := _player.global_position + Vector3(0, 1.25, 0) + camera.global_basis.x * 0.35
	var to: Vector3 = _target.get("position", camera.global_position - camera.global_basis.z * PISTOL_RANGE)
	if muzzle.distance_to(to) > PISTOL_RANGE:
		to = muzzle + (to - muzzle).normalized() * PISTOL_RANGE
	Effects.beam(_world(), muzzle, to, Color(1, 0.9, 0.45, 0.9))
	Sfx.play(&"shot", muzzle)
	var collider: Object = _target.get("collider")
	if not (collider is Creature or collider is Critter):
		return
	if _distance_to((collider as Node3D).global_position) > PISTOL_RANGE:
		return
	Effects.burst(_world(), to, Color(1, 0.6, 0.3), 6)
	var id: StringName = collider.call("get_scan_info")["id"]
	GameState.learn(id, "hit")
	collider.call("take_hit", _pistol_damage(), _player.global_position)


func _eat() -> void:
	var run := GameState.run
	if run == null or _player.health >= _player.max_health:
		return
	if not run.remove_item(&"voidberry"):
		Sfx.play(&"deny")
		return
	_player.heal(FOOD_HEAL)
	GameState.learn(&"voidberry", "eat")
	Sfx.play(&"eat", _player.global_position)
	notify.emit("+%d health" % int(FOOD_HEAL))


## PPM: rzut tym, co jest w drugiej ręce.
func _throw() -> void:
	var run := GameState.run
	var collider: Object = _target.get("collider")
	if run == null or run.offhand == &"":
		Sfx.play(&"deny")
		notify.emit("Nothing to throw")
		return
	if collider == null or _distance_to(_target["position"]) > THROW_RANGE:
		Sfx.play(&"deny")
		notify.emit("Too far")
		return
	var item := run.offhand
	if not run.remove_item(item):
		Sfx.play(&"deny")
		return
	_player.stop_sprint()
	_player.play_shoot()
	var landing: Vector3 = _target["position"]
	var on_creature := collider is Creature or collider is Critter
	if on_creature:
		landing = Vector3((collider as Node3D).global_position.x, _player.global_position.y, (collider as Node3D).global_position.z)
	var plant: Node3D = TrapPlant.new() if item == &"seed_snapper" else BoomPlant.new()
	_world().add_child(plant)
	plant.global_position = landing
	Sfx.play(&"throw", _player.global_position)
	hotbar_changed.emit(selected)


func _cycle_offhand() -> void:
	var run := GameState.run
	if run == null:
		return
	if run.cycle_offhand() == &"":
		notify.emit("Nothing to throw")
	hotbar_changed.emit(selected)


func _interact() -> void:
	var collider: Object = _target.get("collider")
	var run := GameState.run
	if collider is Pickup:
		var pickup := collider as Pickup
		if not _in_reach(pickup.global_position) or run == null:
			return
		if pickup.kind == "artifact":
			_apply_buff(pickup.buff)
			Sfx.play(&"pickup", pickup.global_position)
			Effects.burst(_world(), pickup.global_position + Vector3(0, 0.5, 0), pickup.color)
			pickup.queue_free()
			return
		var added := run.add_item(pickup.item_id, pickup.amount)
		if added <= 0:
			Sfx.play(&"deny")
			notify.emit("Backpack full")
			return
		run.ensure_offhand()
		Sfx.play(&"pickup", pickup.global_position)
		Effects.fly_to(_world(), pickup.global_position + Vector3(0, 0.4, 0), _player, pickup.color)
		notify.emit("+%d %s" % [added, pickup.display_name()])
		if pickup.scan_id != &"":
			GameState.learn(pickup.scan_id, "pickup")
		if pickup.dropped:
			pass
		elif pickup.rare:
			run.add_awakening(AWAKENING_RARE)
			notify.emit("Awakening +%d" % int(AWAKENING_RARE))
		else:
			run.add_awakening(AWAKENING_COMMON)
		if added < pickup.amount:
			pickup.amount -= added
		else:
			pickup.queue_free()
		hotbar_changed.emit(selected)
	elif collider is WildBush:
		var bush := collider as WildBush
		if _in_reach(bush.global_position) and bush.eat():
			_player.heal(WildBush.HEAL)
			GameState.learn(&"voidberry", "eat")
			Sfx.play(&"eat", bush.global_position)
			notify.emit("+%d health" % int(WildBush.HEAL))
	elif collider is MistySpring and _in_reach(_target["position"], EVAC_REACH):
		if run == null or run.add_item(&"water_misty", 1) <= 0:
			Sfx.play(&"deny")
			notify.emit("Backpack full")
			return
		Sfx.play(&"fill", _target["position"])
		notify.emit("+1 Misty Water")
		GameState.learn(&"misty_spring", "pickup")
	elif collider is Node and (collider as Node).is_in_group("evac") and _in_reach(_target["position"], EVAC_REACH):
		evac_requested.emit()


## Wyrzuca przedmioty z plecaka na ziemię przed graczem (można je podnieść z powrotem).
func drop_item(id: StringName, amount: int) -> bool:
	var run := GameState.run
	if run == null or amount <= 0 or not run.remove_item(id, amount):
		return false
	var forward := Basis(Vector3.UP, _player.camera.global_rotation.y) * Vector3.FORWARD
	var pickup := Pickup.new()
	var entry := Pickup.entry_for(id, amount)
	entry["dropped"] = true
	pickup.setup(entry)
	_world().add_child(pickup)
	pickup.global_position = _player.global_position + forward * 1.4 + Vector3(randf_range(-0.3, 0.3), -_player.global_position.y, 0)
	Sfx.play(&"throw", _player.global_position)
	hotbar_changed.emit(selected)
	return true


func _scan() -> void:
	var collider: Object = _target.get("collider")
	var info := _scan_info(collider)
	if info.is_empty():
		return
	if _distance_to(_target["position"]) > SCAN_RANGE:
		notify.emit("Too far")
		return
	var id: StringName = info["id"]
	var is_new := not GameState.has_discovery(id)
	if GameState.learn(id, "scan") == "" and not GameState.add_discovery(id):
		return
	if GameState.run:
		GameState.run.discoveries.append(id)
		GameState.run.changed.emit()
	Sfx.play(&"scan", _target["position"])
	Effects.burst(_world(), _target["position"] + Vector3(0, 0.3, 0), Color(0.3, 0.95, 1.0), 16)
	if is_new and not Codex.has_entry(id):
		notify.emit("New: %s" % info["name"])


func _apply_buff(buff: Dictionary) -> void:
	match buff.get("id", ""):
		"speed":
			_player.speed_multiplier = 1.25
		"vitality":
			_player.add_max_health(25.0)
	if GameState.run:
		GameState.run.buffs.append(buff.get("name", ""))
		GameState.run.changed.emit()
	notify.emit("%s: %s" % [buff.get("name", ""), buff.get("desc", "")])


func _set_prompt(text: String, ok: bool) -> void:
	var key := "%s|%s" % [text, ok]
	if key == _last_prompt:
		return
	_last_prompt = key
	prompt_changed.emit(text, ok)
