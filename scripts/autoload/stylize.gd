extends Node
## Wspólny styl wszystkich modeli: cel-shading (ostre tony światła, jasna krawędź)
## i miękkie plamy farby na powierzchni. Działa na zwykłe StandardMaterial3D,
## więc świecenie roślin, mutacje i obwódki działają jak wcześniej.
## Każdy MeshInstance3D wchodzący do drzewa sceny dostaje styl automatycznie.

## Wyłącznik (np. do porównań w testach).
var enabled := true

var _paint: NoiseTexture2D
var _done: Dictionary = {}


func _ready() -> void:
	_paint = _make_paint()
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if enabled and node is MeshInstance3D:
		apply(node as MeshInstance3D)


## Nakłada styl na wszystkie materiały siatki (materiały są współdzielone, więc raz na materiał).
func apply(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	_style(mi.material_override)
	for i in mi.mesh.get_surface_count():
		_style(mi.get_surface_override_material(i))
		_style(mi.mesh.surface_get_material(i))


func _style(material: Material) -> void:
	var m := material as BaseMaterial3D
	if m == null or _done.has(m):
		return
	_done[m] = true
	# Nieoświetlone (cząsteczki, napisy) i przezroczyste (szkło, mgła) zostają gładkie.
	if m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.rim_enabled = true
	m.rim = 0.5
	m.rim_tint = 0.3
	m.detail_enabled = true
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.detail_albedo = _paint
	m.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	# Triplanar w przestrzeni obiektu: plamy nie "pływają" po animowanych modelach.
	m.uv2_triplanar = true
	m.uv2_world_triplanar = false
	m.uv2_scale = Vector3(0.45, 0.45, 0.45)


## Tekstura plam farby: komórki z poszarpanymi brzegami, jasność 0.86-1.06.
static func _make_paint() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.02
	noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	noise.domain_warp_enabled = true
	noise.domain_warp_amplitude = 30.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.86, 0.86, 0.86))
	ramp.set_color(1, Color(1.06, 1.06, 1.06))
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	tex.color_ramp = ramp
	return tex
