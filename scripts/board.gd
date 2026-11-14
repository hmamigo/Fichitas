class_name Board
extends Node3D
## Tablero 3D: escena, cámara casi cenital (zoom y paneo, sin rotación), entrada táctil/ratón
## y reglas de los dos modos ("mem" = memoria, "assoc" = asociación).

signal won
signal pair_done(pair_id: String, clean: bool)
signal sfx(sound: String)  # "flip", "ok", "err", "win"

const ST := 1.12      # separación entre fichas
const TILT := 0.17    # inclinación de la cámara
const FOV := 35.0
const MENU_DIST := 22.0   # distancia de la cámara en el menú: las 4 losetas (alto ≈ 4,5) ocupan ~1/3 del alto visible; calibrada a mano
# Las tres estaciones van en fila a lo largo de X: menú, materias y tablero (en el origen).
# 10 de separación: el tablero apaisado de PC puede medir ~11 de ancho y no debe tocar la mesa de materias.
const STATION_GAP := 10.0
const SUBJ_X := -STATION_GAP          # materias: a la izquierda del tablero
const MENU_X := -2.0 * STATION_GAP    # menú: a la izquierda de las materias
const MENU_LOOK_DZ := -0.2             # el punto de mira va delante de la mesa del menú: la sube en pantalla
const MENU_LOOK := Vector3(MENU_X, -0.2, MENU_LOOK_DZ)
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
const LIGHT_ENERGY := 0.43    # luz direccional principal
const FILL_ENERGY := 0.14     # luz de relleno (sin sombras)
const AMBIENT_ENERGY := 0.20  # luz ambiental
const SKY_ENERGY := 0.55      # brillo del entorno (reflejos)
const CLEARCOAT := 0.6        # barniz de las caras
# Chispas al emparejar (ajustables)
const SPARK_AMOUNT := 16       # estrellas por ficha
const SPARK_LIFE := 0.55       # segundos que viven
const SPARK_SIZE := 0.13       # lado de cada estrella
const SPARK_GOLD := Color("ffd45e")
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
var station: String = "menu"  # "menu", "subjects" o "game"
var menu_station: StationMenu
var subject_station: StationSubjects
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
var dragging: bool = false
var drag_tile: Tile = null
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
	get_viewport().size_changed.connect(_layout)

# ---------- API ----------

func start(pairs: Array, pop_delay: float = 0.0) -> void:
	# El vuelo lo pide `main` antes de llamar aquí; si nadie lo hizo (pruebas), se salta.
	if station != "game" and _settled:
		fly_to_station("game", 0.0)
	_clear_tiles()
	gen += 1
	active = true
	err.clear()
	revealed.clear()
	sel = null
	dragging = false
	drag_tile = null
	lock = false
	var items: Array = []
	for pr in pairs:
		items.append({"id": pr["id"], "tex": pr["a"]})
		items.append({"id": pr["id"], "tex": pr["b"]})
	items.shuffle()
	for it in items:
		tiles.append(_make_tile(str(it["id"]), it["tex"]))
	zoom = 1.0
	cam_x = 0.0
	cam_z = 0.0
	_layout()
	# Cascada de entrada: con 48 fichas un paso fijo de 0,03 s tardaría casi 1,5 s
	var step: float = minf(0.03, 0.75 / float(maxi(tiles.size(), 1)))
	for i in tiles.size():
		var t: Tile = tiles[i]
		t.node.scale = Vector3.ONE * 0.001
		var tw := t.node.create_tween()
		tw.tween_interval(pop_delay + float(i) * step)
		tw.tween_property(t.node, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func stop() -> void:
	gen += 1
	active = false
	ptrs.clear()
	_clear_tiles()
	if board != null:
		board.queue_free()
		board = null
	cols = 0
	rows = 0
	_refresh_floor()

## Construye las losetas de una estación y reajusta los huecos del suelo.
func build_menu(mode_now: String, level: int) -> void:
	menu_station.build(mode_now, level)
	_refresh_floor()

func build_subjects(cards: Array) -> void:
	subject_station.build(cards)
	_refresh_floor()

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

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = FOG_COLOR
	env.sky = _make_sky()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("cfe0f5")
	env.ambient_light_energy = AMBIENT_ENERGY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.glow_enabled = true
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
	sun.shadow_blur = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 12.0
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
	ground_pad.position.y = -0.45
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
	far.position.y = -0.455
	add_child(far)

func _face_material(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.42
	m.clearcoat_enabled = true
	m.clearcoat = CLEARCOAT
	m.clearcoat_roughness = 0.18
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.3
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

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
	var best_c: int = 2
	var best_s: float = -1.0
	var best_cells: int = 1 << 30
	for c in range(2, n + 1):
		var r: int = ceili(float(n) / float(c))
		var s: float = minf(a / float(c), 0.86 / float(r))
		if s > best_s + 1e-6 or (absf(s - best_s) < 1e-6 and c * r < best_cells):
			best_s = s
			best_c = c
			best_cells = c * r
	cols = best_c
	rows = ceili(float(n) / float(cols))
	for i in n:
		var row: int = floori(float(i) / float(cols))
		var in_row: int = cols if row < rows - 1 else n - cols * (rows - 1)
		var col: int = i % cols
		var tl: Tile = tiles[i]
		tl.home = Vector3((float(col) - float(in_row - 1) * 0.5) * ST, MATCH_Y if tl.matched else REST_Y, (float(row) - float(rows - 1) * 0.5) * ST)
		if not (dragging and drag_tile == tl):
			tl.node.position = tl.home
	_build_board()
	var tn: float = tan(deg_to_rad(FOV * 0.5))
	var w: float = float(cols) * ST + 0.5
	var h: float = float(rows) * ST + 0.5
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
	TileLook.table(board, w, h)

# ---------- Cámara y estaciones ----------

func _process(delta: float) -> void:
	_drift(delta)
	_update_cam()

## Inercia del arrastre en las estaciones: sigue un poco después de soltar.
func _drift(delta: float) -> void:
	if station == "game" or _pan_v.length() < 2.0 or not ptrs.is_empty():
		return
	_pan(_pan_v * delta)
	_pan_v *= exp(-7.0 * delta)
	if _pan_v.length() < 2.0:
		_pan_v = Vector2.ZERO

## Pose de la estación activa: a dónde mira la cámara, a qué distancia y con cuánto balanceo.
func _pose() -> Dictionary:
	if station == "subjects" and subject_station != null:
		var s: Vector3 = subject_station.position
		return {
			"target": Vector3(s.x + cam_x, s.y, s.z + cam_z),
			"dist": subject_station.fit_distance() / zoom,
			"tilt": subject_station.TILT,
			"yaw": 0.0,
		}
	if station == "menu":
		return {"target": MENU_LOOK, "dist": MENU_DIST, "tilt": TILT, "yaw": 0.0}
	return {"target": Vector3(cam_x, 0.0, cam_z), "dist": fit / zoom, "tilt": TILT, "yaw": 0.0}

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
	cam.look_at(target, Vector3.UP)

## Límites del paneo (semiejes en X y Z) de la estación activa.
func _pan_bounds(dist: float) -> Vector2:
	if station == "subjects" and subject_station != null:
		return subject_station.pan_bounds(dist)
	if station == "menu":
		return Vector2.ZERO
	return Vector2(float(cols) * ST * 0.5, float(rows) * ST * 0.5)

## Lleva la cámara de una estación a otra. `start_at` salta el principio del vuelo
## (entre niveles basta un acercamiento corto).
func fly_to_station(name: String, secs: float, start_at: float = 0.0) -> void:
	if _fly != null:
		_fly.kill()
	_from = _pose_now()
	station = name
	_apply_station_visibility(true)
	cam_x = 0.0
	cam_z = 0.0
	zoom = 1.0
	_pan_v = Vector2.ZERO
	# Las materias empiezan por la primera fila: la lista es más alta que la pantalla
	if name == "subjects" and subject_station != null:
		cam_z = subject_station.initial_z(subject_station.fit_distance())
	_arc = 0.0
	if secs > 0.0 and start_at <= 0.0:
		var travel: float = ((_from["target"] as Vector3) - (_pose()["target"] as Vector3)).length()
		if travel > ARC_MIN_TRAVEL:
			_arc = minf(travel * ARC_GAIN, ARC_MAX)
	if secs <= 0.0:
		_t = 1.0
		_settled = true
		_apply_station_visibility()
		return
	_t = clampf(start_at, 0.0, 0.95)
	_settled = false
	_fly = create_tween()
	_fly.tween_property(self, "_t", 1.0, secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_fly.finished.connect(func() -> void:
		_settled = true
		_apply_station_visibility()
	)

## Mantiene ambas mesas visibles durante el vuelo para que el cambio de estación
## se lea como un recorrido continuo, y oculta la inactiva al llegar.
func _apply_station_visibility(keep_stations_visible: bool = false) -> void:
	if menu_station != null:
		menu_station.visible = keep_stations_visible or station == "menu"
	if subject_station != null:
		subject_station.visible = keep_stations_visible or station == "subjects"
	_refresh_floor()

func _pan(delta: Vector2) -> void:
	var h: float = maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var upp: float = 2.0 * float(_pose()["dist"]) * tan(deg_to_rad(FOV * 0.5)) / h
	cam_x -= delta.x * upp
	cam_z -= delta.y * upp

func _zoom_by(f: float) -> void:
	zoom = clampf(zoom * f, 0.5, 3.0)

## Huecos del suelo: una mesa por estación (menú, materias y tablero).
func _refresh_floor() -> void:
	if floor_cubes == null:
		return
	var clears: Array = []
	if cols > 0 and rows > 0:
		var w: float = float(cols) * ST + 0.5
		var h: float = float(rows) * ST + 0.5
		clears.append(Rect2(-w * 0.5 - 0.22, -h * 0.5 - 0.22, w + 0.44, h + 0.44))
	for st in [menu_station, subject_station]:
		if st != null and (st as Node3D).visible:
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
		return
	ptrs[id] = pos
	last_pos = pos
	if ptrs.size() == 1:
		press_tile = _tile_at(pos) if station == "game" else null
		press_start = pos
		moved = false
		_pan_v = Vector2.ZERO
	else:
		if dragging and drag_tile != null:
			_return_home(drag_tile)
		dragging = false
		drag_tile = null
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
		if station == "game" and mode == "assoc" and press_tile != null and not press_tile.matched and not lock:
			_begin_drag(press_tile)
	if dragging and drag_tile != null:
		var g: Vector3 = _ground_point(pos)
		drag_tile.node.position.x = g.x
		drag_tile.node.position.z = g.z
	elif moved:
		_pan(delta)
		if station != "game":
			var dt: float = maxf(get_process_delta_time(), 0.001)
			_pan_v = _pan_v.lerp(delta / dt, 0.45)

func _up(id: int) -> void:
	if not ptrs.has(id):
		return
	ptrs.erase(id)
	if not ptrs.is_empty():
		return
	if dragging and drag_tile != null:
		_drop(drag_tile, last_pos)
		dragging = false
		drag_tile = null
	elif not moved and press_tile != null:
		_tap(press_tile)
	elif not moved and station != "game":
		_station_tap(last_pos)
	press_tile = null
	# La inercia sigue solo tras arrastrar en una estación; un toque la corta
	if station == "game" or not moved:
		_pan_v = Vector2.ZERO

## Toque corto en las estaciones: la loseta que hay bajo el dedo.
func _station_tap(pos: Vector2) -> void:
	if station == "menu" and menu_station != null:
		menu_station.tap(pos, cam)
	elif station == "subjects" and subject_station != null:
		subject_station.tap(pos, cam)

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
		err[a.pair] = true  # error de la ficha elegida o arrastrada primero
		sfx.emit("err")
		_shake(a)
		_shake(b)

func _begin_drag(t: Tile) -> void:
	if sel != null:
		_unsel(sel)
		sel = null
	dragging = true
	drag_tile = t
	_lift(t, 0.35)

func _drop(t: Tile, pos: Vector2) -> void:
	var g: Vector3 = _ground_point(pos)
	var other: Tile = null
	var best: float = 0.55 * ST
	for o in tiles:
		if o != t and not o.matched:
			var d: float = Vector2(g.x - o.home.x, g.z - o.home.z).length()
			if d < best:
				best = d
				other = o
	_return_home(t)
	if other != null:
		_resolve_assoc(t, other)

func _return_home(t: Tile) -> void:
	var tw := t.node.create_tween()
	tw.tween_property(t.node, "position", t.home, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
	p.initial_velocity_min = 1.3
	p.initial_velocity_max = 2.6
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

## Color de la chispa a lo largo de su vida: nace casi blanca y se apaga en dorado.
func _spark_ramp() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.30, 1.0])
	g.colors = PackedColorArray([SPARK_PALE, SPARK_GOLD, Color(SPARK_GOLD.r, SPARK_GOLD.g, SPARK_GOLD.b, 0.0)])
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
	for i in tiles.size():
		var t: Tile = tiles[i]
		var tw := t.node.create_tween()
		tw.tween_interval(0.4 + i * 0.05)
		tw.tween_property(t.node, "position:y", 0.45, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(_sparks.bind(t))  # estallido de estrellas en lo alto del salto
		tw.tween_property(t.node, "position:y", MATCH_Y, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(1.1 + tiles.size() * 0.05).timeout
	if g == gen and active:
		sfx.emit("win")
		won.emit()

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
