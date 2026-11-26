class_name StationHelp
extends Node3D
## Estación "¿Cómo jugar?": una mesa a la izquierda del álbum con la explicación en
## cuatro pasos. Es solo información, así que todo va pintado plano sobre la mesa
## (`FlatLabel`, como en el álbum): la única acción es el botón "Atrás" de la capa 2D.
## La cámara viaja hasta acá desde el menú y vuelve al tocar "Atrás".

const CARD_W := 3.5
const PPU := 128               # píxeles de diseño por unidad del mundo
const TITLE_H := 1.5           # cabecera (icono, título y una línea)
const ROW_H := 1.14            # alto de cada paso
const GAP := 0.16              # aire entre cabecera y pasos, y entre pasos
const TILT := 0.17             # igual que la cámara del tablero

# Encuadre y desplazamiento: los mismos valores que la mesa de Materias (`StationSubjects`),
# así la ayuda se recorre igual: vertical, con zoom de dos dedos y recordando dónde quedó.
const FIT_PAD_W := 0.15        # aire a los lados de la mesa al encuadrar el ancho
const FIT_VIEW_H := 4.55       # alto que debe caber (2,6 tarjetas de 1,75, como Materias)
const FIT_MARGIN := 1.6        # alejamiento sobre el ajuste justo
const PAN_PAD_X := 0.10
const PAN_PAD_Y := 0.11        # aire arriba y abajo al recorrer (fracción del alto visible)

const DEMO_PITCH := 0.82        # ficha de ejemplo (igual que la victoria)
const DEMO_H := 0.9             # alto de una fila de demo
const BLUE := Color("3b82f6")

var labels: Array = []          # FlatLabel: cabecera y pasos (nada se toca)
var demos: Array = []           # AlbumTile: fichas de ejemplo animadas (tampoco se tocan)
var _loops: Array = []          # animaciones en bucle de las demos
var _shared: Dictionary = {}
var _table: Node3D
var _height: float = 0.0

## `pairs`: parejas {id, a, b} para las fichas de ejemplo (si faltan, se usan colores lisos).
func build(pairs: Array = []) -> void:
	clear()
	var rows: Array = [
		{"name": "1 · Elegí qué practicar", "sub": "Materia, recorrido general o repaso.",
			"icon": "cuaderno", "color": Color("4a8ff5")},
		{"name": "2 · Jugá en Memoria", "sub": "Destapá fichas y encontrá las parejas.",
			"icon": "cerebro", "color": Color("a78bfa"), "demo": "mem"},
		{"name": "3 · O jugá en Asociación", "sub": "Tocá una ficha y luego su pareja.",
			"icon": "dialogo", "color": Color("42cd84"), "demo": "assoc"},
		{"name": "4 · Recorré la mesa", "sub": "Deslizá y pellizcá para acercar.",
			"icon": "mobile_phone", "color": Color("42cd84")},
	]
	var n_demo: int = 2
	_height = TITLE_H + float(rows.size()) * ROW_H + float(n_demo) * DEMO_H \
		+ float(rows.size() + n_demo + 1) * GAP
	_table = TileLook.table(self, CARD_W + 0.5, _height + 0.5)
	_shared = AlbumTile.shared()
	var dp: Array = _demo_pairs(pairs)
	var views: Array = []
	var w: int = int(CARD_W * PPU)
	var k: int = Cards.HELP_K
	var z: float = -_height * 0.5
	var title_px: int = int(TITLE_H * PPU)
	var head := FlatLabel.new()
	head.setup(Vector2(CARD_W, TITLE_H))
	head.position.z = z + TITLE_H * 0.5
	add_child(head)
	head.bake(Cards.help_header("¿Cómo se juega?", "Elegí materia y modo.", w, title_px), w * k, title_px * k)
	head.pop_in(0.0)
	views.append_array(head.views())
	labels.append(head)
	z += TITLE_H + GAP
	var row_px: int = int(ROW_H * PPU)
	for i in rows.size():
		var d: Dictionary = rows[i]
		var lb := FlatLabel.new()
		lb.setup(Vector2(CARD_W, ROW_H))
		lb.position.z = z + ROW_H * 0.5
		add_child(lb)
		lb.bake(Cards.help_row(str(d["name"]), str(d["sub"]), str(d["icon"]), d["color"], w, row_px),
			w * k, row_px * k)
		lb.pop_in(0.04 * float(i + 1))
		views.append_array(lb.views())
		labels.append(lb)
		z += ROW_H + GAP
		if d.has("demo"):
			_add_demo(str(d["demo"]), dp, z + DEMO_H * 0.5)
			z += DEMO_H + GAP
	FaceTex.settle(views)
	_sync_loops()

## Dos parejas para las demos: las que pasa `main` o, si no hay, dos de colores lisos.
func _demo_pairs(pairs: Array) -> Array:
	if pairs.size() >= 2:
		return pairs.slice(0, 2)
	var out: Array = []
	for c in [[Color("ff9fcb"), Color("8ee3b0")], [Color("9cc8ff"), Color("ffd966")]]:
		out.append({"id": "d%d" % out.size(), "a": _solid(c[0]), "b": _solid(c[1])})
	return out

func _solid(c: Color) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

## Cuatro fichas en fila y una animación en bucle que muestra cómo se juega.
func _add_demo(kind: String, dp: Array, z: float) -> void:
	var p0: Dictionary = dp[0]
	var p1: Dictionary = dp[1]
	var mem: bool = kind == "mem"
	# memoria: [a0, a1, b0, b1] boca abajo; asociación: [a0, b1, a1, b0] a la vista
	var set: Array = []
	if mem:
		set = [[p0["a"], p0], [p1["a"], p1], [p0["b"], p0], [p1["b"], p1]]
	else:
		set = [[p0["a"], p0], [p1["b"], p1], [p1["a"], p1], [p0["b"], p0]]
	var ts: Array = []
	for i in 4:
		var t := AlbumTile.new()
		t.setup(_shared, set[i][0], not mem, DEMO_PITCH, set[i][1])
		t.position = Vector3((float(i) - 1.5) * (DEMO_PITCH + 0.06), AlbumTile.REST, z)
		add_child(t)
		t.pop_in(0.3 + 0.05 * float(i))
		ts.append(t)
		demos.append(t)
	var tw := create_tween().set_loops()
	tw.tween_interval(1.2)
	if mem:
		# 1) dos fichas distintas: no es pareja, se vuelven a tapar
		tw.tween_callback(func() -> void: ts[0].ping(BLUE); ts[0].flip_to(true))
		tw.tween_interval(0.8)
		tw.tween_callback(func() -> void: ts[1].ping(BLUE); ts[1].flip_to(true))
		tw.tween_interval(1.0)
		tw.tween_callback(func() -> void: ts[0].flip_to(false); ts[1].flip_to(false))
		tw.tween_interval(0.9)
		# 2) una ficha y su pareja: acierto
		tw.tween_callback(func() -> void: ts[0].ping(BLUE); ts[0].flip_to(true))
		tw.tween_interval(0.8)
		tw.tween_callback(func() -> void: ts[2].ping(BLUE); ts[2].flip_to(true))
		tw.tween_interval(0.7)
		tw.tween_callback(func() -> void: ts[0].celebrate(); ts[2].celebrate())
		tw.tween_interval(1.6)
		tw.tween_callback(func() -> void:
			for i in [0, 2]:
				ts[i].reset_state()
				ts[i].flip_to(false))
		tw.tween_interval(0.6)
	else:
		# 1) se elige una ficha y se toca otra que no es su pareja: tiembla
		tw.tween_callback(func() -> void: ts[0].ping(BLUE); ts[0].select(true))
		tw.tween_interval(0.9)
		tw.tween_callback(func() -> void: ts[1].ping(BLUE))
		tw.tween_interval(0.3)
		tw.tween_callback(func() -> void: ts[0].select(false); ts[0].shake(); ts[1].shake())
		tw.tween_interval(1.1)
		# 2) se elige la misma ficha y su pareja: acierto
		tw.tween_callback(func() -> void: ts[0].ping(BLUE); ts[0].select(true))
		tw.tween_interval(0.9)
		tw.tween_callback(func() -> void: ts[3].ping(BLUE))
		tw.tween_interval(0.3)
		tw.tween_callback(func() -> void: ts[0].celebrate(); ts[3].celebrate())
		tw.tween_interval(1.8)
		tw.tween_callback(func() -> void: ts[0].reset_state(); ts[3].reset_state())
	_loops.append(tw)

## Las animaciones solo corren mientras la mesa se ve (no gastan nada en las demás estaciones).
func _sync_loops() -> void:
	for tw in _loops:
		if (tw as Tween).is_valid():
			if is_visible_in_tree():
				(tw as Tween).play()
			else:
				(tw as Tween).pause()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_sync_loops()

func clear() -> void:
	for tw in _loops:
		if (tw as Tween).is_valid():
			(tw as Tween).kill()
	_loops.clear()
	for t in demos:
		(t as Node).queue_free()
	demos.clear()
	for l in labels:
		(l as Node).queue_free()
	labels.clear()
	if _table != null:
		_table.queue_free()
		_table = null
	_height = 0.0

## Distancia de cámara para que quepa el ancho de la mesa (como en Materias).
func fit_distance() -> float:
	var need := Vector2(CARD_W + FIT_PAD_W, FIT_VIEW_H)
	return CamView.distance_for(get_viewport(), need) * FIT_MARGIN

## Cuánto se puede desplazar la cámara sin perder de vista la mesa.
func pan_bounds(dist: float) -> Vector2:
	if labels.is_empty():
		return Vector2.ZERO
	var view: Vector2 = CamView.visible_size(get_viewport(), dist)
	var w: float = CARD_W + 0.5
	var h: float = _height + 0.5
	var extra: float = view.y * PAN_PAD_Y
	return Vector2(maxf((w - view.x) * 0.5 + PAN_PAD_X, 0.0), maxf((h - view.y) * 0.5 + extra, 0.0))

## Desplazamiento inicial: empezar por arriba (la cabecera).
func initial_z(dist: float) -> float:
	return -pan_bounds(dist).y

## Zona libre del suelo bajo la mesa, en coordenadas del mundo (la mesa es el origen).
func clear_rect() -> Rect2:
	if labels.is_empty():
		return Rect2()
	var w: float = CARD_W + 0.7
	var h: float = _height + 0.7
	return Rect2(global_position.x - w * 0.5, global_position.z - h * 0.5, w, h)
