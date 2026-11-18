class_name StationSubjects
extends Node3D
## Mesas de materias: una mesa por grupo (Para todos, Peques, Exploradores, Nerds, Más), una
## debajo de otra, cada una con su rótulo plano arriba y sus losetas rectangulares en columna.
## La lista se recorre con la cámara (paneo), no con un ScrollContainer.

signal chosen(id: String)      # "" = recorrido general, ":review" = repaso
signal info(text: String)      # materia bloqueada: aviso para la interfaz

const CARD_W := 3.5
const CARD_H := 1.75
const LABEL_H := 1.0           # rótulo plano del grupo (no se toca)
const GAP := 0.18
const TABLE_GAP := 1.5         # entre mesas (el marco sobresale 0,225 por lado)
const TILT := 0.17             # igual que la cámara del tablero
const FACE_W := 448
const FACE_H := 224
const FACE_LABEL_H := 128      # LABEL_H × 128 px por unidad

# Encuadre de la cámara en esta mesa
const FIT_PAD_W := 0.15        # aire a los lados de la tarjeta al encuadrar el ancho
const FIT_ROWS := 2.6          # filas (en alto de tarjeta) que deben caber en pantalla
const FIT_MARGIN := 1.6        # alejamiento sobre el ajuste justo (1.0 = justo); a mano
const PAN_PAD_X := 0.10        # margen extra del paneo horizontal
const PAN_PAD_Y := 0.11        # aire arriba y abajo al recorrer (fracción del alto visible)

var tiles: Array = []          # Plaque: solo lo que se toca
var labels: Array = []         # FlatLabel: rótulos de grupo, planos
var _tables: Array = []
var _rects: Array = []         # zona de cada mesa en coordenadas locales (Rect2 sobre x/z)
var _height: float = 0.0       # alto total de todas las mesas y los huecos entre ellas

## `cards`: diccionarios de tarjeta. Uno con `header` abre un grupo nuevo (una mesa nueva)
## y lleva {name, sub, icon, color, ink, frame}; las tarjetas siguientes pertenecen a ese grupo.
func build(cards: Array) -> void:
	clear()
	if cards.is_empty():
		return
	var groups: Array = []
	for d in cards:
		if bool((d as Dictionary).get("header", false)):
			groups.append({"head": d, "cards": []})
		else:
			if groups.is_empty():
				groups.append({"head": {}, "cards": []})
			(groups[groups.size() - 1]["cards"] as Array).append(d)
	# Alto de cada mesa: rótulo (si lo hay) + tarjetas + el aire de la mesa
	var heights: Array = []
	var total: float = float(groups.size() - 1) * TABLE_GAP
	for g in groups:
		var n: int = (g["cards"] as Array).size()
		var content: float = float(n) * CARD_H + float(maxi(n - 1, 0)) * GAP
		if not (g["head"] as Dictionary).is_empty():
			content += LABEL_H + (GAP if n > 0 else 0.0)
		heights.append(content + 0.5)
		total += content + 0.5
	_height = total
	var views: Array = []
	var z: float = -total * 0.5
	var order: int = 0
	for gi in groups.size():
		var g: Dictionary = groups[gi]
		var th: float = heights[gi]
		var head: Dictionary = g["head"]
		var frame := Color(str(head.get("frame", "2f86d6")))
		var tb: Node3D = TileLook.table(self, CARD_W + 0.5, th, frame)
		tb.position.z = z + th * 0.5
		_tables.append(tb)
		_rects.append(Rect2(-(CARD_W + 0.7) * 0.5, z + th * 0.5 - (th + 0.2) * 0.5, CARD_W + 0.7, th + 0.2))
		var cz: float = z + 0.25    # el aire de 0,25 por arriba
		if not head.is_empty():
			var lb := FlatLabel.new()
			lb.setup(Vector2(CARD_W, LABEL_H))
			lb.position.z = cz + LABEL_H * 0.5
			add_child(lb)
			var ld: Dictionary = head.duplicate()
			ld["color"] = Color(str(head["color"]))
			ld["ink"] = Color(str(head["ink"]))
			lb.bake(Cards.label(ld, FACE_W, FACE_LABEL_H), FACE_W, FACE_LABEL_H)
			lb.pop_in(0.05 * float(order))
			views.append_array(lb.views())
			labels.append(lb)
			cz += LABEL_H + GAP
			order += 1
		for d in (g["cards"] as Array):
			var p := Plaque.new()
			p.setup(Vector2(CARD_W, CARD_H), str(d["id"]), str(d.get("info", "")))
			p.position.z = cz + CARD_H * 0.5
			cz += CARD_H + GAP
			add_child(p)
			p.bake(Cards.subject(d, FACE_W, FACE_H), FACE_W, FACE_H)
			p.pop_in(0.03 * float(order))
			order += 1
			views.append_array(p.views())
			tiles.append(p)
		z += th + TABLE_GAP
	FaceTex.settle(views)

func clear() -> void:
	for t in tiles:
		(t as Node).queue_free()
	tiles.clear()
	for l in labels:
		(l as Node).queue_free()
	labels.clear()
	for tb in _tables:
		(tb as Node).queue_free()
	_tables.clear()
	_rects.clear()
	_height = 0.0

## Distancia de cámara para que quepa la tarjeta (y se vean varias filas).
func fit_distance() -> float:
	var need := Vector2(CARD_W + FIT_PAD_W, FIT_ROWS * CARD_H)
	return CamView.distance_for(get_viewport(), need) * FIT_MARGIN

## Cuánto se puede desplazar la cámara sin perder de vista la mesa.
func pan_bounds(dist: float) -> Vector2:
	if tiles.is_empty():
		return Vector2.ZERO
	var view: Vector2 = CamView.visible_size(get_viewport(), dist)
	var w: float = CARD_W + 0.5
	var h: float = _height + 0.5
	# Un poco de aire arriba (la cabecera 2D) y abajo al recorrer la lista
	var extra: float = view.y * PAN_PAD_Y
	return Vector2(maxf((w - view.x) * 0.5 + PAN_PAD_X, 0.0), maxf((h - view.y) * 0.5 + extra, 0.0))

## Desplazamiento inicial: empezar por la primera fila (arriba de la mesa).
func initial_z(dist: float) -> float:
	return -pan_bounds(dist).y

## Zona libre del suelo bajo la mesa, en coordenadas del mundo.
func clear_rects() -> Array:
	var out: Array = []
	for r in _rects:
		var rr: Rect2 = r
		out.append(Rect2(global_position.x + rr.position.x, global_position.z + rr.position.y, rr.size.x, rr.size.y))
	return out

func tap(pos: Vector2, cam: Camera3D) -> void:
	var p: Plaque = Pick3D.plaque(tiles, cam, pos)
	if p == null:
		return
	p.press()
	if p.info != "":
		info.emit(p.info)
		return
	chosen.emit(p.key)
