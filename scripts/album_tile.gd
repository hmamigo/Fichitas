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
	face.material_override = TileLook.face_material(tex)
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
