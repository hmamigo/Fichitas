class_name StationWin
extends Node3D
## Estación de "Nivel completado": una mesa a la derecha del tablero. La cabecera (trofeo y
## mensaje) va plana sobre la mesa, porque no se toca; las parejas se muestran como en el
## álbum (dos fichas juntas, boca arriba si están dominadas y boca abajo si no) y la única
## loseta con relieve es el botón de seguir. La cámara viaja hasta aquí al ganar y vuelve
## al tablero al seguir.

signal next
signal sfx(name: String)

const CARD_W := 3.5
const GAP := 0.18
const BTN_GAP := 0.26          # más aire antes de la acción principal
const PPU := 128               # píxeles de diseño por unidad del mundo (como el menú)
const HEAD_H := 1.75           # cabecera con mensaje corto (una línea)
const HEAD_H_LONG := 2.15      # mensaje largo (dos o tres líneas)
const HEAD_LONG_CHARS := 32    # a partir de aquí el mensaje no entra en una línea
const BTN_H := 0.82            # la acción principal, más baja: no compite con las fichas
const BOTTOM_PAD := 0.18       # aire extra bajo el botón: la vista inclinada achica el borde cercano
const LOOK_Y := -0.2           # punto de mira algo bajo el origen: la mesa queda centrada

# Fichas de las parejas: las mismas del álbum, algo más chicas para que entren dos
# parejas (cuatro fichas) por fila en esta mesa.
const TILE_PITCH := 0.82
const TILE_GAP := 0.10
const PAIR_GAP := 0.20         # aire entre parejas: dentro de la pareja van juntas
const PAIR_COLS := 2           # parejas por fila
const MORE_PX := 512           # resolución de la cara "+N" de las parejas que no entran

# Encuadre de la cámara
const FIT_PAD_W := 1.3         # aire a los lados (la loseta dorada crece ×1,05 y asoma su lámina)
const FIT_PAD_H := 0.9         # aire arriba y abajo al encuadrar la pila entera
const PAN_PAD_X := 0.10
const PAN_PAD_Y := 0.11

var tiles: Array = []          # Plaque: solo el botón de seguir
var pairs: Array = []          # AlbumTile: las parejas, boca arriba si están dominadas
var labels: Array = []         # FlatLabel: la cabecera, plana
var title: String = ""
var dom_count: int = 0
var _table: Node3D
var _height: float = 0.0
var _shared: Dictionary = {}

## `data`: {title, msg, button, doms}; cada `doms[i]` es {a, b, stage, up} o {more: N}.
func build(data: Dictionary) -> void:
	clear()
	title = str(data.get("title", ""))
	var doms: Array = data.get("doms", [])
	dom_count = int(data.get("total", doms.size()))
	var w: int = int(CARD_W * PPU)
	var k: int = Cards.WIN_K
	var msg: String = str(data.get("msg", ""))
	# La cabecera se ajusta al mensaje: con una línea no necesita el alto de tres.
	var head_h: float = HEAD_H_LONG if msg.length() > HEAD_LONG_CHARS else HEAD_H
	var head_px: int = int(round(head_h * PPU))
	var btn_px: int = int(round(BTN_H * PPU))
	var grid_h: float = _pair_grid_h(doms)
	# Aire entre cabecera, fichas y botón; si no hay fichas, solo entre cabecera y botón.
	_height = head_h + BTN_H + grid_h + GAP + BOTTOM_PAD
	if not doms.is_empty():
		_height += BTN_GAP
	_table = TileLook.table(self, CARD_W + 0.5, _height + 0.5)
	var views: Array = []
	var z: float = -_height * 0.5
	var head := FlatLabel.new()
	head.setup(Vector2(CARD_W, head_h))
	head.position.z = z + head_h * 0.5
	add_child(head)
	head.bake(Cards.win_header(title, msg, w, head_px), w * k, head_px * k)
	head.pop_in(0.55)   # aparece cuando la cámara llega
	views.append_array(head.views())
	labels.append(head)
	z += head_h + GAP
	if not doms.is_empty():
		_build_pairs(doms, z, views)
		z += grid_h + BTN_GAP
	var pl := Plaque.new()
	pl.setup(Vector2(CARD_W, BTN_H), "next")
	pl.position.z = z + BTN_H * 0.5
	add_child(pl)
	pl.bake(Cards.win_button(str(data.get("button", "Seguir")), w, btn_px), w * k, btn_px * k)
	pl.set_selected(true, true)   # la acción principal brilla
	pl.pop_in(0.69 if doms.is_empty() else 0.83)
	views.append_array(pl.views())
	tiles.append(pl)
	FaceTex.settle(views)

## Alto de la cuadrícula de parejas (dos fichas juntas por pareja). La ficha "+N", si
## aparece, va en su propia fila.
func _pair_grid_h(doms: Array) -> float:
	if doms.is_empty():
		return 0.0
	var n: int = 0
	var more: bool = false
	for d in doms:
		if (d as Dictionary).has("more"):
			more = true
		else:
			n += 1
	var rows: int = ceili(float(n) / float(PAIR_COLS)) + (1 if more else 0)
	return float(rows) * TILE_PITCH + float(rows - 1) * TILE_GAP

## Coloca las parejas como en el álbum: las dos fichas juntas y más aire entre parejas.
## Una pareja dominada va boca arriba; la que todavía no se aprendió, boca abajo.
## La última fila se centra si queda incompleta.
func _build_pairs(doms: Array, top: float, views: Array) -> void:
	_shared = AlbumTile.shared()
	var rows: Array = []
	var row: Array = []
	var more: Dictionary = {}
	for d in doms:
		if (d as Dictionary).has("more"):
			more = d
		else:
			row.append(d)
			if row.size() == PAIR_COLS:
				rows.append(row)
				row = []
	if not row.is_empty():
		rows.append(row)
	if not more.is_empty():
		rows.append([more])
	var order: int = 0
	for r in rows.size():
		var items: Array = rows[r]
		var z: float = top + (float(r) + 0.5) * TILE_PITCH + float(r) * TILE_GAP
		if items.size() == 1 and (items[0] as Dictionary).has("more"):
			_place_more(items[0], z, order, views)
			order += 1
			continue
		var k: int = items.size()
		var row_w: float = float(k) * (2.0 * TILE_PITCH) + float(k - 1) * PAIR_GAP
		for j in k:
			var d: Dictionary = items[j]
			var cx: float = -row_w * 0.5 + TILE_PITCH + float(j) * (2.0 * TILE_PITCH + PAIR_GAP)
			var up: bool = int(d.get("stage", 0)) == 2
			for side in 2:
				var x: float = cx + (float(side) - 0.5) * TILE_PITCH
				_place_pair_tile(d, side, up, x, z, order, views)
				order += 1

## Ficha de una pareja: `side` 0 es la imagen `a`, 1 es la `b`.
func _place_pair_tile(d: Dictionary, side: int, up: bool, x: float, z: float, order: int, views: Array) -> void:
	var t := AlbumTile.new()
	t.setup(_shared, d["a"] if side == 0 else d["b"], up, TILE_PITCH, d)
	t.position = Vector3(x, AlbumTile.REST, z)
	add_child(t)
	t.pop_in(0.55 + minf(0.025 * float(order), 0.45))
	pairs.append(t)

## Ficha resumen de las parejas que no entran. Su cara "+N" cuelga de la ficha, así
## que se libera con ella al limpiar.
func _place_more(d: Dictionary, z: float, order: int, views: Array) -> void:
	var t := AlbumTile.new()
	var vp := FaceTex.render(t, Cards.more_face(int(d["more"]), MORE_PX), MORE_PX, MORE_PX)
	var tex: Texture2D = null
	if vp != null:
		tex = vp.get_texture()
		views.append(vp)
	t.setup(_shared, tex, true, TILE_PITCH, d)
	t.position = Vector3(0.0, AlbumTile.REST, z)
	add_child(t)
	t.pop_in(0.55 + minf(0.025 * float(order), 0.45))
	pairs.append(t)

func clear() -> void:
	for t in tiles:
		(t as Node).queue_free()
	tiles.clear()
	for p in pairs:
		(p as Node).queue_free()
	pairs.clear()
	for l in labels:
		(l as Node).queue_free()
	labels.clear()
	if _table != null:
		_table.queue_free()
		_table = null
	_height = 0.0
	title = ""
	dom_count = 0

## Distancia de cámara a la que cabe la pila entera de losetas.
func fit_distance() -> float:
	var need := Vector2(CARD_W + FIT_PAD_W, maxf(_height, 1.0) + FIT_PAD_H)
	return CamView.distance_for(get_viewport(), need)

## Cuánto se puede desplazar la cámara sin perder de vista la mesa (solo al acercar).
func pan_bounds(dist: float) -> Vector2:
	if tiles.is_empty():
		return Vector2.ZERO
	var view: Vector2 = CamView.visible_size(get_viewport(), dist)
	var w: float = CARD_W + 0.5
	var h: float = _height + 0.5
	return Vector2(maxf((w - view.x) * 0.5 + PAN_PAD_X, 0.0) if w > view.x else 0.0,
		maxf((h - view.y) * 0.5 + view.y * PAN_PAD_Y, 0.0) if h > view.y else 0.0)

## Zona libre del suelo bajo la mesa, en coordenadas del mundo.
func clear_rect() -> Rect2:
	if tiles.is_empty():
		return Rect2()
	var w: float = CARD_W + 0.7
	var h: float = _height + 0.7
	return Rect2(global_position.x - w * 0.5, global_position.z - h * 0.5, w, h)

func tap(pos: Vector2, cam: Camera3D) -> void:
	var p: Plaque = Pick3D.plaque(tiles, cam, pos)
	if p != null and p.key == "next":
		p.press()
		sfx.emit("tap")
		next.emit()
