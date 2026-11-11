class_name ExpeditionInteraction
extends Node
## Sterowanie na wyprawie: ogłuszacz, rzucane nasiona Snappera, jedzenie,
## podnoszenie znajdziek (E), skanowanie (Q) i wezwanie ewakuacji.

signal prompt_changed(text: String, ok: bool)
signal hotbar_changed(index: int)
signal notify(text: String)
signal evac_requested

const RAY_LENGTH := 30.0
const RAY_MASK := 1 | 4
const REACH := 3.0
const EVAC_REACH := 4.5
const SCAN_RANGE := 18.0
const STUN_RANGE := 14.0
const STUN_COOLDOWN := 1.2
const STUN_SECONDS := 3.0
const THROW_RANGE := 12.0
const FOOD_HEAL := 30.0
const AWAKENING_COMMON := 2.0
const AWAKENING_RARE := 12.0

const SLOTS := [
	{"kind": "stunner"},
	{"kind": "trap", "item": &"seed_snapper"},
	{"kind": "food", "item": &"voidberry"},
]

var selected := 0

var _target := {}
var _stun_cooldown := 0.0
var _last_prompt := ""

@onready var _player: Player = get_parent()


func _physics_process(delta: float) -> void:
	_stun_cooldown -= delta
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
	elif event.is_action_pressed("scan"):
		_scan()


func select_slot(index: int) -> void:
	selected = index
	hotbar_changed.emit(selected)


# --- Sloty dla HUD -----------------------------------------------------------

func slot_count() -> int:
	return SLOTS.size()


func slot_title(index: int) -> String:
	match SLOTS[index]["kind"]:
		"stunner":
			return "Ogłuszacz"
		"trap":
			return "Snapper (rzut)"
		_:
			return "Voidberry (zjedz)"


func slot_detail(index: int) -> String:
	var slot: Dictionary = SLOTS[index]
	if slot["kind"] == "stunner":
		return "gotowy" if _stun_cooldown <= 0.0 else "ładuje się"
	return "w plecaku: %d" % _run_count(slot["item"])


func slot_color(index: int) -> Color:
	match SLOTS[index]["kind"]:
		"stunner":
			return Color(1, 0.9, 0.4)
		"trap":
			return Color(0.9, 0.25, 0.3)
		_:
			return Color(0.62, 0.3, 0.95)


# --- Celowanie ---------------------------------------------------------------

func _update_target() -> void:
	var camera := _player.camera
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * RAY_LENGTH, RAY_MASK, [_player.get_rid()])
	_target = _player.get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Object = _target.get("collider")
	var slot: Dictionary = SLOTS[selected]
	var scan_hint := _scan_hint(collider)

	if collider is Creature:
		var creature := collider as Creature
		var parts: Array[String] = []
		parts.append(String(creature.get_scan_info()["name"]))
		if slot["kind"] == "stunner" and _distance_to(creature.global_position) <= STUN_RANGE:
			parts.append("[LPM] Ogłusz")
		if scan_hint != "":
			parts.append(scan_hint)
		_set_prompt(" · ".join(parts), true)
		return
	if collider is Pickup:
		var pickup := collider as Pickup
		var text := ""
		if not _in_reach(pickup.global_position):
			text = "%s · podejdź bliżej" % pickup.display_name()
		elif pickup.kind == "artifact":
			text = "[E] Weź ulepszenie: %s" % pickup.display_name()
		elif GameState.run and GameState.run.free_space() <= 0:
			_set_prompt("Plecak pełny: %s" % pickup.display_name() + (" · " + scan_hint if scan_hint != "" else ""), false)
			return
		else:
			text = "[E] Podnieś: %s (+%d)%s" % [pickup.display_name(), pickup.amount, " · rzadkie!" if pickup.rare else ""]
		_set_prompt(text + (" · " + scan_hint if scan_hint != "" else ""), true)
		return
	if collider is WildBush:
		var bush := collider as WildBush
		var text := "Dziki krzew Voidberry"
		if _in_reach(bush.global_position):
			text = "Krzew ogołocony" if bush.eaten else "[E] Zjedz dziki owoc (+%d Kondycji)" % int(WildBush.HEAL)
		_set_prompt(text + (" · " + scan_hint if scan_hint != "" else ""), not bush.eaten)
		return
	if collider is Node and (collider as Node).is_in_group("evac"):
		if _in_reach(_target["position"], EVAC_REACH):
			_set_prompt("[E] Wezwij ewakuację (stój na lądowisku 5 s)", true)
		else:
			_set_prompt("Lądowisko: punkt ewakuacji", true)
		return

	match slot["kind"]:
		"trap":
			if _run_count(slot["item"]) <= 0:
				_set_prompt("Brak nasion Snappera w plecaku", false)
			elif collider == null or _distance_to(_target["position"]) > THROW_RANGE:
				_set_prompt("Za daleko na rzut (max %d m)" % int(THROW_RANGE), false)
			else:
				_set_prompt("[LPM] Rzuć nasiono Snappera: wyrośnie pułapka", true)
		"food":
			if _run_count(slot["item"]) <= 0:
				_set_prompt("Brak Voidberry w plecaku", false)
			elif _player.health >= _player.max_health:
				_set_prompt("Kondycja pełna", true)
			else:
				_set_prompt("[LPM] Zjedz Voidberry (+%d Kondycji)" % int(FOOD_HEAL), true)
		_:
			_set_prompt("Ogłuszacz · celuj w stworzenie" if _stun_cooldown <= 0.0 else "Ogłuszacz się ładuje...", true)


func _scan_hint(collider: Object) -> String:
	var info := _scan_info(collider)
	if info.is_empty() or GameState.has_discovery(info["id"]):
		return ""
	return "[Q] Skanuj" if _distance_to(_target["position"]) <= SCAN_RANGE else "za daleko na skan"


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

func _use_tool() -> void:
	var slot: Dictionary = SLOTS[selected]
	var collider: Object = _target.get("collider")
	var run := GameState.run
	match slot["kind"]:
		"stunner":
			if _stun_cooldown > 0.0:
				Sfx.play(&"deny")
				return
			_stun_cooldown = STUN_COOLDOWN
			var from := _player.global_position + Vector3(0, 1.2, 0)
			var to: Vector3 = _target.get("position", _player.camera.global_position - _player.camera.global_basis.z * STUN_RANGE)
			if from.distance_to(to) > STUN_RANGE:
				to = from + (to - from).normalized() * STUN_RANGE
			Effects.beam(get_tree().current_scene, from, to, Color(1, 0.95, 0.4, 0.9))
			Sfx.play(&"zap", from)
			hotbar_changed.emit(selected)
			get_tree().create_timer(STUN_COOLDOWN).timeout.connect(func() -> void: hotbar_changed.emit(selected))
			if collider is Creature and _distance_to((collider as Creature).global_position) <= STUN_RANGE:
				(collider as Creature).stun(STUN_SECONDS)
		"trap":
			if run == null or collider == null or collider is Creature or _distance_to(_target["position"]) > THROW_RANGE:
				Sfx.play(&"deny")
				return
			if not run.remove_item(slot["item"]):
				Sfx.play(&"deny")
				notify.emit("Brak nasion Snappera")
				return
			var trap := TrapPlant.new()
			get_tree().current_scene.add_child(trap)
			trap.global_position = _target["position"]
			Sfx.play(&"throw", _player.global_position)
		"food":
			if run == null or _player.health >= _player.max_health:
				return
			if not run.remove_item(slot["item"]):
				Sfx.play(&"deny")
				return
			_player.heal(FOOD_HEAL)
			Sfx.play(&"eat", _player.global_position)
			notify.emit("Zjedzono Voidberry (+%d Kondycji)" % int(FOOD_HEAL))


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
			Effects.burst(get_tree().current_scene, pickup.global_position + Vector3(0, 0.5, 0), pickup.color)
			pickup.queue_free()
			return
		var added := run.add_item(pickup.item_id, pickup.amount)
		if added <= 0:
			Sfx.play(&"deny")
			notify.emit("Plecak pełny. Zjedz coś albo wracaj na lądowisko.")
			return
		Sfx.play(&"pickup", pickup.global_position)
		Effects.fly_to(get_tree().current_scene, pickup.global_position + Vector3(0, 0.4, 0), _player, pickup.color)
		notify.emit("+%d %s" % [added, pickup.display_name()])
		if pickup.rare:
			run.add_awakening(AWAKENING_RARE)
			notify.emit("Coś rzadkiego... Przebudzenie rośnie szybciej (+%d)" % int(AWAKENING_RARE))
		else:
			run.add_awakening(AWAKENING_COMMON)
		if added < pickup.amount:
			pickup.amount -= added
			notify.emit("Zmieściło się tylko %d" % added)
		else:
			pickup.queue_free()
	elif collider is WildBush:
		var bush := collider as WildBush
		if _in_reach(bush.global_position) and bush.eat():
			_player.heal(WildBush.HEAL)
			Sfx.play(&"eat", bush.global_position)
			notify.emit("Dziki owoc: +%d Kondycji" % int(WildBush.HEAL))
	elif collider is Node and (collider as Node).is_in_group("evac") and _in_reach(_target["position"], EVAC_REACH):
		evac_requested.emit()


func _scan() -> void:
	var collider: Object = _target.get("collider")
	var info := _scan_info(collider)
	if info.is_empty():
		return
	if _distance_to(_target["position"]) > SCAN_RANGE:
		notify.emit("Za daleko na skan (max %d m)" % int(SCAN_RANGE))
		return
	var id: StringName = info["id"]
	if not GameState.add_discovery(id):
		notify.emit("Już w bazie danych: %s" % info["name"])
		return
	if GameState.run:
		GameState.run.discoveries.append(id)
		GameState.run.changed.emit()
	Sfx.play(&"scan", _target["position"])
	Effects.burst(get_tree().current_scene, _target["position"] + Vector3(0, 0.3, 0), Color(0.3, 0.95, 1.0), 16)
	notify.emit("Nowe odkrycie: %s (zostaje nawet po porażce)" % info["name"])


func _apply_buff(buff: Dictionary) -> void:
	match buff.get("id", ""):
		"speed":
			_player.speed_multiplier = 1.25
		"vitality":
			_player.add_max_health(25.0)
	if GameState.run:
		GameState.run.buffs.append(buff.get("name", ""))
		GameState.run.changed.emit()
	notify.emit("Ulepszenie wyprawy: %s (%s)" % [buff.get("name", ""), buff.get("desc", "")])


func _set_prompt(text: String, ok: bool) -> void:
	var key := "%s|%s" % [text, ok]
	if key == _last_prompt:
		return
	_last_prompt = key
	prompt_changed.emit(text, ok)
