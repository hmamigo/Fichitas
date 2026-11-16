class_name StationMode
extends Node3D
## Estación "¿Cómo quieres jugar?": una mesa entre materias y tablero con dos losetas
## grandes (Memoria y Asociación). La cámara llega hasta acá después de elegir una
## materia o el recorrido general, y la partida empieza recién al tocar una loseta.
## Así el menú queda solo para elegir qué jugar y no mezcla los modos.

signal chosen(mode: String)

const CARD_W := 3.5
const CARD_H := 1.35
const GAP := 0.18
const FACE_W := 448
const FACE_H := 176
const TILT := 0.17             # igual que la cámara del tablero

# Encuadre de la cámara en esta mesa: las dos losetas, sin que toquen los bordes.
const FIT_PAD_W := 2.6         # aire a los lados (la mesa completa mide 4,5 de ancho)
const FIT_PAD_H := 2.0         # aire arriba y abajo

var tiles: Array = []
var _table: Node3D
var _height: float = 0.0

## `last_mode` queda disponible para el día que se quiera destacar el último modo,
## pero tocar una loseta ya elige y arranca: por eso no se marca ninguna como activa.
func build(last_mode: String = "mem") -> void:
	clear()
	var defs: Array = [
		{"key": "mem", "title": "Memoria", "sub": "Fichas boca abajo",
			"dot": true, "bg": UiTheme.LAVENDER, "ink": UiTheme.INK},
		{"key": "assoc", "title": "Asociación", "sub": "Fichas a la vista",
			"dot": true, "bg": UiTheme.MINT, "ink": UiTheme.INK},
	]
	_height = float(defs.size()) * CARD_H + float(defs.size() - 1) * GAP
	_table = TileLook.table(self, CARD_W + 0.55, _height + 0.55)
	var views: Array = []
	for i in defs.size():
		var d: Dictionary = defs[i]
		var p := Plaque.new()
		p.setup(Vector2(CARD_W, CARD_H), str(d["key"]))
		p.position.z = (float(i) - float(defs.size() - 1) * 0.5) * (CARD_H + GAP)
		add_child(p)
		p.bake(Cards.action(str(d["title"]), str(d["sub"]), "", bool(d["dot"]),
			d["bg"], d["ink"], FACE_W, FACE_H), FACE_W, FACE_H)
		p.pop_in(0.04 * float(i))
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
	chosen.emit(p.key)
