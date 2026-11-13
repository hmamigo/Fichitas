class_name StationMenu
extends Node3D
## Mesa del menú: las cuatro acciones del menú como losetas 3D (modo memoria,
## modo asociación, elegir materia y recorrido general). El resto del menú
## (logotipo, título y ajustes) sigue siendo una capa 2D encima.

signal play_general
signal open_subjects
signal mode_changed(mode: String)

const CARD_W := 3.5
const CARD_H := 1.0
const GAP := 0.16
const FACE_W := 448
const FACE_H := 128

var tiles: Array = []
var _mode: String = "mem"
var _table: Node3D

func build(mode_now: String, level: int) -> void:
	clear()
	_mode = mode_now
	var defs: Array = [
		{"key": "mem", "title": "Memoria", "sub": "Fichas boca abajo", "icon": "", "dot": true, "bg": UiTheme.LAVENDER, "ink": UiTheme.INK},
		{"key": "assoc", "title": "Asociación", "sub": "Todas las fichas a la vista", "icon": "", "dot": true, "bg": UiTheme.MINT, "ink": UiTheme.INK},
		{"key": "subjects", "title": "Elegir materia", "sub": "Cada materia, sus niveles", "icon": "book_open", "dot": false, "bg": Color("dcecff"), "ink": UiTheme.BLUE_DARK},
		{"key": "general", "title": "Recorrido general", "sub": "Nivel %d" % level, "icon": "compass", "dot": false, "bg": Color("ffe1a0"), "ink": UiTheme.GOLD_INK},
	]
	var h: float = float(defs.size()) * CARD_H + float(defs.size() - 1) * GAP
	_table = TileLook.table(self, CARD_W + 0.55, h + 0.55)
	var views: Array = []
	for i in defs.size():
		var d: Dictionary = defs[i]
		var p := Plaque.new()
		p.setup(Vector2(CARD_W, CARD_H), str(d["key"]))
		p.position.z = (float(i) - float(defs.size() - 1) * 0.5) * (CARD_H + GAP)
		add_child(p)
		p.bake(Cards.action(str(d["title"]), str(d["sub"]), str(d["icon"]), bool(d["dot"]), d["bg"], d["ink"], FACE_W, FACE_H), FACE_W, FACE_H)
		p.set_selected(p.key == _mode, true)
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

## Cambia la loseta marcada sin reconstruir la mesa.
func set_mode(mode_now: String) -> void:
	_mode = mode_now
	for t in tiles:
		var p: Plaque = t
		if p.key == "mem" or p.key == "assoc":
			p.set_selected(p.key == _mode)

## Zona libre del suelo bajo la mesa, en coordenadas del mundo (la mesa es el origen).
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
	match p.key:
		"subjects":
			p.press()
			open_subjects.emit()
		"general":
			p.press()
			play_general.emit()
		"mem", "assoc":
			set_mode(p.key)
			p.press()
			mode_changed.emit(p.key)
