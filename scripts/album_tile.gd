class_name AlbumTile
extends Node3D
## Ficha del álbum: la misma ficha del tablero (cuerpo dorado con bisel, cara con la
## imagen y dorso con emblema), a menor tamaño. Boca arriba si la pareja está
## dominada; boca abajo (dorso) si todavía no.

const REST := 0.06        # altura de reposo: igual que las fichas pendientes del tablero
const PRESS_Y := 0.16     # altura al pulsar
const BOARD_ST := 1.12    # casilla del tablero (Board.ST): la ficha se escala desde ahí
const HY := 0.065         # grosor y cara de la ficha: los mismos que en Board
const FACE := 0.425

static var _shared: Dictionary = {}

## Mallas y materiales de la ficha, iguales a los de Board. Se crean una sola vez y los
## comparten el álbum y la victoria, para que las fichas de las dos mesas sean idénticas.
static func shared() -> Dictionary:
	if _shared.is_empty():
		_shared = {
			"body": TileMesh.slab(0.49, 0.49, 0.16, HY * 2.0, 0.03, 5, 8),
			"face": TileMesh.face(FACE, HY + 0.003, true),
			"back": TileMesh.face(FACE, -HY - 0.003, false),
			"gold": TileLook.gold_material(TileLook.bezel_texture()),
			"back_mat": TileLook.face_material(TileLook.back_texture()),
		}
	return _shared

var size := Vector2.ONE   # casilla en el mundo (para Pick3D)
var pair: Dictionary = {}
var mastered: bool = false

var _flip: Node3D
var _base: float = 1.0
var _tw: Tween
var _ft: Tween          # tween del giro (demos)
var _face_mat: StandardMaterial3D
var _halo: MeshInstance3D

## `shared`: mallas y materiales comunes (los crea StationAlbum una sola vez).
func setup(shared: Dictionary, tex: Texture2D, up: bool, side: float, pr: Dictionary) -> void:
	pair = pr
	mastered = up
	size = Vector2(side, side)
	_base = side / BOARD_ST
	scale = Vector3.ONE * _base
	position.y = REST
	_flip = Node3D.new()
	add_child(_flip)
	var body := MeshInstance3D.new()
	body.mesh = shared["body"]
	body.material_override = shared["gold"]
	_flip.add_child(body)
	var face := MeshInstance3D.new()
	face.mesh = shared["face"]
	_face_mat = TileLook.face_material(tex)
	face.material_override = _face_mat
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flip.add_child(face)
	var back := MeshInstance3D.new()
	back.mesh = shared["back"]
	back.material_override = shared["back_mat"]
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flip.add_child(back)
	_flip.rotation.z = 0.0 if up else PI

## Entrada: la ficha crece desde el centro (con un pequeño retardo).
func pop_in(delay: float) -> void:
	scale = Vector3.ONE * 0.001
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(self, "scale", Vector3.ONE * _base, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Rebote al tocar: sube y vuelve a su altura.
func press() -> void:
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "position:y", PRESS_Y, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "position:y", REST, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ---------- Demostraciones (la ayuda anima fichas que no se tocan) ----------

## Gira la ficha con un saltito, como en el tablero.
func flip_to(up: bool, secs: float = 0.33) -> void:
	if _ft != null:
		_ft.kill()
	_ft = create_tween()
	_ft.tween_property(_flip, "rotation:z", 0.0 if up else PI, secs) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "position:y", 0.5, secs * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "position:y", REST, secs * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## Anillo que se abre y se apaga: marca "tocá aquí" (azul) o acierto (dorado).
func ping(col: Color = Color("3b82f6")) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = TileMesh.ring(0.50, 0.74, 0.0, 8, 0.17)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 2
	m.albedo_color = col
	mi.material_override = m
	mi.position.y = 0.15
	mi.scale = Vector3.ONE * 0.8
	add_child(mi)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.45, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(mi.queue_free)

## Ficha "elegida" (modo Asociación): sube y muestra un halo azul.
func select(on: bool) -> void:
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "position:y", 0.3 if on else REST, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if on and _halo == null:
		_halo = MeshInstance3D.new()
		_halo.mesh = TileMesh.ring(0.50, 0.565, 0.0, 8, 0.17)
		_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(0.23, 0.51, 0.96, 0.85)
		_halo.material_override = m
		_halo.position.y = -0.075
		add_child(_halo)
	elif not on and _halo != null:
		_halo.queue_free()
		_halo = null

func shake() -> void:
	var tw := _flip.create_tween()
	tw.tween_property(_flip, "position:x", 0.1, 0.06)
	tw.tween_property(_flip, "position:x", -0.1, 0.09)
	tw.tween_property(_flip, "position:x", 0.0, 0.06)

## Pareja resuelta: salto, destello dorado y cara atenuada.
func celebrate() -> void:
	select(false)
	ping(Color("ffb400"))
	_face_mat.albedo_color = Color(0.70, 0.80, 0.74)
	if _tw != null:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(self, "position:y", 0.45, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "position:y", REST, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func reset_state() -> void:
	_face_mat.albedo_color = Color.WHITE
