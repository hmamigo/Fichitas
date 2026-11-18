class_name StationAlbum
extends Node3D
## Mesa del álbum: una sola mesa larga con una sección por materia. Cada sección lleva
## una loseta de cabecera (nombre, dominadas, barra) y las parejas como fichas iguales
## a las del juego, de dos en dos: boca arriba si están dominadas, boca abajo si no.
## Se recorre con la cámara (paneo vertical), igual que la mesa de materias.

signal opened(pair: Dictionary)   # tocó una pareja dominada: {id, a, b, fact, stage}

const COLS := 6                  # fichas por fila (3 parejas)
const PITCH := 0.9               # casilla de cada ficha en el mundo
const HEAD_H := 1.2              # alto de la cabecera de cada materia
const HEAD_GAP := 0.22           # aire entre la cabecera y sus fichas
const SEC_GAP := 0.5             # aire entre secciones
const PX := 133                  # píxeles de la cara horneada por unidad del mundo
const TILT := 0.17               # igual que la cámara del tablero
const HY := 0.065                # grosor y cara de la ficha: los mismos que en Board
const FACE := 0.425

# Encuadre de la cámara en esta mesa
const FIT_PAD_W := 0.4           # aire a los lados de la mesa al encuadrar el ancho
const FIT_VIEW_H := 8.0          # alto mínimo que debe caber en pantalla
const FIT_MARGIN := 1.2          # alejamiento sobre el ajuste justo (1.0 = justo)
const PAN_PAD_X := 0.10
const PAN_PAD_Y := 0.11          # aire arriba y abajo al recorrer (fracción del alto visible)

var tiles: Array = []            # AlbumTile
var _heads: Array = []           # FlatLabel (planos: no se tocan)
var _table: Node3D
var _height: float = 0.0         # alto total de las secciones (sin marco)
var _shared: Dictionary = {}

## `data`: Array de {id, name, icon, color, locked, pairs: [{id, a, b, fact, stage}]}.
func build(data: Array) -> void:
	clear()
	if data.is_empty():
		return
	_ensure_shared()
	var w: float = float(COLS) * PITCH
	var rows_of: Array = []
	var total: float = 0.0
	for d in data:
		var n: int = ((d as Dictionary)["pairs"] as Array).size() * 2
		var rows: int = ceili(float(n) / float(COLS))
		rows_of.append(rows)
		total += HEAD_H + SEC_GAP
		if rows > 0:
			total += HEAD_GAP + float(rows) * PITCH
	total -= SEC_GAP
	_height = total
	_table = TileLook.table(self, w + 0.5, total + 0.5)
	var views: Array = []
	var z: float = -total * 0.5
	var order: int = 0
	var fw: int = int(w * float(PX))
	var fh: int = int(HEAD_H * float(PX))
	for s in data.size():
		var d: Dictionary = data[s]
		var pairs: Array = d["pairs"]
		var locked: bool = bool(d.get("locked", false))
		var dom: int = 0
		for q in pairs:
			if int((q as Dictionary)["stage"]) == 2:
				dom += 1
		var head := FlatLabel.new()
		head.setup(Vector2(w, HEAD_H))
		head.position.z = z + HEAD_H * 0.5
		add_child(head)
		var face_d: Dictionary = d.duplicate()
		face_d["sub"] = "De pago" if locked else "Dominadas %d de %d" % [dom, pairs.size()]
		face_d["frac"] = -1.0 if (locked or pairs.is_empty()) else float(dom) / float(pairs.size())
		head.bake(Cards.label(face_d, fw, fh), fw, fh)
		head.pop_in(minf(0.02 * float(order), 0.8))
		views.append_array(head.views())
		_heads.append(head)
		z += HEAD_H
		if int(rows_of[s]) > 0:
			z += HEAD_GAP
			for k in pairs.size():
				var pr: Dictionary = pairs[k]
				var up: bool = int(pr["stage"]) == 2
				for side in 2:
					var i: int = k * 2 + side
					var t := AlbumTile.new()
					t.setup(_shared, pr["a"] if side == 0 else pr["b"], up, PITCH, pr)
					var col: int = i % COLS
					var row: int = floori(float(i) / float(COLS))
					t.position = Vector3(
						(float(col) - float(COLS - 1) * 0.5) * PITCH,
						AlbumTile.REST,
						z + (float(row) + 0.5) * PITCH)
					add_child(t)
					order += 1
					t.pop_in(minf(0.012 * float(order), 0.8))
					tiles.append(t)
			z += float(rows_of[s]) * PITCH
		z += SEC_GAP
		order += 1
	FaceTex.settle(views)

func clear() -> void:
	for t in tiles:
		(t as Node).queue_free()
	tiles.clear()
	for h in _heads:
		(h as Node).queue_free()
	_heads.clear()
	if _table != null:
		_table.queue_free()
		_table = null
	_height = 0.0

## Mallas y materiales de la ficha, iguales a los de Board (se crean una sola vez).
func _ensure_shared() -> void:
	if not _shared.is_empty():
		return
	_shared = {
		"body": TileMesh.slab(0.49, 0.49, 0.16, HY * 2.0, 0.03, 5, 8),
		"face": TileMesh.face(FACE, HY + 0.003, true),
		"back": TileMesh.face(FACE, -HY - 0.003, false),
		"gold": TileLook.gold_material(TileLook.bezel_texture()),
		"back_mat": TileLook.face_material(TileLook.back_texture()),
	}

## Distancia de cámara para que quepa el ancho de la mesa.
func fit_distance() -> float:
	var need := Vector2(float(COLS) * PITCH + FIT_PAD_W, FIT_VIEW_H)
	return CamView.distance_for(get_viewport(), need) * FIT_MARGIN

## Cuánto se puede desplazar la cámara sin perder de vista la mesa.
func pan_bounds(dist: float) -> Vector2:
	if _height <= 0.0:
		return Vector2.ZERO
	var view: Vector2 = CamView.visible_size(get_viewport(), dist)
	var w: float = float(COLS) * PITCH + 0.5
	var h: float = _height + 0.5
	var extra: float = view.y * PAN_PAD_Y
	return Vector2(maxf((w - view.x) * 0.5 + PAN_PAD_X, 0.0), maxf((h - view.y) * 0.5 + extra, 0.0))

## Desplazamiento inicial: empezar por la primera materia (arriba de la mesa).
func initial_z(dist: float) -> float:
	return -pan_bounds(dist).y

## Zona libre del suelo bajo la mesa, en coordenadas del mundo.
func clear_rect() -> Rect2:
	if _height <= 0.0:
		return Rect2()
	var w: float = float(COLS) * PITCH + 0.7
	var h: float = _height + 0.7
	return Rect2(global_position.x - w * 0.5, global_position.z - h * 0.5, w, h)

func tap(pos: Vector2, cam: Camera3D) -> void:
	var n: Node3D = Pick3D.item(tiles, cam, pos)
	if n == null:
		return
	var t: AlbumTile = n as AlbumTile
	t.press()
	if t.mastered:
		opened.emit(t.pair)
