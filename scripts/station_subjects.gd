class_name StationSubjects
extends Node3D
## Mesa de materias: losetas planas en dos columnas fijas. La lista es más alta
## que la pantalla en un móvil, así que se recorre con la cámara (paneo), no con
## un ScrollContainer.

signal chosen(id: String)      # "" = recorrido general, ":review" = repaso
signal info(text: String)      # materia bloqueada: aviso para la interfaz

const CARD_W := 1.6
const CARD_H := 1.232          # 345 / 448: la misma proporción que la cara
const GAP := 0.22
const COLS := 2
const TILT := 0.17             # igual que la cámara del tablero
const FACE_W := 448
const FACE_H := 345

var tiles: Array = []
var _table: Node3D

## `cards`: los mismos diccionarios que usaba la pantalla 2D de materias.
func build(cards: Array) -> void:
	clear()
	var n: int = cards.size()
	if n == 0:
		return
	var rows: int = ceili(float(n) / float(COLS))
	var w: float = float(COLS) * CARD_W + float(COLS - 1) * GAP
	var h: float = float(rows) * CARD_H + float(rows - 1) * GAP
	_table = TileLook.table(self, w + 0.5, h + 0.5)
	var views: Array = []
	for i in n:
		var d: Dictionary = cards[i]
		var p := Plaque.new()
		p.setup(Vector2(CARD_W, CARD_H), str(d["id"]), str(d.get("info", "")))
		p.position.x = (float(i % COLS) - float(COLS - 1) * 0.5) * (CARD_W + GAP)
		p.position.z = (float(int(i / COLS)) - float(rows - 1) * 0.5) * (CARD_H + GAP)
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

## Distancia de cámara para que quepan las dos columnas (y al menos dos filas).
func fit_distance() -> float:
	var vp: Viewport = get_viewport()
	var ar: float = 0.5625
	var fov: float = 35.0
	if vp != null:
		var r: Vector2 = vp.get_visible_rect().size
		ar = r.x / maxf(r.y, 1.0)
		var cam: Camera3D = vp.get_camera_3d()
		if cam != null:
			fov = cam.fov
	var tn: float = tan(deg_to_rad(fov * 0.5))
	var w: float = float(COLS) * CARD_W + float(COLS - 1) * GAP + 0.15
	var by_w: float = w / (ar * 2.0 * tn)
	var by_h: float = (2.6 * CARD_H) / (2.0 * tn)
	return maxf(by_w, by_h) * 1.02

## Cuánto se puede desplazar la cámara sin perder de vista la mesa.
func pan_bounds(dist: float) -> Vector2:
	var vp: Viewport = get_viewport()
	var ar: float = 0.5625
	var fov: float = 35.0
	if vp != null:
		var r: Vector2 = vp.get_visible_rect().size
		ar = r.x / maxf(r.y, 1.0)
		var cam: Camera3D = vp.get_camera_3d()
		if cam != null:
			fov = cam.fov
	var tn: float = tan(deg_to_rad(fov * 0.5))
	var view := Vector2(dist * tn * ar, dist * tn) * 2.0
	var n: int = tiles.size()
	if n == 0:
		return Vector2.ZERO
	var rows: int = ceili(float(n) / float(COLS))
	var w: float = float(COLS) * CARD_W + float(COLS - 1) * GAP + 0.5
	var h: float = float(rows) * CARD_H + float(rows - 1) * GAP + 0.5
	# Un poco de aire arriba (la cabecera 2D) y abajo al recorrer la lista
	var extra: float = view.y * 0.11
	return Vector2(maxf((w - view.x) * 0.5 + 0.10, 0.0), maxf((h - view.y) * 0.5 + extra, 0.0))

## Desplazamiento inicial: empezar por la primera fila (arriba de la mesa).
func initial_z(dist: float) -> float:
	return -pan_bounds(dist).y

## Zona libre del suelo bajo la mesa, en coordenadas del mundo.
func clear_rect() -> Rect2:
	if tiles.is_empty():
		return Rect2()
	var rows: int = ceili(float(tiles.size()) / float(COLS))
	var w: float = float(COLS) * CARD_W + float(COLS - 1) * GAP + 0.7
	var h: float = float(rows) * CARD_H + float(rows - 1) * GAP + 0.7
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