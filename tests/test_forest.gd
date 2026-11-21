extends Node
## Grzybowy Las (wersja testowa): losowy teren z kolizją, lądowisko, kanion, doły,
## grzyby z brył, znajdźki i Hammer Capy (fala trafia na ziemi, w skoku nie).
## Uruchom:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_forest.tscn

const FOREST := preload("res://scenes/levels/expedition_mushroom.tscn")
const FOREST_SCRIPT := preload("res://scripts/expedition/mushroom_expedition.gd")
const TEST_SAVE := "user://test_forest_save.json"

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.save_path = TEST_SAVE
	GameState.new_game()
	GameState.start_run({}, {"biome": &"mushroom"})
	var started := Time.get_ticks_msec()
	var forest := FOREST.instantiate()
	forest.set("return_scene", "")
	add_child(forest)
	print("  (ładowanie lasu: %d ms)" % (Time.get_ticks_msec() - started))
	await _frames(3)

	var level := forest.get_node("Level")
	var terrain := level.get_node("Terrain") as ForestTerrain
	var player := forest.get_node("Player") as Player
	var beacon := level.get_node("EvacBeacon") as Node3D

	# --- Teren ---
	var pad := terrain.pad_point()
	var pad_flat := true
	for offset in [Vector2(5, 0), Vector2(-5, 3), Vector2(0, -6), Vector2(4, 4)]:
		if absf(terrain.height_at(terrain.pad_center.x + offset.x, terrain.pad_center.y + offset.y) - pad.y) > 0.3:
			pad_flat = false
	_check(pad_flat, "lądowisko płaskie")
	var lo := INF
	var hi := -INF
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 400:
		var h := terrain.height_at(rng.randf_range(-130, 130), rng.randf_range(-130, 130))
		lo = minf(lo, h)
		hi = maxf(hi, h)
	_check(hi - lo > 12.0, "teren nierówny: różnica wysokości %.1f m" % (hi - lo))

	var mid := terrain.canyon_point(0.5)
	var c_pts := terrain.canyon_points
	var i_mid := c_pts.size() / 2
	var dir := (c_pts[i_mid + 1] - c_pts[i_mid - 1]).normalized()
	var side := Vector2(-dir.y, dir.x) * (terrain.canyon_floor_half + terrain.canyon_wall + 4.0)
	var rim_a := terrain.height_at(c_pts[i_mid].x + side.x, c_pts[i_mid].y + side.y)
	var rim_b := terrain.height_at(c_pts[i_mid].x - side.x, c_pts[i_mid].y - side.y)
	_check(minf(rim_a, rim_b) - mid.y > 7.0, "kanion głęboki w środku (%.1f m)" % (minf(rim_a, rim_b) - mid.y))
	var start := terrain.canyon_point(0.01)
	var cut := terrain._raw(start.x, start.z) - start.y
	_check(cut < 4.0, "wejście do kanionu płytkie (wcięcie %.1f m)" % cut)
	var ramp_ok := true
	for k in 20:  # rampa na początku kanionu nie jest stroma (da się wejść i wyjść)
		var a := terrain.canyon_point(k * 0.0065)
		var b := terrain.canyon_point((k + 1) * 0.0065)
		var run_len := Vector2(b.x - a.x, b.z - a.z).length()
		if run_len > 0.01 and absf(b.y - a.y) / run_len > 0.9:
			ramp_ok = false
	_check(ramp_ok, "rampa kanionu łagodniejsza niż 42 stopnie")

	_check(terrain.pits.size() >= 4, "doły w terenie (%d)" % terrain.pits.size())
	if not terrain.pits.is_empty():
		var pit: Vector4 = terrain.pits[0]
		var bottom := terrain.height_at(pit.x, pit.y)
		var around := -INF
		for k in 12:  # najwyższy punkt na pierścieniu wokół dołu (rampa tylko w jednym kierunku)
			var a := TAU * k / 12.0
			around = maxf(around, terrain.height_at(pit.x + pit.z * 1.6 * cos(a), pit.y + pit.z * 1.6 * sin(a)))
		_check(around - bottom > 3.5, "dół głęboki (%.1f m)" % (around - bottom))

	# Kolizja zgadza się z siatką.
	var space := (forest as Node3D).get_world_3d().direct_space_state
	var worst := 0.0
	for i in 30:
		# W węzłach siatki (między nimi siatka i kolizja to płaskie trójkąty, a height_at krzywa).
		var x := roundf(rng.randf_range(-120, 120) / terrain.cell) * terrain.cell
		var z := roundf(rng.randf_range(-120, 120) / terrain.cell) * terrain.cell
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 200, z), Vector3(x, -100, z), 1))
		if hit.is_empty():
			worst = INF
			break
		if (hit["collider"] as Node).is_in_group("terrain"):
			worst = maxf(worst, absf(hit["position"].y - terrain.height_at(x, z)))
	_check(worst < 0.6, "kolizja terenu zgadza się z wysokością (max %.2f m)" % worst)

	# --- Zawartość ---
	var mushrooms := level.get_node("Mushrooms") as ForestMushrooms
	_check(mushrooms.giants.size() >= 80, "olbrzymie grzyby (%d)" % mushrooms.giants.size())
	var in_canyon := 0
	for g in mushrooms.giants:
		var b: Vector3 = g["base"]
		if terrain.in_canyon(b.x, b.z):
			in_canyon += 1
	_check(in_canyon == 0, "w kanionie nie rosną olbrzymy")
	var pickups := level.get_children().filter(func(n: Node) -> bool: return n is Pickup)
	var cave_loot: int = FOREST_SCRIPT.SPORE_HOLLOW_LOOT + FOREST_SCRIPT.CAVE_LOOT * (terrain.caves.size() - 1)
	_check(pickups.size() == FOREST_SCRIPT.FOREST_PICKUPS + FOREST_SCRIPT.FOREST_NIGHT_PICKUPS + 1 + cave_loot, "znajdźki (%d)" % pickups.size())
	var floating := 0
	for p: Pickup in pickups:
		if absf(p.global_position.y - terrain.mesh_height_at(p.global_position.x, p.global_position.z)) > 0.05:
			floating += 1
	_check(floating == 0, "znajdźki leżą na terenie")
	var hammers := level.get_children().filter(func(n: Node) -> bool: return n is HammerCap)
	_check(hammers.size() == FOREST_SCRIPT.HAMMER_CAPS, "Hammer Capy w kanionie (%d)" % hammers.size())
	var all_in := true
	var on_wall := true
	var hits_floor := true
	for h: HammerCap in hammers:
		if not terrain.in_canyon(h.impact_point.x, h.impact_point.z):
			all_in = false
		# Wyrasta ze ściany: punkt montażu wyżej niż dno pod nim, uderza w dno kanionu.
		if h.global_position.y - h.impact_point.y < 1.5:
			on_wall = false
		if absf(h.impact_point.y - terrain.mesh_height_at(h.impact_point.x, h.impact_point.z)) > 0.1 or h.slam_angle > 2.0:
			hits_floor = false
	_check(all_in, "wszystkie Hammer Capy biją w kanion")
	_check(on_wall, "Hammer Capy wyrastają ze ścian (nad dnem)")
	_check(hits_floor, "kapelusz sięga dna kanionu")

	# Detale lasu.
	var details := level.get_node("Details") as ForestDetails
	var kinds := details.placed.keys().size()
	var total := 0
	for k in details.placed:
		total += int(details.placed[k])
	_check(kinds >= 14 and total > 1500, "detale lasu: %d rodzajów, %d sztuk" % [kinds, total])
	_check(int(details.placed.get("oyster", 0)) > 50 and int(details.placed.get("ghost_wall_a", 0)) > 20, "grzyby na ścianach i trzonach")

	# Gracz startuje przy latarni i stoi na ziemi.
	await _frames(30)
	var flat := Vector2(player.global_position.x - beacon.global_position.x, player.global_position.z - beacon.global_position.z)
	_check(flat.length() < 3.0, "gracz startuje przy latarni")
	_check(player.is_on_floor() and absf(player.global_position.y - pad.y) < 0.6, "gracz stoi na lądowisku")

	# --- Hammer Cap ---
	var hammer := hammers[0] as HammerCap
	for other: HammerCap in hammers:
		if other != hammer:
			other.process_mode = Node.PROCESS_MODE_DISABLED
	var ground := hammer.impact_point
	var along := (hammer.impact_point - hammer.global_position)
	along.y = 0.0
	player.global_position = ground + along.normalized().rotated(Vector3.UP, PI / 2) * 4.0 + Vector3(0, 0.5, 0)
	await _frames(20)
	var hp := player.health
	var sent := hammer.waves_sent
	await _wait_wave(hammer, sent)
	await _frames(25)
	_check(player.health < hp, "fala trafia gracza stojącego na ziemi (%.0f -> %.0f)" % [hp, player.health])

	# W powietrzu fala przechodzi pod graczem.
	player.heal(100)
	hp = player.health
	sent = hammer.waves_sent
	while hammer.state != HammerCap.State.SLAM:
		await _frames(1)
		if hammer.state == HammerCap.State.RAISE and player.is_on_floor():
			player.velocity.y = 9.0
	await _wait_wave(hammer, sent)
	await _frames(10)
	_check(player.health >= hp, "skok nad falą chroni (%.0f -> %.0f)" % [hp, player.health])

	# Strzał przerywa zamach.
	hammer.take_hit(10.0)
	_check(hammer.state == HammerCap.State.STUNNED, "trafienie ogłusza Hammer Capa")

	hammer.process_mode = Node.PROCESS_MODE_DISABLED
	await _test_world(forest, terrain, player, level)
	await _test_director(forest, terrain, player, level)
	await _test_step3(forest, terrain, player, level)

	forest.queue_free()
	GameState.run = null
	if _failures == 0:
		print("TESTY OK")
	else:
		printerr("TESTY: %d błędów" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Krok 2: jaskinie, Grota Zarodników, arena, serca grzybni, Shelfcapy, zarodniki pod kapeluszami.
func _test_world(forest: Node, terrain: ForestTerrain, player: Player, level: Node) -> void:
	_check(terrain.caves.size() == 3, "3 jaskinie (jest %d)" % terrain.caves.size())
	var pad := terrain.pad_center
	_check(terrain.arena.z > 0.0 and Vector2(terrain.arena.x, terrain.arena.y).distance_to(pad) > 100.0, "arena bossa daleko od lądowiska")
	_check(terrain.hearts.size() >= 10, "serca grzybni (%d)" % terrain.hearts.size())
	var mush := level.get_node("Mushrooms") as ForestMushrooms
	var bad := 0
	for g in mush.giants:
		var b: Vector3 = g["base"]
		if terrain.cave_at(b.x, b.z) >= 0 or terrain.in_arena(b.x, b.z):
			bad += 1
	_check(bad == 0, "olbrzymy nie rosną w jaskiniach ani na arenie")
	var caves := level.get_node("Caves") as ForestCaves
	var space := (forest as Node3D).get_world_3d().direct_space_state
	var roofs := true
	var open := true
	var blocker := ""
	for i in terrain.caves.size():
		var c := terrain.caves[i]
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(c.x, c.w + 60.0, c.y), Vector3(c.x, c.w - 5.0, c.y), 1))
		if hit.is_empty() or (hit["position"] as Vector3).y < c.w + 3.0:
			roofs = false
		var a := terrain.cave_facing[i]
		var from := Vector3(c.x + cos(a) * (c.z + 4.0), c.w + 1.6, c.y + sin(a) * (c.z + 4.0))
		var to := Vector3(c.x, c.w + 1.6, c.y)
		var h2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
		if not h2.is_empty():
			open = false
			blocker = "%s/%s w %.1f m" % [(h2["collider"] as Node).get_parent().name, (h2["collider"] as Node).name, from.distance_to(h2["position"])]
	_check(roofs, "jaskinie mają dach (promień z góry trafia w sklepienie)")
	_check(open, "wejścia do jaskiń są otwarte (do środka bez przeszkód) %s" % blocker)
	var fog := caves.cave_nodes[0].get_node_or_null("SporeFog") as Area3D
	_check(fog != null and fog.is_in_group("spore_fog"), "Grota Zarodników ma strefę zarodników")
	if fog:
		var c0 := terrain.caves[0]
		player.global_position = Vector3(c0.x, c0.w + 1.0, c0.y)
		player.velocity = Vector3.ZERO
		await _frames(8)
		_check(fog.overlaps_body(player), "strefa zarodników wykrywa gracza w grocie")
	# Schody z półek.
	var shelves := level.get_node("Shelves") as ForestShelves
	var climbable := true
	var worst := ""
	var count := 0
	for stair: Array in shelves.stairs:
		count += stair.size()
		for k in range(1, stair.size()):
			var a0: Transform3D = stair[k - 1]
			var a1: Transform3D = stair[k]
			var dy := a1.origin.y - a0.origin.y
			var dxz := Vector2(a1.origin.x - a0.origin.x, a1.origin.z - a0.origin.z).length()
			if dy > 1.3 or dxz > 3.2:
				climbable = false
				worst = "dy %.2f dxz %.2f (krok %d z %d)" % [dy, dxz, k, stair.size()]
	_check(shelves.stairs.size() >= 6 and count >= 20, "schody z Shelfcapów (%d schodów, %d półek)" % [shelves.stairs.size(), count])
	_check(climbable, "kolejne półki w zasięgu skoku (do 1,3 m w górę, do 3,2 m w bok) %s" % worst)
	var first: Transform3D = (shelves.stairs[0] as Array)[0]
	var top := first.origin + first.basis.z * 1.0
	# Krótki promień tuż nad półką (wyższa półka schodów może wisieć nad nią, jak u prawdziwych hub).
	var hit3 := space.intersect_ray(PhysicsRayQueryParameters3D.create(top + Vector3(0, 0.7, 0), top - Vector3(0, 3, 0), 1))
	_check(not hit3.is_empty() and absf((hit3["position"] as Vector3).y - first.origin.y) < 0.4, "na półce da się stanąć (kolizja na wysokości półki)")
	# Zarodniki pod kapeluszami najbliższych olbrzymów.
	var g0: Dictionary = mush.giants[0]
	player.global_position = (g0["base"] as Vector3) + Vector3(4, 1, 0)
	await _frames(80)
	var spores := level.get_node("Spores") as ForestSpores
	var on := spores.emitters.filter(func(e: GPUParticles3D) -> bool: return e.emitting)
	_check(on.size() >= 5, "zarodniki sypią się spod najbliższych kapeluszy (%d emiterów)" % on.size())


## Reżyser przeciwników, kokony, Sporebat i Rotling.
func _test_director(forest: Node, terrain: ForestTerrain, player: Player, level: Node) -> void:
	var director := forest.get("director") as SpawnDirector
	_check(director != null, "reżyser przeciwników działa w lesie")
	if director == null:
		return
	director.enabled = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var spot := terrain.random_point(rng, 20.0)
	player.global_position = spot + Vector3(0, 0.5, 0)
	player.velocity = Vector3.ZERO
	await _frames(10)
	# Punkty spawnu: 25-45 m, poza kamerą.
	var ok := true
	var found := 0
	for i in 20:
		var p := director.find_spawn_point()
		if p == Vector3.INF:
			continue
		found += 1
		var d := Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length()
		if director.is_visible(p) or d < 24.5 or d > 45.5:
			ok = false
	_check(found > 10 and ok, "kokony tylko poza kamerą, 25-45 m od gracza (%d/20)" % found)
	var seen := false
	for dist: float in [6.0, 9.0, 12.0, 15.0]:  # przed kamerą (pierwszy niezasłonięty pniem czy półką)
		var ahead: Vector3 = player.camera.global_position - player.camera.global_basis.z * dist - Vector3(0, 1.0, 0)
		if director.is_visible(ahead):
			seen = true
	_check(seen, "punkt przed kamerą liczy się jako widoczny")

	# Kokon pęka i wychodzą Rotlingi; dobiegają i gryzą.
	player.heal(100)
	var hp := player.health
	var near := terrain.surface_point(spot.x + 6.0, spot.z)
	director.spawn_pack("rotling", 2, near)
	await _frames(int(1.6 * 60) + 10)
	_check(director.alive.size() == 2 and director.alive[0] is Rotling, "z kokonu wychodzą 2 Rotlingi")
	for k in 360:
		await _frames(1)
		if player.health < hp:
			break
	_check(player.health < hp, "Rotling dobiega i gryzie (%.0f -> %.0f)" % [hp, player.health])
	# Zabicie: Mycelium Fiber i Przebudzenie.
	var run := GameState.run
	var aw := run.awakening
	var victim := director.alive[0]
	victim.take_hit(100.0)
	await _frames(3)
	var fibers := level.get_children().filter(func(n: Node) -> bool: return n is Pickup and (n as Pickup).item_id == &"mycelium_fiber")
	_check(fibers.size() >= 1, "zabity Rotling zostawia Mycelium Fiber")
	_check(run.awakening >= aw + 1.9, "zabicie podnosi Przebudzenie (+%.1f)" % (run.awakening - aw))
	_check(not director.alive.has(victim), "zabity znika z listy reżysera")
	# Daleko zostawiony wraca do grzybni.
	var last := director.alive[0]
	var credits := director.credits
	last.global_position = player.global_position + Vector3(95, 0, 0)
	director.enabled = true
	director.elapsed = 0.0  # bez nowych grup (czas ochronny)
	await _frames(80)
	director.enabled = false
	_check(director.alive.is_empty() and director.credits > credits, "daleki Rotling wraca do grzybni, punkty wracają")

	# Sporebat: nurkuje i rani.
	player.heal(100)
	hp = player.health
	director.spawn_pack("sporebat", 1, near)
	await _frames(int(1.6 * 60) + 10)
	var bat := director.alive[0] as Sporebat
	_check(bat != null, "z kokonu wychodzi Sporebat")
	if bat:
		bat.set("_timer", 0.1)
		for k in 600:
			await _frames(1)
			if bat.dives > 0:
				break
		_check(bat.dives > 0 and player.health < hp, "Sporebat nurkuje na gracza (%.0f -> %.0f)" % [hp, player.health])
		bat.take_hit(10.0)
		_check(bat.dead, "Sporebat pada od jednego strzału")

	# Reżyser sam kupuje grupę, gdy ma punkty.
	director.alive.clear()
	director.enabled = true
	director.elapsed = SpawnDirector.START_GRACE + 1.0
	director.credits = 40.0
	await _frames(90)
	var cocoons := level.get_children().filter(func(n: Node) -> bool: return n is SporeCocoon)
	_check(cocoons.size() >= 1 and director.credits < 40.0, "reżyser sam wypuszcza kokon za punkty")
	director.enabled = false


## Krok 3: Spore Tick, Rot Thornback, halucynacje (mgła groty, fałszywe znajdźki, fantomy, maska).
func _test_step3(forest: Node, terrain: ForestTerrain, player: Player, level: Node) -> void:
	var director := forest.get("director") as SpawnDirector
	var hall := forest.get("hallucination") as Hallucination
	_check(hall != null, "licznik halucynacji działa w lesie")
	director.enabled = false
	await _frames(int(1.7 * 60))  # niech pękną kokony z poprzedniego testu
	for c in director.alive.duplicate():
		if is_instance_valid(c):
			c.queue_free()
	director.alive.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var spot := terrain.random_point(rng, 20.0)
	player.global_position = spot + Vector3(0, 0.5, 0)
	player.velocity = Vector3.ZERO
	player.heal(100)
	hall.value = 0.0
	await _frames(10)
	# Spore Tick skacze i dodaje halucynacji.
	var hp := player.health
	director.spawn_pack("spore_tick", 1, terrain.surface_point(spot.x + 5.0, spot.z))
	await _frames(int(1.6 * 60) + 5)
	var ticks := director.alive.filter(func(c: ForestCreature) -> bool: return c is SporeTick)
	var tick := (ticks[0] if not ticks.is_empty() else null) as SporeTick
	_check(tick != null, "z kokonu wychodzi Spore Tick")
	if tick == null:
		return
	for k in 600:
		await _frames(1)
		if tick.hits > 0:
			break
	_check(tick.leaps > 0 and player.health < hp and hall.value > 0.1, "Spore Tick skacze, rani i dodaje halucynacji (%.2f)" % hall.value)
	tick.take_hit(20.0)
	_check(tick.dead, "Spore Tick pada od dwóch strzałów")
	await _frames(30)
	# Rot Thornback szarżuje.
	player.heal(100)
	hp = player.health
	director.alive.clear()
	director.spawn_pack("rot_thornback", 1, terrain.surface_point(spot.x + 10.0, spot.z + 2.0))
	await _frames(int(1.6 * 60) + 5)
	var rts := director.alive.filter(func(c: ForestCreature) -> bool: return c is RotThornback)
	var rt := (rts[0] if not rts.is_empty() else null) as RotThornback
	_check(rt != null, "z kokonu wychodzi Rot Thornback")
	if rt == null:
		return
	for k in 900:
		await _frames(1)
		player.velocity = Vector3.ZERO
		if player.health < hp:
			break
	_check(rt.charges > 0 and player.health <= hp - RotThornback.DAMAGE + 0.1, "Rot Thornback szarżuje i trafia (%.0f -> %.0f)" % [hp, player.health])
	for k in 7:
		rt.take_hit(10.0)
	_check(rt.dead, "Rot Thornback pada po 7 strzałach")
	await _frames(30)
	director.alive.clear()
	# Grota Zarodników: licznik rośnie, potem fałszywe znajdźki i fantomy.
	var c0 := terrain.caves[0]
	player.heal(100)
	hp = player.health
	hall.value = 0.0
	player.global_position = Vector3(c0.x, c0.w + 1.0, c0.y)
	player.velocity = Vector3.ZERO
	await _frames(int(4.0 * 60))
	_check(hall.in_fog() and hall.value > 0.3, "w grocie halucynacje rosną (%.2f po 4 s)" % hall.value)
	hall.value = 0.99
	await _frames(int(2.0 * 60))
	_check(hall.fakes.size() >= 3, "fałszywe znajdźki (%d)" % hall.fakes.size())
	_check(hall.phantoms.size() >= 1, "fantomowi przeciwnicy (%d)" % hall.phantoms.size())
	var fake := hall.fakes[0] as Pickup
	_check(fake.phantom, "fałszywa znajdźka jest oznaczona jako fantom")
	var bag := GameState.run.used_space()
	# Podniesienie fałszywki nic nie daje (wywołanie przez interakcję gracza).
	var inter := player.interaction as ExpeditionInteraction
	player.global_position = fake.global_position + Vector3(0.6, 0.3, 0)
	inter.set("_target", {"collider": fake, "position": fake.global_position})
	inter.call("_interact")
	await _frames(3)
	_check(not is_instance_valid(fake) or fake.is_queued_for_deletion(), "fałszywa znajdźka znika przy podniesieniu")
	_check(GameState.run.used_space() == bag, "fałszywa znajdźka nic nie dodaje do plecaka")
	# Fantom nie rani i rozwiewa się po strzale.
	var ph := hall.phantoms[0] as ForestCreature
	ph.global_position = player.global_position + Vector3(1.0, 0.2, 0)
	await _frames(120)
	_check(player.health >= hp, "fantomy nie zadają obrażeń")
	ph.take_hit(10.0)
	await _frames(2)
	_check(not is_instance_valid(ph) or ph.is_queued_for_deletion(), "fantom rozwiewa się po strzale")
	# Spore Mask: licznik nie rośnie.
	hall.value = 0.0
	GameState.upgrades[&"spore_mask"] = true
	await _frames(int(2.0 * 60))
	_check(hall.value == 0.0, "Spore Mask chroni przed halucynacjami")
	GameState.upgrades.erase(&"spore_mask")
	# Poza mgłą licznik opada.
	hall.value = 0.5
	player.global_position = spot + Vector3(0, 0.5, 0)
	await _frames(int(2.0 * 60))
	_check(hall.value < 0.45, "poza mgłą halucynacje opadają (%.2f)" % hall.value)


func _wait_wave(hammer: HammerCap, sent: int) -> void:
	for i in 400:
		if hammer.waves_sent > sent:
			return
		await _frames(1)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		printerr("  FAIL ", label)
