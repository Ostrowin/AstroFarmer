class_name TreeMeshes
extends Resource
## Zapisane siatki jednego wygenerowanego drzewa (pamięć podręczna TreeGenerator).

## Nazwa węzła -> siatka ("Bark", "Leaves", "Glow").
@export var meshes: Dictionary = {}
## Nazwa węzła -> [kolor materiału, siła świecenia].
@export var materials: Dictionary = {}


static func from_tree(tree: Node3D) -> TreeMeshes:
	var out := TreeMeshes.new()
	for child in tree.get_children():
		var instance := child as MeshInstance3D
		if instance == null:
			continue
		var mat := instance.material_override as StandardMaterial3D
		out.meshes[String(instance.name)] = instance.mesh
		out.materials[String(instance.name)] = [mat.albedo_color, mat.emission_energy_multiplier if mat.emission_enabled else 0.0]
	return out


func instantiate() -> Node3D:
	var root := Node3D.new()
	root.name = "Tree"
	for mesh_name in meshes:
		var instance := MeshInstance3D.new()
		instance.name = mesh_name
		instance.mesh = meshes[mesh_name]
		var info: Array = materials.get(mesh_name, [Color.WHITE, 0.0])
		instance.material_override = TreeGenerator.shared_material(info[0], info[1])
		root.add_child(instance)
	return root
