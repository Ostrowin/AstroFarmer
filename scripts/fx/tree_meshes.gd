class_name TreeMeshes
extends Resource
## Zapisane siatki jednego wygenerowanego drzewa (pamięć podręczna TreeGenerator).

## Nazwa węzła -> siatka ("Bark", "Leaves", "Glow").
@export var meshes: Dictionary = {}
## Nazwa węzła -> [kolor materiału, siła świecenia].
@export var materials: Dictionary = {}


## `mid`, `low` (opcjonalnie): to samo drzewo w wersjach uproszczonych ("<nazwa>_mid", "<nazwa>_far").
static func from_tree(tree: Node3D, mid: Node3D = null, low: Node3D = null) -> TreeMeshes:
	var out := TreeMeshes.new()
	for source: Node3D in [tree, mid, low]:
		if source == null:
			continue
		for child in source.get_children():
			var instance := child as MeshInstance3D
			if instance == null:
				continue
			var key := String(instance.name) + ("_mid" if source == mid else ("_far" if source == low else ""))
			var mat := instance.material_override as StandardMaterial3D
			out.meshes[key] = instance.mesh
			out.materials[key] = [mat.albedo_color, mat.emission_energy_multiplier if mat.emission_enabled else 0.0]
		source.free()
	return out


## Zasięgi od kamery: pełne siatki do `near`, "_mid" do `mid`, "_far" do `far` (0 = bez końca).
## Bez płynnego przenikania (dithering wyłącza wczesny test głębokości i kosztuje kilka ms),
## wersje mają ten sam kształt, więc przeskok prawie nie widać. Uproszczone nie rzucają cienia.
## `near` = 0: tylko pełne siatki, zawsze widoczne. `mid` = 0: połowa drogi między near i far.
func instantiate(near := 0.0, far := 0.0, mid := 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Tree"
	if near > 0.0 and mid <= 0.0:
		mid = near + (far - near) * 0.3 if far > 0.0 else near * 2.0
	for mesh_name: String in meshes:
		var tier := 2 if mesh_name.ends_with("_far") else (1 if mesh_name.ends_with("_mid") else 0)
		if tier > 0 and near <= 0.0:
			continue
		var instance := MeshInstance3D.new()
		instance.name = mesh_name
		instance.mesh = meshes[mesh_name]
		var info: Array = materials.get(mesh_name, [Color.WHITE, 0.0])
		instance.material_override = TreeGenerator.shared_material(info[0], info[1])
		if near > 0.0:
			var ranges := [Vector2(0.0, near), Vector2(near, mid), Vector2(mid, far)]
			instance.visibility_range_begin = ranges[tier].x
			instance.visibility_range_end = ranges[tier].y
			if tier > 0:
				instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)
	return root
