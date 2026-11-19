class_name StationWin
extends Node3D
## Estación de "Nivel completado": una mesa a la derecha del tablero. La cabecera (trofeo y
## mensaje) y las miniaturas de las parejas con su dominio van planas sobre la mesa, porque no
## se tocan; la única loseta con relieve es el botón de seguir. La cámara viaja hasta aquí al
## ganar y vuelve al tablero al seguir.

signal next

const CARD_W := 3.5
const GAP := 0.18
const PPU := 128               # píxeles de diseño por unidad del mundo (como el menú)
const HEAD_H := 2.1
const BTN_H := 1.0
const TILT := 0.17             # igual que la cámara del tablero

# Encuadre de la cámara
const FIT_PAD_W := 1.3         # aire a los lados (la loseta dorada crece ×1,05 y asoma su lámina)
const FIT_PAD_H := 0.9         # aire arriba y abajo al encuadrar la pila entera
const PAN_PAD_X := 0.10
const PAN_PAD_Y := 0.11

var tiles: Array = []          # Plaque: solo el botón de seguir
var labels: Array = []         # FlatLabel: cabecera y miniaturas, planas
var title: String = ""
var dom_count: int = 0
var _table: Node3D
var _height: float = 0.0

## `data`: {title, msg, button, doms}; cada `doms[i]` es {tex, stage, up}.
func build(data: Dictionary) -> void:
	clear()
	title = str(data.get("title", ""))
	var doms: Array = data.get("doms", [])
	dom_count = doms.size()
	var w: int = int(CARD_W * PPU)
	var k: int = Cards.WIN_K
	var parts: Array = []   # {key, h (unidades), face (Control), px, flat}
	var head_px: int = int(round(HEAD_H * PPU))
	parts.append({"key": "head", "h": float(head_px) / PPU, "px": head_px, "flat": true,
		"face": Cards.win_header(title, str(data.get("msg", "")), w, head_px)})
	if dom_count > 0:
		var dom_px: int = int(Cards.dom_layout(dom_count, w)["h"])
		parts.append({"key": "doms", "h": float(dom_px) / PPU, "px": dom_px, "flat": true, "face": Cards.win_doms(doms, w)})
	var btn_px: int = int(round(BTN_H * PPU))
	parts.append({"key": "next", "h": float(btn_px) / PPU, "px": btn_px, "flat": false,
		"face": Cards.win_button(str(data.get("button", "Seguir")), w, btn_px)})
	_height = GAP * float(parts.size() - 1)
	for p in parts:
		_height += float(p["h"])
	_table = TileLook.table(self, CARD_W + 0.5, _height + 0.5)
	var z: float = -_height * 0.5
	var views: Array = []
	for i in parts.size():
		var d: Dictionary = parts[i]
		var ph: float = float(d["h"])
		var delay: float = 0.55 + 0.14 * float(i)   # aparecen cuando la cámara llega
		if bool(d["flat"]):
			# Lo que no se toca va plano sobre la mesa; solo el botón es una loseta con relieve
			var fl := FlatLabel.new()
			fl.setup(Vector2(CARD_W, ph))
			fl.position.z = z + ph * 0.5
			add_child(fl)
			fl.bake(d["face"], w * k, int(d["px"]) * k)
			fl.pop_in(delay)
			views.append_array(fl.views())
			labels.append(fl)
		else:
			var pl := Plaque.new()
			pl.setup(Vector2(CARD_W, ph), str(d["key"]))
			pl.position.z = z + ph * 0.5
			add_child(pl)
			pl.bake(d["face"], w * k, int(d["px"]) * k)
			pl.set_selected(true, true)   # la acción principal brilla
			pl.pop_in(delay)
			views.append_array(pl.views())
			tiles.append(pl)
		z += ph + GAP
	FaceTex.settle(views)

func clear() -> void:
	for t in tiles:
		(t as Node).queue_free()
	tiles.clear()
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
		next.emit()
