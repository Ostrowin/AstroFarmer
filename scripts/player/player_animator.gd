class_name PlayerAnimator
extends Node
## Animacje modelu gracza (art/models/player.glb) sterowane stanem postaci.
##   Ruch: Idle / Run / Sprint / Jump / Dash (przejścia z krótkim przenikaniem).
##   Strzał: Shoot nakładany tylko na górę ciała (OneShot z filtrem kości),
##   więc można strzelać w biegu.

const LOOPED := [&"Idle", &"Run", &"Sprint"]
const STATES := [&"Idle", &"Run", &"Sprint", &"Jump", &"Dash"]
## Kości, na które działa animacja strzału.
const UPPER_BODY := [&"chest", &"clavicle.L", &"clavicle.R", &"upper_arm.L", &"upper_arm.R",
	&"forearm.L", &"forearm.R", &"hand.L", &"hand.R"]
const SKELETON_PATH := "PlayerRig/Skeleton3D"
## Prędkości, przy których animacje biegu grają z normalną szybkością.
const RUN_REFERENCE_SPEED := 5.0
const SPRINT_REFERENCE_SPEED := 8.5

var state: StringName = &"Idle"
var tree: AnimationTree

var _air_time := 0.0


## Buduje AnimationTree dla modelu. Zwraca false, jeśli model nie ma animacji.
func setup(model: Node) -> bool:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return false
	var animation_player := players[0] as AnimationPlayer
	for name in LOOPED:
		if animation_player.has_animation(name):
			animation_player.get_animation(name).loop_mode = Animation.LOOP_LINEAR

	var loco := AnimationNodeTransition.new()
	loco.xfade_time = 0.15
	var blend := AnimationNodeBlendTree.new()
	for i in STATES.size():
		loco.add_input(String(STATES[i]))
		var clip := AnimationNodeAnimation.new()
		clip.animation = STATES[i]
		blend.add_node(STATES[i], clip, Vector2(0, i * 120))
	blend.add_node(&"loco", loco, Vector2(300, 200))
	for i in STATES.size():
		blend.connect_node(&"loco", i, STATES[i])

	var speed := AnimationNodeTimeScale.new()
	blend.add_node(&"speed", speed, Vector2(500, 200))
	blend.connect_node(&"speed", 0, &"loco")

	var shoot := AnimationNodeOneShot.new()
	shoot.fadein_time = 0.03
	shoot.fadeout_time = 0.12
	shoot.filter_enabled = true
	for bone in UPPER_BODY:
		shoot.set_filter_path(NodePath("%s:%s" % [SKELETON_PATH, bone]), true)
	var shoot_clip := AnimationNodeAnimation.new()
	shoot_clip.animation = &"Shoot"
	blend.add_node(&"shoot_clip", shoot_clip, Vector2(500, 400))
	blend.add_node(&"shoot", shoot, Vector2(700, 200))
	blend.connect_node(&"shoot", 0, &"speed")
	blend.connect_node(&"shoot", 1, &"shoot_clip")
	blend.connect_node(&"output", 0, &"shoot")

	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	tree.tree_root = blend
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(animation_player)
	tree.active = true
	_set_state(&"Idle")
	return true


## Wywoływane co klatkę fizyki przez gracza.
func update(player: Player) -> void:
	if tree == null:
		return
	var horizontal := Vector2(player.velocity.x, player.velocity.z).length()
	var next := &"Idle"
	var playback := 1.0
	if player.is_dashing():
		next = &"Dash"
	elif not player.is_on_floor() and player.velocity.y > -20.0 and _airborne_long_enough(player):
		next = &"Jump"
	elif horizontal > 0.6:
		if player.sprinting:
			next = &"Sprint"
			playback = clampf(horizontal / SPRINT_REFERENCE_SPEED, 0.7, 1.5)
		else:
			next = &"Run"
			playback = clampf(horizontal / RUN_REFERENCE_SPEED, 0.6, 1.6)
	_set_state(next)
	tree.set("parameters/speed/scale", playback)


func shoot() -> void:
	if tree:
		tree.set("parameters/shoot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)



## Krótkie oderwania od ziemi (schodek, nierówność) nie włączają skoku.
func _airborne_long_enough(player: Player) -> bool:
	return _air_time > 0.12 or player.velocity.y > 1.0


func tick(delta: float, on_floor: bool) -> void:
	_air_time = 0.0 if on_floor else _air_time + delta


func _set_state(next: StringName) -> void:
	if next == state and tree.get("parameters/loco/current_state") == String(next):
		return
	state = next
	tree.set("parameters/loco/transition_request", String(next))
