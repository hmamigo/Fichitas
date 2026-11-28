class_name Board
extends Node3D
## Tablero 3D: escena, cámara casi cenital (zoom y paneo, sin rotación), entrada táctil/ratón
## y reglas de los dos modos ("mem" = memoria, "assoc" = asociación).

signal won
signal pair_done(pair_id: String, clean: bool)
signal sfx(sound: String)  # "flip", "tap", "ok", "err", "win"

const ST := 1.12      # separación entre fichas
const TITLE_H := 0.9  # franja de la mesa con el título de la partida (rótulo plano, no se toca)
const TITLE_PPU := 128  # píxeles por unidad del mundo al hornear la franja del título
const TILT := 0.35     # inclinación de la cámara en radianes (0,3 ≈ 17°), igual en todas las estaciones
const FOV := 35.0
const MENU_DIST := 20.0   # distancia de la cámara en el menú: las 3 losetas (alto ≈ 4,3) ocupan ~1/3 del alto visible; calibrada a mano
# Las estaciones van en fila a lo largo de X: ayuda, álbum, menú, materias, temas, modo, tablero
# (en el origen) y victoria. Materias -> temas -> modo avanzan siempre hacia la derecha.
# El tablero apaisado de PC puede medir ~11 de ancho (±5,5): la mesa del modo queda a −9 para no
# tocarlo durante el vuelo, y de ahí hacia la izquierda las estaciones van de 10 en 10.
const STATION_GAP := 10.0
const MODE_X := -0.9 * STATION_GAP    # modo: a la izquierda del tablero
const THEMES_X := -1.5 * STATION_GAP  # temas de una materia: a la izquierda del modo
const SUBJ_X := -2.1 * STATION_GAP    # materias: a la izquierda de los temas (mismos 6 que modo y temas)
const MENU_X := -3.1 * STATION_GAP    # menú: a la izquierda de las materias
const ALBUM_X := -4.1 * STATION_GAP   # álbum: a la izquierda del menú
const HELP_X := -5.1 * STATION_GAP    # cómo jugar: a la izquierda del álbum
const WIN_X := STATION_GAP            # nivel completado: a la derecha del tablero
const MENU_LOOK_Y := -0.2             # altura del punto de mira del menú
const MENU_LOOK_DZ := -0.2            # z de partida; `center_menu` la ajusta al hueco 2D
# Vuelos largos entre estaciones: la cámara se aleja un poco a mitad de camino (0 = sin arco)
const ARC_GAIN := 0.15        # fracción del recorrido que se suma a la distancia en el punto medio
const ARC_MAX := 3.0
const ARC_MIN_TRAVEL := 4.0   # por debajo (p. ej. entre niveles) no hay arco
const HY := 0.065     # mitad del grosor de la ficha
const FACE := 0.425   # semiancho de la cara con la imagen
const REST_Y := 0.06   # altura de las fichas pendientes: separadas de la losa
const MATCH_Y := -0.09  # las resueltas se hunden en la losa
const FLASH_Y := 0.15      # altura del destello sobre las fichas pendientes
const MATCH_ALPHA := 0.68  # opacidad de las fichas resueltas (un poco translúcidas)
# Iluminación (ajustable en pruebas con las flechas ↑ ↓ del teclado; el valor sale en la consola)
const LIGHT_ENERGY := 0.28#0.30    # luz direccional principal
const FILL_ENERGY := 0.1     # luz de relleno (sin sombras)
const AMBIENT_ENERGY := 0.18#0.20  # luz ambiental
const SKY_ENERGY := 16#0.20      # brillo del entorno (reflejos)
const CLEARCOAT := 0.8        # barniz de las caras
# Chispas al emparejar (ajustables)
const MOBILE_SCALE_3D := 0.75   # en móvil el 3D se dibuja a esta fracción de la resolución; la interfaz (2D) sigue nítida
const SHADOW_REACH := 7.0      # hasta dónde llegan las sombras desde la mesa que mira la cámara: menos alcance, texeles más finos
const FIT_ROWS := 3.5          # filas de fichas que se ven a la vez al empezar una ronda (la cuarta asoma: invita a deslizar)
const PAN_PAD_Y := 0.12#0.08        # aire arriba y abajo al recorrer el tablero (fracción del alto visible)
const GLIDE_SECS := 0.45      # lo que tarda la cámara en volver a la primera fila al pasar de ronda
const SPARK_AMOUNT := 22       # estrellas por ficha
const SPARK_LIFE := 0.80       # segundos que viven
const SPARK_SIZE := 0.24       # lado de cada estrella
const SPARK_GOLD := Color("ffb400")   # dorado intenso: se distingue sobre las fichas claras
const SPARK_ORANGE := Color("ff8a00")  # al apagarse
const SPARK_PALE := Color("fffdf2")

class Tile:
	var node: Node3D
	var flip: Node3D
	var body_mat: StandardMaterial3D
	var face_mat: StandardMaterial3D
	var back_mat: StandardMaterial3D
	var halo: MeshInstance3D = null
	var pair: String = ""
	var up: bool = false
	var seen: bool = false
	var matched: bool = false
	var home: Vector3 = Vector3.ZERO

var mode: String = "mem"
var active: bool = false
var blockers: Array = []   # controles de interfaz que no deben dejar pasar toques al tablero
var station: String = "menu"  # "menu", "subjects", "themes", "mode", "album", "help", "game" o "win"
var menu_look_z: float = MENU_LOOK_DZ  # lo ajusta `center_menu` según la franja 2D
var menu_station: StationMenu
var subject_station: StationSubjects
var theme_station: StationSubjects   # los temas de una materia con temas: su propia mesa, a la derecha de las materias
var mode_station: StationMode
var album_station: StationAlbum
var help_station: StationHelp
var win_station: StationWin
var game_title: Dictionary = {}   # {name, sub, icon, color}: rótulo sobre la mesa del tablero ({} = sin franja)
var progress_matched: int = 0     # parejas ya emparejadas en la partida actual
var progress_total: int = 0       # parejas del nivel (0 = sin contador)
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var ground_pad: MeshInstance3D
var ground_mesh: PlaneMesh
var light_scale: float = 1.0
var board: Node3D
var tiles: Array = []
var cols: int = 0
var rows: int = 0
var fit: float = 10.0
var zoom: float = 1.0
var floor_cubes: FloorCubes
var _fly: Tween
var _from: Dictionary = {}     # pose de la cámara al empezar un vuelo
var _title_label: FlatLabel    # franja del título, para actualizar el contador sin rehornear la mesa
var _view_mem: Dictionary = {} # "subjects"/"themes"/"album"/"help" -> {x, z, zoom}: dónde quedó cada lista
var _t: float = 1.0            # mezcla del vuelo (0 = origen, 1 = estación)
var _arc: float = 0.0          # alejamiento extra de la cámara a mitad del vuelo actual
var _settled: bool = true      # la cámara ya llegó: se puede tocar
var _pan_v: Vector2 = Vector2.ZERO  # inercia del arrastre, en píxeles por segundo
var cam_x: float = 0.0
var cam_z: float = 0.0
var lock: bool = false
var gen: int = 0
var revealed: Array = []
var err: Dictionary = {}
var sel: Tile = null
var _rounds: Array = []       # parejas de cada ronda del nivel (Levels.round_sizes)
var _round: int = 0            # ronda en curso
var _done_pairs: int = 0       # parejas de las rondas ya terminadas
var _glide: Tween              # deslizamiento de la cámara hacia la ronda nueva
var ptrs: Dictionary = {}
var press_tile: Tile = null
var press_start: Vector2 = Vector2.ZERO
var last_pos: Vector2 = Vector2.ZERO
var moved: bool = false
var pinch_d: float = 0.0
var back_tex: ImageTexture
var bezel_tex: ImageTexture
var spark_tex: ImageTexture
var spark_mesh: QuadMesh
var gold: StandardMaterial3D
var tile_body: ArrayMesh
var face_up: ArrayMesh
var face_down: ArrayMesh
var ring_mesh: ArrayMesh
var halo_mesh: ArrayMesh
var ground_mat: StandardMaterial3D
var far_mat: StandardMaterial3D
var fill: DirectionalLight3D

const FOG_COLOR := Color("b9d2ee")

## Color del suelo al borde de la pantalla: también es el fondo lejano de la escena.
func _ground_edge() -> Color:
	return Color("6f92bd")

func _ready() -> void:
	_make_textures()
	_build_environment()
	cam = Camera3D.new()
	cam.fov = FOV
	cam.near = 0.1
	cam.far = 200.0
	add_child(cam)
	cam.current = true
	tile_body = TileMesh.slab(0.49, 0.49, 0.16, HY * 2.0, 0.03, 5, 8)
	face_up = TileMesh.face(FACE, HY + 0.003, true)
	face_down = TileMesh.face(FACE, -HY - 0.003, false)
	# Destello y halo con la silueta de la ficha (losa de 0.49 y esquinas de 0.16, desplazada 0.01)
	ring_mesh = TileMesh.ring(0.50, 0.74, 0.0, 8, 0.17)
	halo_mesh = TileMesh.ring(0.50, 0.565, 0.0, 8, 0.17)
	# Mesas de las otras dos estaciones del mundo (vacías hasta que main las vista)
	menu_station = StationMenu.new()
	menu_station.position = Vector3(MENU_X, 0.0, 0.0)
	add_child(menu_station)
	subject_station = StationSubjects.new()
	subject_station.position = Vector3(SUBJ_X, 0.0, 0.0)
	add_child(subject_station)
	theme_station = StationSubjects.new()
	theme_station.position = Vector3(THEMES_X, 0.0, 0.0)
	add_child(theme_station)
	mode_station = StationMode.new()
	mode_station.position = Vector3(MODE_X, 0.0, 0.0)
	add_child(mode_station)
	album_station = StationAlbum.new()
	album_station.position = Vector3(ALBUM_X, 0.0, 0.0)
	add_child(album_station)
	help_station = StationHelp.new()
	help_station.position = Vector3(HELP_X, 0.0, 0.0)
	add_child(help_station)
	win_station = StationWin.new()
	win_station.position = Vector3(WIN_X, 0.0, 0.0)
	add_child(win_station)
	# Los toques en las estaciones también suenan (y vibran) como los del tablero
	for st in [menu_station, subject_station, theme_station, mode_station, album_station, win_station]:
		(st as Node).connect("sfx", Callable(self, "_relay_sfx"))
	get_viewport().size_changed.connect(_layout)

## Repite el sonido de una estación por la señal del tablero, que ya escucha `main`.
func _relay_sfx(name: String) -> void:
	sfx.emit(name)

# ---------- API ----------

func start(pairs: Array, pop_delay: float = 0.0) -> void:
	# El vuelo lo pide `main` antes de llamar aquí; si nadie lo hizo (pruebas), se salta.
	if station != "game" and _settled:
		fly_to_station("game", 0.0)
	gen += 1
	active = true
	err.clear()
	revealed.clear()
	sel = null
	lock = false
	progress_matched = 0
	progress_total = pairs.size()
	_done_pairs = 0
	_round = 0
	_rounds.clear()
	var at: int = 0
	for n in Levels.round_sizes(pairs.size()):
		_rounds.append(pairs.slice(at, at + n))
		at += n
	_build_round(pop_delay)

## Dibuja la ronda en curso: fichas barajadas, vista desde arriba y cascada de entrada.
func _build_round(pop_delay: float, glide: bool = false) -> void:
	_stop_glide()
	var from_x: float = cam_x
	var from_z: float = cam_z
	var from_zoom: float = zoom
	_clear_tiles()
	if _rounds.is_empty():
		return
	var items: Array = []
	for pr in _rounds[_round]:
		items.append({"id": pr["id"], "tex": pr["a"]})
		items.append({"id": pr["id"], "tex": pr["b"]})
	items.shuffle()
	for it in items:
		tiles.append(_make_tile(str(it["id"]), it["tex"]))
	zoom = 1.0
	cam_x = 0.0
	_layout()
	var top: float = -_game_bounds(fit).y   # empieza por la primera fila, como las listas
	cam_z = top
	if glide:
		# Entre rondas la cámara no salta: parte de donde estaba y se desliza a la primera fila
		cam_x = from_x
		cam_z = from_z
		zoom = from_zoom
		_glide = create_tween().set_parallel(true)
		_glide.tween_property(self, "cam_x", 0.0, GLIDE_SECS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_glide.tween_property(self, "cam_z", top, GLIDE_SECS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_glide.tween_property(self, "zoom", 1.0, GLIDE_SECS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Cascada de entrada: con 12 fichas un paso fijo de 0,03 s es poco, pero se acota igual
	var step: float = minf(0.03, 0.75 / float(maxi(tiles.size(), 1)))
	for i in tiles.size():
		var t: Tile = tiles[i]
		t.node.scale = Vector3.ONE * 0.001
		var tw := t.node.create_tween()
		tw.tween_interval(pop_delay + float(i) * step)
		tw.tween_property(t.node, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Pasa a la ronda siguiente del mismo nivel (el contador sigue sumando parejas).
## Corta el deslizamiento entre rondas (al tocar la pantalla manda el dedo, no la animación).
func _stop_glide() -> void:
	if _glide != null and _glide.is_valid():
		_glide.kill()
	_glide = null

func _next_round() -> void:
	_done_pairs += tiles.size() / 2
	_round += 1
	gen += 1
	err.clear()
	revealed.clear()
	sel = null
	lock = false
	_build_round(0.15, true)

func stop() -> void:
	_stop_glide()
	gen += 1
	active = false
	ptrs.clear()
	_clear_tiles()
	_title_label = null
	if board != null:
		board.queue_free()
		board = null
	cols = 0
	rows = 0
	progress_matched = 0
	progress_total = 0
	_rounds.clear()
	_round = 0
	_done_pairs = 0
	_refresh_floor()

## Construye las losetas de una estación y reajusta los huecos del suelo.
func build_menu(level: int) -> void:
	menu_station.build(level)
	_refresh_floor()

func build_subjects(cards: Array) -> void:
	subject_station.build(cards)
	_refresh_floor()

## Los temas de la materia abierta (la mesa que queda a la derecha de las materias).
func build_themes(cards: Array) -> void:
	theme_station.build(cards)
	_refresh_floor()

## La mesa de lista (materias o temas) de la estación activa, o null si no es una lista de esas.
func _list_station() -> StationSubjects:
	if station == "subjects":
		return subject_station
	if station == "themes":
		return theme_station
	return null

## Título de la partida (materia, nivel y modo): va en una franja de la mesa del tablero.
## Hay que fijarlo antes de `start`, para que la primera distribución ya cuente con la franja.
func set_title(d: Dictionary) -> void:
	game_title = d

## Parejas ya emparejadas: la franja del título muestra el avance de la partida.
func set_progress(matched: int) -> void:
	matched = clampi(matched, 0, progress_total)
	if matched == progress_matched:
		return
	progress_matched = matched
	_refresh_title()

## Parejas resueltas en el nivel: las de las rondas ya terminadas más las de la ronda en curso.
func matched_pairs() -> int:
	var n: int = 0
	for t in tiles:
		if (t as Tile).matched:
			n += 1
	return _done_pairs + n / 2

## Texto del subtítulo con el contador, si la partida tiene parejas.
func _title_now() -> Dictionary:
	if progress_total <= 0 or game_title.is_empty():
		return game_title
	var d: Dictionary = game_title.duplicate()
	var base: String = str(d.get("sub", ""))
	if _rounds.size() > 1:
		# Con varias rondas la franja (2 columnas de ancho) no da para el modo: se quita el último
		# tramo ("Nivel 3 · Memoria" -> "Nivel 3") y se añade la ronda.
		var cut: int = base.rfind(" · ")
		if cut >= 0:
			base = base.substr(0, cut)
		base = "%s · Ronda %d/%d" % [base, _round + 1, _rounds.size()]
	d["sub"] = "%s · %d de %d" % [base, progress_matched, progress_total]
	return d

## Vuelve a hornear la franja con el contador nuevo. Se hace una vez por pareja
## (no en cada frame) y el rótulo mantiene la textura vieja hasta que la nueva
## está pintada, así no parpadea.
func _refresh_title() -> void:
	if _title_label == null or not is_instance_valid(_title_label):
		return
	var w: int = int(_title_label.size.x * float(TITLE_PPU))
	var h: int = int(_title_label.size.y * float(TITLE_PPU))
	_title_label.update(Cards.label(_title_now(), w, h), w, h)

func _title_extra() -> float:
	return TITLE_H if not game_title.is_empty() else 0.0

## Paso previo a la partida: las dos formas de jugar. `title` es el rótulo plano de la mesa.
func build_mode(mode_now: String, title: Dictionary = {}) -> void:
	mode_station.build(mode_now, title)
	_refresh_floor()

func build_album(data: Array) -> void:
	album_station.build(data)
	_refresh_floor()

## Ayuda "¿Cómo se juega?": rótulos planos y fichas de ejemplo animadas (`pairs`: dos parejas).
func build_help(pairs: Array = []) -> void:
	help_station.build(pairs)
	_refresh_floor()

## Nivel completado: construye las losetas de la estación de victoria.
func build_win(data: Dictionary) -> void:
	win_station.build(data)
	_refresh_floor()

## Centra la mesa del menú en la franja libre entre la cabecera y los ajustes 2D.
## `band_center` es la fracción vertical desde arriba (0 = borde superior, 1 = inferior).
func center_menu(band_center: float) -> void:
	menu_look_z = _menu_look_for_band(band_center)

func _clear_tiles() -> void:
	for t in tiles:
		t.node.queue_free()
	tiles.clear()

# ---------- Construcción de la escena ----------

func _make_textures() -> void:
	back_tex = TileLook.back_texture()
	bezel_tex = TileLook.bezel_texture()
	# Chispas: la estrella del tema, blanca, para poder teñirla desde el color de la partícula
	spark_tex = UiTheme.icon("star", 64, Color.WHITE)
	spark_mesh = _spark_mesh() if spark_tex != null else null
	gold = TileLook.gold_material(bezel_tex)

## Suelo: foco de luz bajo el tablero, dos manchas de color suaves, el anillo que
## enmarca la losa y la viñeta hacia los bordes; un grano fino evita las bandas.
## La parte visible es la franja central del cuadrado (ver `_layout`), así que el
## degradado se aprieta alrededor del tablero en lugar de repartirse por todo él.
func _ground_texture() -> ImageTexture:
	var n := 128
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	var mid := Color("f4f8ff")    # justo bajo el tablero
	var ring := Color("b8cef0")   # anillo que lo enmarca
	var out := _ground_edge()
	var cool := Color("e2d8ff")   # mancha fría (arriba a la izquierda)
	var warm := Color("d8f4e8")   # mancha verde (abajo a la derecha)
	for y in n:
		var fy: float = (float(y) + 0.5) / float(n)
		for x in n:
			var fx: float = (float(x) + 0.5) / float(n)
			var d: float = (Vector2(fx, fy) * 2.0 - Vector2.ONE).length()
			var col: Color = mid
			col = col.lerp(cool, 0.60 * pow(clampf(1.0 - Vector2(fx, fy).distance_to(Vector2(0.33, 0.30)) / 0.45, 0.0, 1.0), 1.5))
			col = col.lerp(warm, 0.50 * pow(clampf(1.0 - Vector2(fx, fy).distance_to(Vector2(0.67, 0.72)) / 0.45, 0.0, 1.0), 1.5))
			col = col.lerp(ring, smoothstep(0.22, 0.58, d))
			col = col.lerp(out, smoothstep(0.62, 1.02, d))
			# Grano fino: el degradado es de 8 bits y sin él se verían bandas
			var r: float = sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453
			var g: float = (r - floorf(r) - 0.5) * 0.024
			img.set_pixel(x, y, Color(clampf(col.r + g, 0.0, 1.0), clampf(col.g + g, 0.0, 1.0), clampf(col.b + g, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

## Entorno para los reflejos del metal: degradado con focos suaves (softbox) y un
## brillo cálido en el horizonte, que tiñe las partes bajas de la ficha dorada.
func _make_sky() -> Sky:
	var img := Image.create_empty(512, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		var t: float = float(y) / 255.0
		var col: Color
		if t < 0.5:
			col = Color("ffffff").lerp(Color("dbe7ff"), t * 2.0)
		else:
			col = Color("b4c2de").lerp(Color("5b6b8c"), (t - 0.5) * 2.0)
		img.fill_rect(Rect2i(0, y, 512, 1), col)
	# Focos: [centro, alto, brillo]; el de arriba es la luz principal (cenit)
	for band in [[18, 54, 0.95], [96, 30, 0.55], [168, 44, 0.28]]:
		var y0: int = band[0]
		var bh: int = band[1]
		for y in range(y0, mini(y0 + bh, 256)):
			var f: float = 1.0 - absf(float(y - y0) / float(bh) - 0.5) * 2.0
			f = pow(clampf(f, 0.0, 1.0), 0.6) * float(band[2])
			img.fill_rect(Rect2i(0, y, 512, 1), (img.get_pixel(0, y) as Color).lerp(Color.WHITE, f))
	# Brillo del horizonte: un tinte de color que separa el cielo del suelo
	var glow := Color("ffe6c0")
	for y in range(96, 180):
		var f: float = 1.0 - absf(float(y) - 138.0) / 42.0
		f = pow(clampf(f, 0.0, 1.0), 1.4) * 0.20
		img.fill_rect(Rect2i(0, y, 512, 1), (img.get_pixel(0, y) as Color).lerp(glow, f))
	var sm := PanoramaSkyMaterial.new()
	sm.panorama = ImageTexture.create_from_image(img)
	sm.energy_multiplier = SKY_ENERGY
	var sky := Sky.new()
	sky.sky_material = sm
	return sky

## Resolución del 3D según la plataforma: en móvil baja (mucho menos trabajo por pantalla) y se
## amplía con filtro bilineal; la capa 2D (interfaz y textos) no se ve afectada.
func apply_render_scale(mobile: bool) -> void:
	get_viewport().scaling_3d_scale = MOBILE_SCALE_3D if mobile else 1.0

func _build_environment() -> void:
	apply_render_scale(OS.has_feature("mobile"))
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = FOG_COLOR
	env.sky = _make_sky()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cfe0f5")
	env.ambient_light_energy = AMBIENT_ENERGY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.glow_enabled = not OS.has_feature("mobile")   # en móvil cuesta pasadas de pantalla completa y casi no se nota
	env.glow_intensity = 0.40
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.35
	env.set("glow_levels/1", 1.0)
	env.set("glow_levels/2", 0.6)
	env.set("glow_levels/3", 0.3)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = FOG_COLOR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 152, 0)
	sun.light_color = Color("fff4e2")
	sun.light_energy = LIGHT_ENERGY
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.5
	# Un poco de blur y menos opacidad disimulan el escalón del borde en el mapa de sombras
	# de baja resolución del móvil, sin pagar más muestras ni resolución.
	sun.shadow_blur = 1.25
	sun.shadow_opacity = 0.7
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 12.0
	# El valor por defecto (0,8) empieza a apagar la sombra demasiado pronto: con 0,95
	# se mantiene hasta cerca del borde, sin dejar de difuminarse del todo.
	sun.directional_shadow_fade_start = 0.95
	add_child(sun)
	# Luz de relleno: quita dureza a las sombras sin coste (sin sombras propias)
	fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-38, -28, 0)
	fill.light_color = Color("cfe2ff")
	fill.light_energy = FILL_ENERGY
	fill.shadow_enabled = false
	add_child(fill)
	# Suelo cercano: degradado radial que enmarca el tablero (se ajusta en _layout)
	ground_pad = MeshInstance3D.new()
	ground_mesh = PlaneMesh.new()
	ground_mesh.size = Vector2(9, 9)
	ground_pad.mesh = ground_mesh
	ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_texture = _ground_texture()
	ground_mat.roughness = 0.95
	ground_mat.metallic = 0.0
	ground_pad.material_override = ground_mat
	ground_pad.position.y = FloorCubes.GROUND_Y + 0.005
	ground_pad.visible = false
	add_child(ground_pad)
	floor_cubes = FloorCubes.new()
	add_child(floor_cubes)
	# Suelo lejano: el mismo color del borde, para que no se vea el límite
	var far := MeshInstance3D.new()
	var fpm := PlaneMesh.new()
	fpm.size = Vector2(300, 300)
	far.mesh = fpm
	far_mat = StandardMaterial3D.new()
	far_mat.albedo_color = _ground_edge()
	far_mat.roughness = 0.95
	far.material_override = far_mat
	far.position.y = FloorCubes.GROUND_Y
	add_child(far)

func _face_material(tex: Texture2D) -> StandardMaterial3D:
	return TileLook.face_material(tex, CLEARCOAT)

func _make_tile(id: String, tex: Texture2D) -> Tile:
	var t := Tile.new()
	t.pair = id
	t.node = Node3D.new()
	t.flip = Node3D.new()
	t.node.add_child(t.flip)
	add_child(t.node)
	t.body_mat = gold.duplicate() as StandardMaterial3D
	var body := MeshInstance3D.new()
	body.mesh = tile_body
	body.material_override = t.body_mat
	t.flip.add_child(body)
	var face := MeshInstance3D.new()
	face.mesh = face_up
	t.face_mat = _face_material(tex)
	face.material_override = t.face_mat
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.flip.add_child(face)
	var back := MeshInstance3D.new()
	back.mesh = face_down
	t.back_mat = _face_material(back_tex)
	back.material_override = t.back_mat
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.flip.add_child(back)
	t.up = mode == "assoc"
	t.flip.rotation.z = 0.0 if t.up else PI
	return t

func _layout() -> void:
	var n: int = tiles.size()
	if n == 0:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var a: float = vp.x / maxf(vp.y, 1.0)
	cols = mini(2, n)   # como mucho 2 columnas: fichas grandes y desplazamiento solo vertical
	rows = ceili(float(n) / float(cols))
	for i in n:
		var row: int = floori(float(i) / float(cols))
		var in_row: int = cols if row < rows - 1 else n - cols * (rows - 1)
		var col: int = i % cols
		var tl: Tile = tiles[i]
		tl.home = Vector3((float(col) - float(in_row - 1) * 0.5) * ST, MATCH_Y if tl.matched else REST_Y, (float(row) - float(rows - 1) * 0.5) * ST)
		tl.node.position = tl.home
	_build_board()
	var tn: float = tan(deg_to_rad(FOV * 0.5))
	var w: float = float(cols) * ST + 0.5
	var h: float = minf(float(rows), FIT_ROWS) * ST + 0.5 + _title_extra()
	fit = maxf((h + 0.3) / (2.0 * tn), (w + 0.3) / (a * 2.0 * tn)) * 1.12
	# El degradado del suelo se ajusta a lo que ve la cámara en este nivel
	if ground_mesh != null:
		ground_mesh.size = Vector2.ONE * (fit * 0.92)
	if floor_cubes != null:
		_refresh_floor()

func _build_board() -> void:
	if board != null:
		board.queue_free()
	board = Node3D.new()
	add_child(board)
	var w: float = float(cols) * ST + 0.5
	var h: float = float(rows) * ST + 0.5
	var extra: float = _title_extra()
	# Con título, la mesa crece hacia arriba (−z) y el rótulo ocupa esa franja
	var tb: Node3D = TileLook.table(board, w, h + extra)
	tb.position.z = -extra * 0.5
	_title_label = null
	if extra > 0.0:
		var tw: float = float(cols) * ST
		var lb := FlatLabel.make(board, Vector2(tw, extra), _title_now(), 0.0, TITLE_PPU)
		lb.position.z = -(float(rows) * ST * 0.5 + 0.25 + extra * 0.5)
		FaceTex.settle(lb.views())
		_title_label = lb

# ---------- Cámara y estaciones ----------

func _process(delta: float) -> void:
	_drift(delta)
	_update_cam()

## Inercia del arrastre (estaciones y tablero): sigue un poco después de soltar.
func _drift(delta: float) -> void:
	if _pan_v.length() < 2.0 or not ptrs.is_empty():
		return
	_pan(_pan_v * delta)
	_pan_v *= exp(-7.0 * delta)
	if _pan_v.length() < 2.0:
		_pan_v = Vector2.ZERO

## z del punto de mira que deja el marco del menú centrado en `band_center`.
## Se resuelve por bisección porque la tapa del marco es un rectángulo en perspectiva.
func _menu_look_for_band(band_center: float) -> float:
	var corners: Array = menu_station.frame_corners()
	if corners.is_empty():
		return MENU_LOOK_DZ
	var want: float = clampf(band_center, 0.05, 0.95)
	var lo: float = -8.0
	var hi: float = 2.0
	for i in 32:
		var mid: float = (lo + hi) * 0.5
		if _menu_frame_frac(corners, mid) > want:
			lo = mid   # el marco está bajo: subir la mesa (z mayor)
		else:
			hi = mid
	return (lo + hi) * 0.5

## Fracción vertical (0 arriba, 1 abajo) del centro del marco del menú para un z de mira.
func _menu_frame_frac(corners: Array, look_z: float) -> float:
	var target := Vector3(MENU_X, MENU_LOOK_Y, look_z)
	var tan_half: float = tan(deg_to_rad(FOV * 0.5))
	var top: float = INF
	var bottom: float = -INF
	for p in corners:
		var v: Vector3 = (p as Vector3) - target
		var y_cam: float = v.y * sin(TILT) - v.z * cos(TILT)
		var depth: float = MENU_DIST - v.y * cos(TILT) - v.z * sin(TILT)
		var f: float = 0.5 - 0.5 * (y_cam / depth) / tan_half
		top = minf(top, f)
		bottom = maxf(bottom, f)
	return (top + bottom) * 0.5

## Pose de la estación activa: a dónde mira la cámara, a qué distancia y con cuánto balanceo.
func _pose() -> Dictionary:
	var lst: StationSubjects = _list_station()
	if lst != null:
		var s: Vector3 = lst.position
		return {
			"target": Vector3(s.x + cam_x, s.y, s.z + cam_z),
			"dist": lst.fit_distance() / zoom,
			"tilt": TILT,
			"yaw": 0.0,
		}
	if station == "mode" and mode_station != null:
		var m: Vector3 = mode_station.position
		return {
			"target": Vector3(m.x + cam_x, m.y, m.z + cam_z),
			"dist": mode_station.fit_distance() / zoom,
			"tilt": TILT,
			"yaw": 0.0,
		}
	if station == "album" and album_station != null:
		var a: Vector3 = album_station.position
		return {
			"target": Vector3(a.x + cam_x, a.y, a.z + cam_z),
			"dist": album_station.fit_distance() / zoom,
			"tilt": TILT,
			"yaw": 0.0,
		}
	if station == "help" and help_station != null:
		var h: Vector3 = help_station.position
		return {
			"target": Vector3(h.x + cam_x, h.y, h.z + cam_z),
			"dist": help_station.fit_distance() / zoom,
			"tilt": TILT,
			"yaw": 0.0,
		}
	if station == "win" and win_station != null:
		var w: Vector3 = win_station.position
		return {
			"target": Vector3(w.x + cam_x, w.y + win_station.LOOK_Y, w.z + cam_z),
			"dist": win_station.fit_distance() / zoom,
			"tilt": TILT,
			"yaw": 0.0,
		}
	if station == "menu":
		return {"target": Vector3(MENU_X, MENU_LOOK_Y, menu_look_z), "dist": MENU_DIST, "tilt": TILT, "yaw": 0.0}
	# La mesa del tablero crece hacia arriba con el título: la cámara mira un poco más allá del centro
	return {"target": Vector3(cam_x, 0.0, cam_z - _title_extra() * 0.5), "dist": fit / zoom, "tilt": TILT, "yaw": 0.0}

## Pose que se está viendo ahora mismo (a mitad de un vuelo, la mezcla).
func _pose_now() -> Dictionary:
	if _from.is_empty() or _t >= 1.0:
		return _pose()
	return _blend(_from, _pose(), _t)

func _blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	return {
		"target": (a["target"] as Vector3).lerp(b["target"] as Vector3, t),
		"dist": lerpf(float(a["dist"]), float(b["dist"]), t),
		"tilt": lerpf(float(a["tilt"]), float(b["tilt"]), t),
		"yaw": lerpf(float(a["yaw"]), float(b["yaw"]), t),
	}

func _update_cam() -> void:
	var to: Dictionary = _pose()
	var b: Vector2 = _pan_bounds(float(to["dist"]))
	cam_x = clampf(cam_x, -b.x, b.x)
	cam_z = clampf(cam_z, -b.y, b.y)
	to = _pose()  # con el paneo ya corregido
	var p: Dictionary = to if _t >= 1.0 else _blend(_from, to, _t)
	var d: float = float(p["dist"])
	if _t < 1.0:
		d += _arc * sin(PI * _t)
	var tilt: float = float(p["tilt"])
	var target: Vector3 = p["target"]
	var yaw: float = float(p["yaw"])
	var off := Vector3(0.0, d * cos(tilt), d * sin(tilt)).rotated(Vector3.UP, yaw)
	cam.position = target + off
	# La niebla empieza detrás de la mesa: no la tiñe, pero difumina el fondo lejano
	env.fog_depth_begin = d + 4.0
	env.fog_depth_end = d + 22.0
	# El alcance de las sombras sigue a la cámara: con un límite fijo desaparecían al alejarse
	# (niveles grandes, menú, materias), justo cuando más se ve el suelo bajo las mesas.
	sun.directional_shadow_max_distance = d + SHADOW_REACH
	cam.look_at(target, Vector3.UP)

## Límites del paneo (semiejes en X y Z) de la estación activa.
func _pan_bounds(dist: float) -> Vector2:
	var lst: StationSubjects = _list_station()
	if lst != null:
		return lst.pan_bounds(dist)
	if station == "album" and album_station != null:
		return album_station.pan_bounds(dist)
	if station == "win" and win_station != null:
		return win_station.pan_bounds(dist)
	if station == "help" and help_station != null:
		return help_station.pan_bounds(dist)
	if station == "menu" or station == "mode":
		return Vector2.ZERO
	return _game_bounds(dist)

## Cuánto se puede desplazar la cámara en el tablero sin perder de vista la mesa: como en las listas,
## solo en vertical mientras el ancho quepa (en horizontal solo si se acerca con el zoom).
func _game_bounds(dist: float) -> Vector2:
	if cols <= 0 or rows <= 0:
		return Vector2.ZERO
	var view: Vector2 = CamView.visible_size(get_viewport(), dist)
	var w: float = float(cols) * ST + 0.5
	var h: float = float(rows) * ST + 0.5 + _title_extra()
	return Vector2(maxf((w - view.x) * 0.5, 0.0), maxf((h - view.y) * 0.5 + view.y * PAN_PAD_Y, 0.0))

## Lleva la cámara de una estación a otra. `start_at` salta el principio del vuelo
## (entre niveles basta un acercamiento corto).
## Olvida el desplazamiento guardado de una lista: la próxima vez empieza por arriba
## (al abrir otra materia con temas, la lista de temas no hereda el de la anterior).
func forget_view(name: String) -> void:
	_view_mem.erase(name)

func fly_to_station(name: String, secs: float, start_at: float = 0.0) -> void:
	_stop_glide()  # si venimos de cambiar de ronda, su deslizamiento no debe pelear con el vuelo
	if _fly != null:
		_fly.kill()
	_remember_view()
	_from = _pose_now()
	station = name
	_apply_station_visibility(true)
	cam_x = 0.0
	cam_z = 0.0
	zoom = 1.0
	_pan_v = Vector2.ZERO
	# Las listas largas vuelven donde el jugador las dejó (el desplazamiento se
	# recorta solo con los límites de la mesa en `_update_cam`).
	var mem: Dictionary = _view_mem.get(name, {})
	if not mem.is_empty():
		cam_x = float(mem["x"])
		cam_z = float(mem["z"])
		zoom = float(mem["zoom"])
	elif name == "subjects" and subject_station != null:
		# Primera visita: empieza por la primera fila (la lista es más alta que la pantalla)
		cam_z = subject_station.initial_z(subject_station.fit_distance())
	elif name == "themes" and theme_station != null:
		cam_z = theme_station.initial_z(theme_station.fit_distance())
	elif name == "album" and album_station != null:
		# El álbum también empieza por arriba: la primera materia
		cam_z = album_station.initial_z(album_station.fit_distance())
	elif name == "help" and help_station != null:
		# La ayuda también empieza por arriba, como las listas
		cam_z = help_station.initial_z(help_station.fit_distance())
	_arc = 0.0
	if secs > 0.0 and start_at <= 0.0:
		var travel: float = ((_from["target"] as Vector3) - (_pose()["target"] as Vector3)).length()
		if travel > ARC_MIN_TRAVEL:
			_arc = minf(travel * ARC_GAIN, ARC_MAX)
	if secs <= 0.0:
		_t = 1.0
		_arrive()
		return
	_t = clampf(start_at, 0.0, 0.95)
	_settled = false
	_fly = create_tween()
	_fly.tween_property(self, "_t", 1.0, secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_fly.finished.connect(_arrive)

## Guarda el desplazamiento de las listas largas antes de cambiar de estación.
func _remember_view() -> void:
	if station != "subjects" and station != "themes" and station != "album" and station != "help":
		return
	_view_mem[station] = {"x": cam_x, "z": cam_z, "zoom": zoom}

## Fin del vuelo: la mesa de destino queda sola y el tablero se limpia recién ahora,
## así el mundo no se vacía antes de que la cámara se vaya.
func _arrive() -> void:
	_settled = true
	_apply_station_visibility()
	if station != "game" and not tiles.is_empty():
		stop()

## Mantiene ambas mesas visibles durante el vuelo para que el cambio de estación
## se lea como un recorrido continuo, y oculta la inactiva al llegar.
func _apply_station_visibility(keep_stations_visible: bool = false) -> void:
	if menu_station != null:
		menu_station.visible = keep_stations_visible or station == "menu"
	if subject_station != null:
		subject_station.visible = keep_stations_visible or station == "subjects"
	if theme_station != null:
		theme_station.visible = keep_stations_visible or station == "themes"
	if mode_station != null:
		mode_station.visible = keep_stations_visible or station == "mode"
	if album_station != null:
		album_station.visible = keep_stations_visible or station == "album"
	if help_station != null:
		help_station.visible = keep_stations_visible or station == "help"
	if win_station != null:
		win_station.visible = keep_stations_visible or station == "win"
	# El tablero resuelto se esconde al llegar a otra estación (en pantallas anchas asomaría)
	var in_game: bool = keep_stations_visible or station == "game"
	if board != null:
		board.visible = in_game
	for t in tiles:
		t.node.visible = in_game
	_refresh_floor()

func _pan(delta: Vector2) -> void:
	var h: float = maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var upp: float = 2.0 * float(_pose()["dist"]) * tan(deg_to_rad(FOV * 0.5)) / h
	cam_x -= delta.x * upp
	cam_z -= delta.y * upp

func _zoom_by(f: float) -> void:
	zoom = clampf(zoom * f, 0.5, 3.0)

## Huecos del suelo: una mesa por estación (menú, materias y tablero).
## Hasta dónde debe llegar el suelo: las listas largas (materias y álbum) crecen con cada paquete
## y la cámara ve más a lo largo en un móvil vertical, así que se mide con el viewport real.
func _fit_floor_depth() -> void:
	var need: float = 0.0
	for st in [subject_station, theme_station, album_station, help_station]:
		if st == null:
			continue
		var d: float = st.fit_distance()
		var b: Vector2 = st.pan_bounds(d)
		var view: Vector2 = CamView.visible_size(get_viewport(), d)
		need = maxf(need, b.y + view.y * 0.9 + 4.0)   # el 0,9 cubre lo que añade la perspectiva en el borde lejano
	floor_cubes.set_depth(ceili(need))

func _refresh_floor() -> void:
	if floor_cubes == null:
		return
	_fit_floor_depth()
	var clears: Array = []
	if cols > 0 and rows > 0:
		var w: float = float(cols) * ST + 0.5
		var h: float = float(rows) * ST + 0.5
		var ex: float = _title_extra()
		clears.append(Rect2(-w * 0.5 - 0.22, -h * 0.5 - ex - 0.22, w + 0.44, h + ex + 0.44))
	for st in [menu_station, subject_station, theme_station, mode_station, album_station, help_station, win_station]:
		if st != null and (st as Node3D).visible:
			if st.has_method("clear_rects"):
				clears.append_array(st.clear_rects())
				continue
			var r: Rect2 = st.clear_rect()
			if r.size.x > 0.0:
				clears.append(r)
	floor_cubes.set_clears(clears)

# ---------- Entrada (táctil y ratón) ----------

func _ground_point(pos: Vector2) -> Vector3:
	var o: Vector3 = cam.project_ray_origin(pos)
	var d: Vector3 = cam.project_ray_normal(pos)
	if absf(d.y) < 0.0001:
		return Vector3(INF, 0.0, INF)
	return o + d * (-o.y / d.y)

func _tile_at(pos: Vector2) -> Tile:
	var g: Vector3 = _ground_point(pos)
	for t in tiles:
		if absf(g.x - t.home.x) <= 0.5 and absf(g.z - t.home.z) <= 0.5:
			return t
	return null

func _blocked(pos: Vector2) -> bool:
	for c in blockers:
		if (c as Control).is_visible_in_tree() and (c as Control).get_global_rect().has_point(pos):
			return true
	return false

func _apply_light() -> void:
	sun.light_energy = LIGHT_ENERGY * light_scale
	env.ambient_light_energy = AMBIENT_ENERGY * light_scale
	print("Luz x%.2f: direccional %.2f, ambiental %.2f" % [light_scale, sun.light_energy, env.ambient_light_energy])

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and (e as InputEventKey).pressed and OS.is_debug_build():
		var k: Key = (e as InputEventKey).keycode
		if k == KEY_UP or k == KEY_DOWN:
			light_scale = clampf(light_scale + (0.1 if k == KEY_UP else -0.1), 0.2, 2.0)
			_apply_light()
		return
	if not _settled or _t < 0.98:
		return
	if station == "game" and not active:
		return
	if e is InputEventScreenTouch:
		var te := e as InputEventScreenTouch
		if te.pressed:
			_down(te.index, te.position)
		else:
			_up(te.index)
	elif e is InputEventScreenDrag:
		var de := e as InputEventScreenDrag
		_move(de.index, de.position)
	elif e is InputEventMouseButton and e.device != InputEvent.DEVICE_ID_EMULATION:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_down(-1, mb.position)
			else:
				_up(-1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1.1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / 1.1)
	elif e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION:
		var mm := e as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_move(-1, mm.position)

func _down(id: int, pos: Vector2) -> void:
	if _blocked(pos):
		return  # tocar "Atrás" no debe cortar el deslizamiento de la ronda
	_stop_glide()
	ptrs[id] = pos
	last_pos = pos
	if ptrs.size() == 1:
		press_tile = _tile_at(pos) if station == "game" else null
		press_start = pos
		moved = false
		_pan_v = Vector2.ZERO
	else:
		moved = true
		press_tile = null
		pinch_d = _pinch_distance()
		_pan_v = Vector2.ZERO

func _move(id: int, pos: Vector2) -> void:
	if not ptrs.has(id):
		return
	var delta: Vector2 = pos - (ptrs[id] as Vector2)
	ptrs[id] = pos
	last_pos = pos
	if ptrs.size() >= 2:
		var d: float = _pinch_distance()
		if pinch_d > 1.0:
			_zoom_by(d / pinch_d)
		pinch_d = d
		_pan(delta * 0.5)
		return
	if not moved and pos.distance_to(press_start) > 12.0:
		moved = true
	if moved:
		_pan(delta)
		var dt: float = maxf(get_process_delta_time(), 0.001)
		_pan_v = _pan_v.lerp(delta / dt, 0.45)

func _up(id: int) -> void:
	if not ptrs.has(id):
		return
	ptrs.erase(id)
	if ptrs.size() == 2:
		pinch_d = _pinch_distance()  # al levantar el tercer dedo, la pareja que pellizca cambia
	if not ptrs.is_empty():
		return
	if not moved and press_tile != null:
		_tap(press_tile)
	elif not moved and station != "game":
		_station_tap(last_pos)
	press_tile = null
	# La inercia sigue tras arrastrar; un toque la corta
	if not moved:
		_pan_v = Vector2.ZERO

## Toque corto en las estaciones: la loseta que hay bajo el dedo.
func _station_tap(pos: Vector2) -> void:
	if station == "menu" and menu_station != null:
		menu_station.tap(pos, cam)
	elif station == "subjects" and subject_station != null:
		subject_station.tap(pos, cam)
	elif station == "themes" and theme_station != null:
		theme_station.tap(pos, cam)
	elif station == "mode" and mode_station != null:
		mode_station.tap(pos, cam)
	elif station == "album" and album_station != null:
		album_station.tap(pos, cam)
	elif station == "win" and win_station != null:
		win_station.tap(pos, cam)

func _pinch_distance() -> float:
	var k: Array = ptrs.keys()
	return (ptrs[k[0]] as Vector2).distance_to(ptrs[k[1]] as Vector2)

# ---------- Reglas ----------

func _tap(t: Tile) -> void:
	if mode == "assoc":
		_tap_assoc(t)
	else:
		_tap_mem(t)

func _partner(t: Tile) -> Tile:
	for o in tiles:
		if o != t and o.pair == t.pair:
			return o
	return null

func _tap_mem(t: Tile) -> void:
	if lock or t.up or t.matched:
		return
	t.seen = true
	_flip(t, true)
	sfx.emit("flip")
	revealed.append(t)
	if revealed.size() < 2:
		return
	lock = true
	var g: int = gen
	await get_tree().create_timer(0.45).timeout
	if g != gen:
		return
	var a: Tile = revealed[0]
	var b: Tile = revealed[1]
	revealed.clear()
	if a.pair == b.pair:
		_resolve_ok(a, b)
		lock = false
	else:
		var pa: Tile = _partner(a)
		if pa != null and pa.seen:
			err[a.pair] = true  # la pareja de la primera ya se había visto: error de memoria
		sfx.emit("err")
		await get_tree().create_timer(0.55).timeout
		if g != gen:
			return
		_flip(a, false)
		_flip(b, false)
		await get_tree().create_timer(0.35).timeout
		if g != gen:
			return
		lock = false

func _tap_assoc(t: Tile) -> void:
	if t.matched or lock:
		return
	if sel == null:
		sfx.emit("flip")
		sel = t
		_lift(t, 0.3)
		_glow(t, Color("3b82f6"), 0.55)
		return
	var a: Tile = sel
	sel = null
	_unsel(a)
	if a != t:
		_resolve_assoc(a, t)

func _resolve_assoc(a: Tile, b: Tile) -> void:
	if a.pair == b.pair:
		_resolve_ok(a, b)
	else:
		err[a.pair] = true  # error de la ficha elegida primero
		sfx.emit("err")
		_shake(a)
		_shake(b)

func _resolve_ok(a: Tile, b: Tile) -> void:
	_unglow(a)
	_unglow(b)
	_match(a)
	_match(b)
	_sparks(a)
	_sparks(b)
	sfx.emit("ok")
	pair_done.emit(a.pair, not err.has(a.pair))
	_check_win()

func _match(t: Tile) -> void:
	t.matched = true
	t.home.y = MATCH_Y
	# Resuelta: bisel verde, imagen atenuada, un poco translúcida y ficha hundida
	t.body_mat.emission_enabled = false
	var body := Color("5ac489")
	body.a = MATCH_ALPHA
	t.body_mat.albedo_color = body
	t.body_mat.roughness = 0.38
	t.face_mat.albedo_color = Color(0.70, 0.80, 0.74, MATCH_ALPHA)
	t.back_mat.albedo_color = Color(0.70, 0.80, 0.74, MATCH_ALPHA)
	# Las superficies transparentes no escriben profundidad: el cuerpo va antes que las caras
	for m in [t.body_mat, t.face_mat, t.back_mat]:
		(m as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	t.body_mat.render_priority = 0
	t.face_mat.render_priority = 1
	t.back_mat.render_priority = 1
	var tw := t.node.create_tween()
	tw.tween_property(t.node, "position:y", MATCH_Y, 0.1)
	tw.parallel().tween_property(t.node, "scale", Vector3.ONE * 1.12, 0.12)
	tw.tween_property(t.node, "scale", Vector3.ONE * 0.95, 0.18)
	_flash(t, Color(1.0, 0.94, 0.66, 1.0))

## Anillo que se abre y se apaga sobre la ficha resuelta.
func _flash(t: Tile, col: Color) -> void:
	var mi := _ring_node(col, ring_mesh)
	# La ficha se hunde al resolverse; el destello se mantiene por encima del resto
	mi.position.y = FLASH_Y - MATCH_Y
	mi.scale = Vector3.ONE * 0.8
	t.node.add_child(mi)
	var mat: StandardMaterial3D = mi.material_override
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.45, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(mi.queue_free)

## Chispas al emparejar: un puñado de estrellas que saltan de la ficha y se apagan.
## Cuelgan de la ficha (se liberan con ella) y van en coordenadas globales, para que
## no la sigan cuando se hunde en la losa.
func _sparks(t: Tile) -> void:
	if spark_mesh == null:
		return
	var p := CPUParticles3D.new()
	p.mesh = spark_mesh
	p.amount = SPARK_AMOUNT
	p.lifetime = SPARK_LIFE
	p.one_shot = true
	p.explosiveness = 1.0        # todas a la vez: un estallido, no un chorro
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.24
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.8
	p.initial_velocity_max = 3.6
	p.gravity = Vector3(0, -3.2, 0)
	p.damping_min = 0.5
	p.damping_max = 1.3
	p.angular_velocity_min = -240.0
	p.angular_velocity_max = 240.0
	p.scale_amount_min = SPARK_SIZE * 0.55
	p.scale_amount_max = SPARK_SIZE * 1.30
	p.color_ramp = _spark_ramp()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0, 0.10, 0)
	t.node.add_child(p)
	p.emitting = true
	# Se limpian solas; si la ficha se libera antes, el tween muere con el nodo
	var tw := p.create_tween()
	tw.tween_interval(SPARK_LIFE + 0.25)
	tw.tween_callback(p.queue_free)

## Quad con la estrella del tema, siempre de cara a la cámara.
func _spark_mesh() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(SPARK_SIZE, SPARK_SIZE)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = spark_tex
	m.vertex_color_use_as_albedo = true  # el color de la partícula tiñe la estrella
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.render_priority = 2                # por encima de las caras translúcidas
	q.material = m
	return q

## Color de la chispa a lo largo de su vida: nace casi blanca, pasa enseguida a dorado intenso y se apaga en naranja.
func _spark_ramp() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.65, 1.0])
	g.colors = PackedColorArray([SPARK_PALE, SPARK_GOLD, SPARK_ORANGE, Color(SPARK_ORANGE.r, SPARK_ORANGE.g, SPARK_ORANGE.b, 0.0)])
	return g

## Anillo sin iluminar, translúcido, para halos y destellos.
func _ring_node(col: Color, mesh: ArrayMesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Por encima de las caras translúcidas de las fichas resueltas
	m.render_priority = 2
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = col
	mi.material_override = m
	return mi

func _check_win() -> void:
	for t in tiles:
		if not t.matched:
			return
	var g: int = gen
	lock = true
	var last: bool = _round >= _rounds.size() - 1
	for i in tiles.size():
		var t: Tile = tiles[i]
		var tw := t.node.create_tween()
		tw.tween_interval(0.4 + i * 0.05)
		tw.tween_property(t.node, "position:y", 0.45, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_sparks.bind(t))  # estallido de estrellas en lo alto del salto
		tw.tween_property(t.node, "position:y", MATCH_Y, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(1.1 + tiles.size() * 0.05).timeout
	if g != gen or not active:
		return
	if last:
		sfx.emit("win")
		won.emit()
	else:
		_next_round()

# ---------- Animaciones ----------

func _flip(t: Tile, up: bool) -> void:
	t.up = up
	var tw := t.node.create_tween()
	tw.tween_property(t.flip, "rotation:z", 0.0 if up else PI, 0.33).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var hop := t.node.create_tween()
	hop.tween_property(t.node, "position:y", 0.5, 0.165).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hop.tween_property(t.node, "position:y", REST_Y, 0.165).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _lift(t: Tile, y: float) -> void:
	var tw := t.node.create_tween()
	tw.tween_property(t.node, "position:y", y, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _glow(t: Tile, col: Color, energy: float) -> void:
	t.body_mat.emission_enabled = true
	t.body_mat.emission = col
	t.body_mat.emission_energy_multiplier = energy
	if t.halo == null:
		t.halo = _ring_node(Color(col.r, col.g, col.b, 0.85), halo_mesh)
		t.halo.position.y = -0.075
		t.node.add_child(t.halo)
		var tw := t.halo.create_tween()
		tw.set_loops()
		tw.tween_property(t.halo, "scale", Vector3.ONE * 1.05, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(t.halo, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_SINE)

func _unglow(t: Tile) -> void:
	t.body_mat.emission_enabled = false
	if t.halo != null:
		t.halo.queue_free()
		t.halo = null

func _unsel(t: Tile) -> void:
	_lift(t, MATCH_Y if t.matched else REST_Y)
	_unglow(t)

func _shake(t: Tile) -> void:
	var tw := t.flip.create_tween()
	tw.tween_property(t.flip, "position:x", 0.1, 0.06)
	tw.tween_property(t.flip, "position:x", -0.1, 0.09)
	tw.tween_property(t.flip, "position:x", 0.0, 0.06)
