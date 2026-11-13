class_name Plaque
extends Node3D
## Loseta del mundo (menú y materias): losa dorada con la cara 2D horneada encima.
## No lleva botón: el toque lo resuelve `Pick3D` sobre el plano de la mesa.

const REST := 0.06      # altura de reposo (flota sobre la losa, como las fichas)
const PRESS_Y := 0.14   # altura al pulsar
const SEL_Y := 0.12     # altura de la loseta elegida (modo activo)
const SEL_SCALE := 1.05 # la elegida se ve un poco más grande
const THICK := 0.11
const HY := THICK * 0.5
const RIM := 0.05       # filo dorado alrededor de la cara
const FACE_R := 0.03    # radio de la cara (coincide con el de la tarjeta)

var size := Vector2.ONE
var key := ""
var info := ""
var selected := false

var _body: MeshInstance3D
var _face: MeshInstance3D
var _face_mat: StandardMaterial3D
var _gold: StandardMaterial3D
var _gold_sel: StandardMaterial3D
var _glow: MeshInstance3D
var _vp: SubViewport
var _tw: Tween

## Construye la geometría. `s` es el tamaño en el mundo (ancho × fondo de la mesa).
func setup(s: Vector2, k: String = "", inf: String = "") -> void:
	size = s
	key = k
	info = inf
	position.y = REST
	var hx: float = size.x * 0.5
	var hz: float = size.y * 0.5
	_body = MeshInstance3D.new()
	_body.mesh = TileMesh.slab(hx, hz, 0.14, THICK, 0.022, 3, 5)
	_gold = TileLook.gold_material()
	_gold_sel = TileLook.gold_material()
	_gold_sel.albedo_color = Color("ffe28f")
	_gold_sel.emission_enabled = true
	_gold_sel.emission = Color("ffc23d")
	_gold_sel.emission_energy_multiplier = 0.45
	_body.material_override = _gold
	add_child(_body)
	_face_mat = StandardMaterial3D.new()
	_face_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_face_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_face_mat.albedo_color = Color("fffdf7")
	_face = MeshInstance3D.new()
	_face.mesh = TileMesh.face_rect(hx - RIM, hz - RIM, HY + 0.002, true, FACE_R, 5)
	_face.material_override = _face_mat
	_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_face)
	# Aviso de modo activo: lámina dorada que asoma por debajo del filo
	_glow = MeshInstance3D.new()
	_glow.mesh = TileMesh.slab(hx + 0.11, hz + 0.11, 0.20, 0.012, 0.004, 2, 4)
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color("ffe08a")
	gm.emission_enabled = true
	gm.emission = Color("ffb52e")
	gm.emission_energy_multiplier = 1.1
	_glow.material_override = gm
	_glow.position.y = -HY - 0.012
	_glow.visible = false
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)

## Hornea `content` (un Control) como cara. En headless no hay render: queda lisa.
func bake(content: Control, w: int, h: int) -> void:
	if _vp != null:
		_vp.queue_free()
		_vp = null
	if not FaceTex.available():
		return
	_vp = FaceTex.render(self, content, w, h)
	_face_mat.albedo_texture = _vp.get_texture()

## Viewports que hay que dejar de repintar cuando ya se vieron (`FaceTex.settle`).
func views() -> Array:
	return [_vp] if _vp != null else []

## Entrada: la loseta crece desde el centro (con un pequeño retardo por índice).
func pop_in(delay: float) -> void:
	scale = Vector3.ONE * 0.001
	var to: Vector3 = Vector3.ONE * (SEL_SCALE if selected else 1.0)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(self, "scale", to, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Rebote al tocar: sube y vuelve a su altura (la elegida o la de reposo).
func press() -> void:
	if _tw != null:
		_tw.kill()
	var rest_y: float = SEL_Y if selected else REST
	var up: float = maxf(PRESS_Y, rest_y + 0.05)
	var shr: float = SEL_SCALE if selected else 1.0
	_tw = create_tween()
	_tw.tween_property(self, "position:y", up, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "position:y", rest_y, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Repone también la escala: al tocar un modo, `set_selected` acaba de empezarla
	_tw.parallel().tween_property(self, "scale", Vector3.ONE * shr, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Marca la loseta como elegida (modo activo): se levanta y asoma la lámina dorada.
func set_selected(on: bool, instant: bool = false) -> void:
	selected = on
	_glow.visible = on
	_body.material_override = _gold_sel if on else _gold
	if instant:
		if _tw != null:
			_tw.kill()
		position.y = SEL_Y if on else REST
		scale = Vector3.ONE * (SEL_SCALE if on else 1.0)
		return
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.set_parallel(true)
	_tw.tween_property(self, "position:y", SEL_Y if on else REST, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector3.ONE * (SEL_SCALE if on else 1.0), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)