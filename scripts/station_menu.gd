class_name StationMenu
extends Node3D
## Mesa del menú: las cuatro acciones principales (materias, recorrido general, cómo
## jugar y álbum) como losetas 3D. Los modos de juego ya no viven acá: se eligen en la
## estación `StationMode`, justo antes de empezar la partida.
## El resto del menú (logotipo, título y ajustes) sigue siendo una capa 2D encima.

signal open_subjects
signal play_general
signal open_help
signal open_album
signal sfx(name: String)

const CARD_W := 3.5
const CARD_H := 1.0
const GAP := 0.16
const FACE_W := 448
const FACE_H := 128
const FRAME_EXTRA := 1.0   # margen de la mesa (0,55) + filo del marco (0,45)
const FRAME_Y := -0.165    # tapa del marco azul (el encuadre de la cámara la usa)

const LABEL_H := 0.95      # rótulo plano "Menú principal" (no se toca)

var tiles: Array = []
var labels: Array = []
var _table: Node3D
var _content_h: float = 0.0   # alto del contenido de la mesa: rótulo + losetas

func build(level: int) -> void:
	clear()
	var defs: Array = [
		{"key": "subjects", "title": "Materias", "sub": "Elige una asignatura", "icon": "juego",
			"bg": Color("dcecff"), "ink": UiTheme.BLUE_DARK},
		{"key": "general", "title": "Recorrido general", "sub": "Varias materias · Nivel %d" % level, "icon": "brujula",
			"bg": Color("ffe1a0"), "ink": UiTheme.GOLD_INK},
		{"key": "help", "title": "Cómo jugar", "sub": "Dos modos y gestos", "icon": "dialogo",
			"bg": Color("d6f3e0"), "ink": Color("1d6b45")},
		{"key": "album", "title": "Álbum", "sub": "Tus parejas dominadas", "icon": "cuaderno",
			"bg": Color("e3d7ff"), "ink": Color("4b3a9a")},
	]
	var head: float = LABEL_H + GAP
	var h: float = float(defs.size()) * CARD_H + float(defs.size() - 1) * GAP + head
	_content_h = h
	_table = TileLook.table(self, CARD_W + 0.55, h + 0.55)
	var views: Array = []
	var z0: float = -h * 0.5
	var lb := FlatLabel.make(self, Vector2(CARD_W, LABEL_H), {"name": "Menú principal", "sub": "Elige qué quieres hacer",
		"icon": "home", "color": Color("9cc8ff"), "ink": Color("1f5fa8")}, 0.0)
	lb.position.z = z0 + LABEL_H * 0.5
	views.append_array(lb.views())
	labels.append(lb)
	for i in defs.size():
		var d: Dictionary = defs[i]
		var p := Plaque.new()
		p.setup(Vector2(CARD_W, CARD_H), str(d["key"]))
		p.position.z = z0 + head + CARD_H * 0.5 + float(i) * (CARD_H + GAP)
		add_child(p)
		p.bake(Cards.action(str(d["title"]), str(d["sub"]), str(d["icon"]), false,
			d["bg"], d["ink"], FACE_W, FACE_H), FACE_W, FACE_H)
		p.pop_in(0.04 * float(i))
		views.append_array(p.views())
		tiles.append(p)
	FaceTex.settle(views)

func clear() -> void:
	for t in tiles:
		(t as Node).queue_free()
	tiles.clear()
	for l in labels:
		(l as Node).queue_free()
	labels.clear()
	_content_h = 0.0
	if _table != null:
		_table.queue_free()
		_table = null

## Esquinas de la tapa del marco visible, en coordenadas del mundo. `Board` las
## proyecta para centrar la mesa en el hueco libre de la interfaz.
func frame_corners() -> Array:
	if tiles.is_empty():
		return []
	var w: float = CARD_W + FRAME_EXTRA
	var h: float = _content_h + FRAME_EXTRA
	var out: Array = []
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			out.append(global_position + Vector3(w * float(sx), FRAME_Y, h * float(sz)))
	return out

## Zona libre del suelo bajo la mesa, en coordenadas del mundo (la mesa es el origen).
func clear_rect() -> Rect2:
	if tiles.is_empty():
		return Rect2()
	var w: float = CARD_W + 0.7
	var h: float = _content_h + 0.7
	return Rect2(global_position.x - w * 0.5, global_position.z - h * 0.5, w, h)

func tap(pos: Vector2, cam: Camera3D) -> void:
	var p: Plaque = Pick3D.plaque(tiles, cam, pos)
	if p == null:
		return
	p.press()
	sfx.emit("tap")
	match p.key:
		"subjects":
			open_subjects.emit()
		"general":
			play_general.emit()
		"help":
			open_help.emit()
		"album":
			open_album.emit()
