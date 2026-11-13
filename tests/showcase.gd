extends Node
## Podgląd wszystkich roślin we wszystkich etapach, do oceny wyglądu.
## Uruchom:  Godot_v4.7.2-stable_win64.exe --path . res://tests/showcase.tscn
## Używa osobnego pliku zapisu, więc nie rusza Twojej gry.

const SHOWCASE_SAVE := "user://showcase_save.json"


func _enter_tree() -> void:
	# Przed _ready sceny Main, żeby ta wczytała pusty, osobny zapis.
	GameState.save_path = SHOWCASE_SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SHOWCASE_SAVE))


func _ready() -> void:
	await get_tree().process_frame
	var entries: Array = []
	var row := 0
	for id in PlantCatalog.all_ids():
		var data := PlantCatalog.get_plant(id)
		for stage in data.stages:
			entries.append({
				"id": String(id),
				"x": -1.8 + stage * 1.8, "y": 0.0, "z": 1.5 - row * 2.0,
				"stage": stage, "progress": 0, "watered": stage == 1,
			})
		row += 1
	GameState.farm = entries
	$Main/Farm.load_from_state()
	# Drapieżnik (śpi, bo nie ma wyprawy) i znajdźki z wypraw.
	var creature := Creature.new()
	creature.position = Vector3(4.6, 0.3, -1.5)
	$Main.add_child(creature)
	var kinds := [
		{"kind": "seed", "color": Color(0.62, 0.3, 0.95)},
		{"kind": "crystal", "color": Color(0.45, 0.95, 1.0)},
		{"kind": "sample", "color": Color(0.85, 1.0, 0.4)},
		{"kind": "artifact", "color": Color(1.0, 0.8, 0.3), "buff": {"name": "Turbo-buty"}},
	]
	for i in kinds.size():
		var pickup := Pickup.new()
		pickup.setup(kinds[i])
		pickup.position = Vector3(-3.4, 0, 1.2 - i * 1.1)
		$Main.add_child(pickup)
	var player := $Main/Player as Node3D
	player.global_position = Vector3(0, 0, 5.5)
	# Kamera z bliska na rośliny (Tab przełącza na kamerę gracza).
	_close_up = Camera3D.new()
	add_child(_close_up)
	_close_up.look_at_from_position(Vector3(0.6, 3.4, 5.0), Vector3(0.4, 0.3, -1.6))
	_close_up.current = true


var _close_up: Camera3D


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_TAB and _close_up:
		if _close_up.current:
			($Main/Player as Player).camera.current = true
		else:
			_close_up.current = true
