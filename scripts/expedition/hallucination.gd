class_name Hallucination
extends Node
## Halucynacje od zarodników (Grzybowy Las). Ukryty licznik 0..1:
##   - rośnie w strefie mgły zarodników (Grota Zarodników) i od trafień Spore Ticka,
##   - sam opada poza mgłą,
##   - Spore Mask (ulepszenie "spore_mask") całkowicie chroni.
## Skutki na etapie 1 (do zrobienia bez maski; dalsze etapy podkręcą `stage`):
##   >= 0.3  obraz faluje, kolory płyną (nakładka na ekran),
##   >= 0.6  fałszywe znajdźki wokół gracza (migoczą fioletem, znikają przy podniesieniu),
##   >= 1.0  fantomowi przeciwnicy: fioletowi, półprzezroczyści, bez cienia, nie zadają obrażeń,
##           rozwiewają się po strzale.

signal changed(value: float)

const FOG_RATE := 0.11          # na sekundę w gęstej mgle (pełny licznik po ok. 9 s)
const DECAY := 0.06             # na sekundę poza mgłą
const TICK_DOSE := 0.25         # trafienie Spore Ticka
const FAKE_MAX := 4
const PHANTOM_MAX := 3

var value := 0.0
## Etap lasu (1 = do zrobienia bez maski). Wyższe etapy: szybszy przyrost, więcej fantomów.
var stage := 1
var fakes: Array[Node3D] = []
var phantoms: Array[Node3D] = []

var _player: Player
var _level: Node3D
var _overlay: ColorRect
var _spawn_t := 0.0


func setup(player: Player, level: Node3D, hud: CanvasLayer) -> void:
	_player = player
	_level = level
	_overlay = ColorRect.new()
	_overlay.name = "HallucinationOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = OVERLAY_SHADER
	m.shader = sh
	_overlay.material = m
	_overlay.visible = false
	hud.add_child(_overlay)
	hud.move_child(_overlay, 0)


func masked() -> bool:
	return GameState.has_upgrade(&"spore_mask")


func add(amount: float) -> void:
	if masked():
		return
	value = clampf(value + amount * (1.0 + 0.5 * (stage - 1)), 0.0, 1.0)
	changed.emit(value)


func in_fog() -> bool:
	if _player == null:
		return false
	for area in get_tree().get_nodes_in_group("spore_fog"):
		if (area as Area3D).overlaps_body(_player):
			return true
	return false


func _process(delta: float) -> void:
	if _player == null:
		return
	if in_fog() and not masked():
		add(FOG_RATE * delta)
	elif value > 0.0:
		value = maxf(0.0, value - DECAY * delta)
		changed.emit(value)
	if masked() and value > 0.0:
		value = 0.0
	_update_overlay()
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 1.5
		_manage_fakes()
		_manage_phantoms()


func _update_overlay() -> void:
	var k := clampf((value - 0.3) / 0.7, 0.0, 1.0)
	_overlay.visible = k > 0.0
	if k > 0.0:
		(_overlay.material as ShaderMaterial).set_shader_parameter("strength", k)


# --- Fałszywe znajdźki ------------------------------------------------------------

func _manage_fakes() -> void:
	fakes.assign(fakes.filter(func(f: Node3D) -> bool: return is_instance_valid(f)))
	if value < 0.6:
		for f in fakes:
			_vanish(f)
		fakes.clear()
		return
	while fakes.size() < FAKE_MAX:
		var p := _near_point(4.0, 12.0)
		var fake := Pickup.new()
		var entry := Pickup.entry_for([&"sample_glowmoss", &"crystal", &"starfall_shard"].pick_random(), 1)
		entry["phantom"] = true
		fake.setup(entry)
		_level.add_child(fake)
		fake.global_position = p
		_ghostify(fake)
		fakes.append(fake)


# --- Fantomowi przeciwnicy -------------------------------------------------------

func _manage_phantoms() -> void:
	phantoms.assign(phantoms.filter(func(f: Node3D) -> bool: return is_instance_valid(f)))
	if value < 0.999:
		for f in phantoms:
			_vanish(f)
		phantoms.clear()
		return
	var limit := PHANTOM_MAX + (stage - 1) * 2
	if phantoms.size() < limit:
		var ph: ForestCreature
		match randi() % 3:
			0:
				ph = Rotling.new()
			1:
				ph = SporeTick.new()
			_:
				ph = RotThornback.new()
		ph.phantom = true
		var p := _near_point(8.0, 14.0)
		_level.add_child(ph)
		ph.global_position = p + Vector3(0, 0.3, 0)
		_ghostify(ph)
		phantoms.append(ph)


func _near_point(rmin: float, rmax: float) -> Vector3:
	var o := _player.global_position
	var a := randf() * TAU
	var d := randf_range(rmin, rmax)
	var from := o + Vector3(cos(a) * d, 4.0, sin(a) * d)
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 12.0, 0), 1, [_player.get_rid()]))
	return hit["position"] if not hit.is_empty() else Vector3(from.x, o.y, from.z)


## Fioletowy, półprzezroczysty, migoczący i bez cienia (tak gracz może poznać fałszywkę).
static func _ghostify(node: Node) -> void:
	for mi in node.find_children("*", "GeometryInstance3D", true, false):
		var g := mi as GeometryInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.material_override = PHANTOM_MATERIAL
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).material_override = PHANTOM_MATERIAL


static func _vanish(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	if node.get_parent():
		Effects.burst(node.get_parent(), node.global_position + Vector3(0, 0.5, 0), Color(0.75, 0.45, 1.0), 10)
	node.queue_free()


static var PHANTOM_MATERIAL := _make_phantom()


static func _make_phantom() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
void fragment() {
	float flick = 0.55 + 0.45 * sin(TIME * 7.0 + FRAGCOORD.y * 0.05) * sin(TIME * 2.3);
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = vec3(0.6, 0.3, 1.0) * (0.25 + rim * 0.9) * flick;
}
"""
	m.shader = sh
	return m


const OVERLAY_SHADER := """
shader_type canvas_item;
uniform float strength = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	vec2 wob = vec2(sin(uv.y * 14.0 + t * 1.6), cos(uv.x * 11.0 + t * 1.3)) * 0.006 * strength;
	vec3 c;
	c.r = texture(screen_tex, uv + wob + vec2(0.004, 0.0) * strength).r;
	c.g = texture(screen_tex, uv + wob).g;
	c.b = texture(screen_tex, uv + wob - vec2(0.004, 0.0) * strength).b;
	// Kolory płyną: powolne przesunięcie odcienia ku fioletowi, ciemne brzegi.
	vec3 tint = vec3(0.85 + 0.15 * sin(t * 0.7), 0.75, 1.0 + 0.1 * cos(t * 0.5));
	float vig = smoothstep(0.9, 0.3, length(uv - 0.5));
	COLOR = vec4(mix(c, c * tint, strength * 0.6) * mix(1.0, vig, strength * 0.35), 1.0);
}
"""
