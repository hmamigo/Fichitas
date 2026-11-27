class_name StationMode
extends Node3D
## Estación "¿Cómo quieres jugar?": una mesa entre materias y tablero con dos losetas
## grandes (Memoria y Asociación). La cámara llega hasta acá después de elegir una
## materia o el recorrido general, y la partida empieza recién al tocar una loseta.
## Así el menú queda solo para elegir qué jugar y no mezcla los modos.

signal chosen(mode: String)
signal sfx(name: String)

const CARD_W := Cards.TILE_W
const CARD_H := Cards.ACTION_H
const GAP := Cards.TILE_GAP
const FACE_W := int(CARD_W * Cards.PX)
const FACE_H := int(CARD_H * Cards.PX)
const TILT := 0.17             # igual que la cámara del tablero

# Encuadre de la cámara en esta mesa: las dos losetas, sin que toquen los bordes.
const FIT_PAD_W := 2.6         # aire a los lados (la mesa completa mide 4,5 de ancho)
const FIT_PAD_H := 2.0         # aire arriba y abajo

const LABEL_H := 1.0           # rótulo plano con el título (no se toca)

var tiles: Array = []
var labels: Array = []
var _table: Node3D
var _height: float = 0.0

## `last_mode` queda disponible para el día que se quiera destacar el último modo,
## pero tocar una loseta ya elige y arranca: por eso no se marca ninguna como activa.
## `title`: {name, sub, icon, color, ink} del rótulo que va arriba de las dos losetas (opcional).
func build(last_mode: String = "mem", title: Dictionary = {}) -> void:
	clear()
	var defs: Array = [
		{"key": "mem", "title": "Memoria", "sub": "Fichas boca abajo",
			"icon": "cerebro", "bg": UiTheme.LAVENDER, "ink": UiTheme.INK},
		{"key": "assoc", "title": "Asociación", "sub": "Fichas a la vista",
			"icon": "dialogo", "bg": UiTheme.MINT, "ink": UiTheme.INK},
	]
	var head: float = (LABEL_H + GAP) if not title.is_empty() else 0.0
	_height = float(defs.size()) * CARD_H + float(defs.size() - 1) * GAP + head
	_table = TileLook.table(self, CARD_W + 0.55, _height + 0.55)
	var views: Array = []
	var z0: float = -_height * 0.5
	if not title.is_empty():
		var lb := FlatLabel.make(self, Vector2(CARD_W, LABEL_H), title, 0.0)
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
	if _table != null:
		_table.queue_free()
		_table = null
	_height = 0.0

## Distancia de cámara a la que caben las dos losetas con aire alrededor.
func fit_distance() -> float:
	var need := Vector2(CARD_W + FIT_PAD_W, _height + FIT_PAD_H)
	return CamView.distance_for(get_viewport(), need)

## Zona libre del suelo bajo la mesa, en coordenadas del mundo (la mesa es el origen).
func clear_rect() -> Rect2:
	if tiles.is_empty():
		return Rect2()
	var w: float = CARD_W + 0.7
	var h: float = _height + 0.7
	return Rect2(global_position.x - w * 0.5, global_position.z - h * 0.5, w, h)

func tap(pos: Vector2, cam: Camera3D) -> void:
	var p: Plaque = Pick3D.plaque(tiles, cam, pos)
	if p == null:
		return
	p.press()
	sfx.emit("tap")
	chosen.emit(p.key)
