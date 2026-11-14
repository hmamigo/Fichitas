class_name StationSubjects
extends Node3D
## Mesa de materias: losetas rectangulares en una columna. La lista se recorre
## con la cámara (paneo), no con un ScrollContainer.

signal chosen(id: String)      # "" = recorrido general, ":review" = repaso
signal info(text: String)      # materia bloqueada: aviso para la interfaz

const CARD_W := 3.5
const CARD_H := 1.75
const GAP := 0.18
const TILT := 0.17             # igual que la cámara del tablero
const FACE_W := 448
const FACE_H := 224

# Encuadre de la cámara en esta mesa
const FIT_PAD_W := 0.15        # aire a los lados de la tarjeta al encuadrar el ancho
const FIT_ROWS := 2.6          # filas (en alto de tarjeta) que deben caber en pantalla
const FIT_MARGIN := 2.0        # alejamiento sobre el ajuste justo (1.0 = justo); a mano
const PAN_PAD_X := 0.10        # margen extra del paneo horizontal
const PAN_PAD_Y := 0.11        # aire arriba y abajo al recorrer (fracción del alto visible)

var tiles: Array = []
var _table: Node3D

## `cards`: los mismos diccionarios que usaba la pantalla 2D de materias.
func build(cards: Array) -> void:
	clear()
	var n: int = cards.size()
	if n == 0:
		return
	var h: float = float(n) * CARD_H + float(n - 1) * GAP
	var w: float = CARD_W
	_table = TileLook.table(self, w + 0.5, h + 0.5)
	var views: Array = []
	for i in n:
		var d: Dictionary = cards[i]
		var p := Plaque.new()
		p.setup(Vector2(CARD_W, CARD_H), str(d["id"]), str(d.get("info", "")))
		p.position.z = (float(i) - float(n - 1) * 0.5) * (CARD_H + GAP)
		add_child(p)
		p.bake(Cards.subject(d, FACE_W, FACE_H), FACE_W, FACE_H)
		p.pop_in(0.03 * float(i))
		views.append_array(p.views())
		tiles.append(p)
	FaceTex.settle(views)

func clear() -> void:
	for t in tiles:
		(t as Node).queue_free()
	tiles.clear()
	if _table != null:
		_table.queue_free()
		_table = null

## Distancia de cámara para que quepa la tarjeta (y se vean varias filas).
func fit_distance() -> float:
	var need := Vector2(CARD_W + FIT_PAD_W, FIT_ROWS * CARD_H)
	return CamView.distance_for(get_viewport(), need) * FIT_MARGIN

## Cuánto se puede desplazar la cámara sin perder de vista la mesa.
func pan_bounds(dist: float) -> Vector2:
	var n: int = tiles.size()
	if n == 0:
		return Vector2.ZERO
	var view: Vector2 = CamView.visible_size(get_viewport(), dist)
	var w: float = CARD_W + 0.5
	var h: float = float(n) * CARD_H + float(n - 1) * GAP + 0.5
	# Un poco de aire arriba (la cabecera 2D) y abajo al recorrer la lista
	var extra: float = view.y * PAN_PAD_Y
	return Vector2(maxf((w - view.x) * 0.5 + PAN_PAD_X, 0.0), maxf((h - view.y) * 0.5 + extra, 0.0))

## Desplazamiento inicial: empezar por la primera fila (arriba de la mesa).
func initial_z(dist: float) -> float:
	return -pan_bounds(dist).y

## Zona libre del suelo bajo la mesa, en coordenadas del mundo.
func clear_rect() -> Rect2:
	if tiles.is_empty():
		return Rect2()
	var w: float = CARD_W + 0.7
	var h: float = float(tiles.size()) * CARD_H + float(tiles.size() - 1) * GAP + 0.7
	return Rect2(global_position.x - w * 0.5, global_position.z - h * 0.5, w, h)

func tap(pos: Vector2, cam: Camera3D) -> void:
	var p: Plaque = Pick3D.plaque(tiles, cam, pos)
	if p == null:
		return
	p.press()
	if p.info != "":
		info.emit(p.info)
		return
	chosen.emit(p.key)