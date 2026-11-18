class_name FlatLabel
extends Node3D
## Rótulo del mundo: texto, icono y barra pintados directamente sobre la mesa, sin filo
## dorado, sin grosor y sin sombra. Es la otra mitad del lenguaje visual de las losetas:
## lo que se toca es una loseta dorada con relieve (`Plaque`); lo que solo informa va plano.

const Y := -0.092          # apenas por encima de la losa de la mesa (cuya cara está en −0,105)

var size := Vector2.ONE
var _mat: StandardMaterial3D
var _vp: SubViewport

func setup(s: Vector2) -> void:
	size = s
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var mi := MeshInstance3D.new()
	mi.mesh = TileMesh.face_rect(size.x * 0.5, size.y * 0.5, Y, true, 0.02, 3)
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## Hornea `content` (con fondo transparente) como rótulo. En headless queda vacío.
func bake(content: Control, w: int, h: int) -> void:
	if _vp != null:
		_vp.queue_free()
		_vp = null
	if not FaceTex.available():
		return
	_vp = FaceTex.render(self, content, w, h, true)
	_mat.albedo_texture = _vp.get_texture()

func views() -> Array:
	return [_vp] if _vp != null else []

## Entrada: aparece con un fundido (no rebota: no es un botón).
func pop_in(delay: float) -> void:
	_mat.albedo_color = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(_mat, "albedo_color:a", 1.0, 0.35)
