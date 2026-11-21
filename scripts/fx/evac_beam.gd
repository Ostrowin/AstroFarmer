class_name EvacBeam
extends MeshInstance3D
## Słup światła nad latarnią ewakuacyjną: widać go ponad drzewami i przez mgłę,
## więc na dużej łące zawsze wiadomo, gdzie wracać. Pulsuje w górę jak sygnał.
## Za dnia gęstszy i bardziej nasycony (na jasnym niebie słabo widać), nocą świeci.

const HEIGHT := 140.0

const SHADER := """
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform vec3 color : source_color = vec3(0.1, 0.8, 0.95);
uniform vec3 core : source_color = vec3(0.85, 1.0, 1.0);
uniform float opacity = 0.9;
void fragment() {
	float edge = abs(dot(NORMAL, VIEW));
	float up = 1.0 - UV.y;
	float fade = 1.0 - smoothstep(0.15, 1.0, up);
	float pulse = 0.85 + 0.15 * sin(TIME * 2.0 - up * 12.0);
	ALBEDO = mix(color, core, edge * edge);
	ALPHA = clamp(pow(edge, 1.3) * opacity * fade * pulse, 0.0, 1.0);
}
"""

var _material: ShaderMaterial


func _ready() -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 5.0
	cylinder.bottom_radius = 2.2
	cylinder.height = HEIGHT
	cylinder.radial_segments = 24
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	mesh = cylinder
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_meta("no_outline", true)
	position.y += HEIGHT * 0.5
	_update()


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	var night := GameState.night_amount(GameState.time_of_day)
	# Dzień: ciemniejszy turkus, żeby odcinał się od jasnego nieba; noc: jasny, świecący.
	_material.set_shader_parameter("color", Color(0.05, 0.62, 0.8).lerp(Color(0.25, 0.95, 1.0), night))
	_material.set_shader_parameter("opacity", lerpf(1.0, 0.85, night))
