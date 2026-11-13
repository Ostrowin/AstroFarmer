class_name Outline
extends RefCounted
## Obwódka obiektu, z którym gracz może teraz coś zrobić.
## Nakładka (material_overlay) z "odwróconą skorupą": każda siatka obiektu
## rysuje się drugi raz, lekko powiększona, tylko od tyłu, jednolitym kolorem.
## Siatki z meta "no_outline" (np. krążek gleby pod rośliną) są pomijane.

const COLOR := Color(1.0, 0.95, 0.55)
const WIDTH := 0.025

static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.95, 0.55, 1.0);
uniform float width = 0.025;
void vertex() {
	VERTEX += normalize(NORMAL) * width;
}
void fragment() {
	ALBEDO = color.rgb;
}
"""
		_material = ShaderMaterial.new()
		_material.shader = shader
		_material.set_shader_parameter("color", COLOR)
		_material.set_shader_parameter("width", WIDTH)
	return _material


## Włącza albo wyłącza obwódkę na wszystkich siatkach węzła.
static func apply(node: Node, enabled: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	var overlay: Material = material() if enabled else null
	if node is MeshInstance3D and not node.has_meta("no_outline"):
		(node as MeshInstance3D).material_overlay = overlay
	for child in node.find_children("*", "MeshInstance3D", true, false):
		if not child.has_meta("no_outline"):
			(child as MeshInstance3D).material_overlay = overlay


## Pilnuje jednego podświetlonego obiektu (dla jednego gracza).
class Tracker:
	var current: Node = null

	func set_target(node: Node) -> void:
		if node == current:
			# Ponowne nałożenie: model rośliny mógł się przebudować (nowy etap).
			if current and is_instance_valid(current):
				Outline.apply(current, true)
			return
		if current and is_instance_valid(current):
			Outline.apply(current, false)
		current = node
		if current:
			Outline.apply(current, true)
