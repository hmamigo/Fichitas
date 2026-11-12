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
const HY := 0.065     # mitad del grosor de la ficha
const FACE := 0.425   # semiancho de la cara con la imagen
const REST_Y := 0.06   # altura de las fichas pendientes: separadas de la losa
const MATCH_Y := -0.09  # las resueltas se hunden en la losa
const FLASH_Y := 0.15      # altura del destello sobre las fichas pendientes
const MATCH_ALPHA := 0.50  # opacidad de las fichas resueltas (un poco translúcidas)
# Iluminación (ajustable en pruebas con las flechas ↑ ↓ del teclado; el valor sale en la consola)
const LIGHT_ENERGY := 0.55    # luz direccional principal
const FILL_ENERGY := 0.14     # luz de relleno (sin sombras)
const AMBIENT_ENERGY := 0.26  # luz ambiental
const SKY_ENERGY := 0.55      # brillo del entorno (reflejos)
const CLEARCOAT := 0.6        # barniz de las caras

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
var gold: StandardMaterial3D
var tile_body: ArrayMesh
var face_up: ArrayMesh
var face_down: ArrayMesh
var ring_mesh: ArrayMesh
var halo_mesh: ArrayMesh
var dark: bool = false
var ground_mat: StandardMaterial3D
var far_mat: StandardMaterial3D
var fill: DirectionalLight3D

## Color de la escena según la paleta clara u oscura.
func _c(light: Color, night: Color) -> Color:
	return night if dark else light

func _ground_edge() -> Color:
	return _c(Color("6f92bd"), Color("0b1120"))

## Cambia la paleta de la escena 3D (suelo, marco, losa, luces y cielo).
func apply_theme(is_dark: bool) -> void:
	dark = is_dark
	_make_textures()
	if env == null:
		return
	env.background_color = _ground_edge()
	env.sky = _make_sky()
	env.ambient_light_color = _c(Color("cfe0f5"), Color("6f86b8"))
	sun.light_color = _c(Color("fff4e2"), Color("cfe0ff"))
	fill.light_color = _c(Color("cfe2ff"), Color("7893c8"))
	far_mat.albedo_color = _ground_edge()
	ground_mat.albedo_texture = _ground_texture()
	if board != null:
		_build_board()

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
	halo_mesh = TileMesh.ring(0.50, 0.62, 0.0, 8, 0.17)
	get_viewport().size_changed.connect(_layout)

# ---------- API ----------

func start(pairs: Array) -> void:
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
	for i in tiles.size():
		var t: Tile = tiles[i]
		t.node.scale = Vector3.ONE * 0.001
		var tw := t.node.create_tween()
		tw.tween_interval(i * 0.03)
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

func _clear_tiles() -> void:
	for t in tiles:
		t.node.queue_free()
	tiles.clear()

# ---------- Construcción de la escena ----------

func _make_textures() -> void:
	back_tex = _back_texture()
	bezel_tex = _bezel_texture()
	gold = StandardMaterial3D.new()
	gold.albedo_color = Color("e9b949")
	gold.albedo_texture = bezel_tex
	gold.uv1_scale = Vector3(1.0 / 0.98, 1.0 / 0.98, 1.0)
	gold.uv1_offset = Vector3(0.5, 0.5, 0.0)
	gold.metallic = 1.0
	gold.metallic_specular = 0.55
	gold.roughness = 0.28
	gold.clearcoat_enabled = true
	gold.clearcoat = 0.25
	gold.clearcoat_roughness = 0.18

## Dorso de la ficha: tarjeta azulada con borde fino y un emblema en el centro.
func _back_texture() -> ImageTexture:
	var n := 128
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	var top := _c(Color("e8f0fb"), Color("2a3550"))
	var bot := _c(Color("c3d6f2"), Color("1e2740"))
	var line := _c(Color("9cbce4"), Color("3b4a6b"))
	var mark := _c(Color("4a8ff5"), Color("7fb0ff"))
	var inner := _c(Color("eef5ff"), Color("c9d8f5"))
	for y in n:
		var t: float = float(y) / float(n - 1)
		for x in n:
			var u := Vector2((float(x) + 0.5) / n * 2.0 - 1.0, (float(y) + 0.5) / n * 2.0 - 1.0)
			var col: Color = top.lerp(bot, t)
			var d: float = UiTheme.sdf(u, Vector2(0.88, 0.88), 0.22)
			col = col.lerp(line, clampf(1.0 - absf(d + 0.02) / 0.04, 0.0, 1.0) * 0.9)
			var m: float = UiTheme.sdf(u, Vector2(0.50, 0.50), 0.18)
			if m < 0.0:
				col = col.lerp(mark, 0.95)
			var mi: float = UiTheme.sdf(u, Vector2(0.28, 0.28), 0.10)
			if mi < 0.0:
				col = col.lerp(inner, 0.97)
			var mo: float = UiTheme.sdf(u, Vector2(0.13, 0.13), 0.055)
			if mo < 0.0:
				col = col.lerp(mark, 0.95)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

## Bisel dorado: oscurece el hueco donde encaja la cara (oclusión falsa).
func _bezel_texture() -> ImageTexture:
	var n := 128
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var p := Vector2((float(x) + 0.5) / n * 2.0 - 1.0, (float(y) + 0.5) / n * 2.0 - 1.0) * 0.49
			var d: float = UiTheme.sdf(p, Vector2(FACE, FACE), 0.09)
			var k: float = 1.0 - 0.42 * exp(-pow(maxf(d, 0.0) / 0.015, 2.0))
			var do: float = UiTheme.sdf(p, Vector2(0.49, 0.49), 0.16)
			k *= lerpf(1.0, 0.86, clampf(1.0 + do / 0.05, 0.0, 1.0))
			img.set_pixel(x, y, Color(k, k, k))
	return ImageTexture.create_from_image(img)

## Suelo: degradado radial suave que da profundidad alrededor del tablero.
func _ground_texture() -> ImageTexture:
	var n := 96
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	var mid := _c(Color("a8bfda"), Color("141d2e"))
	var out := _ground_edge()
	for y in n:
		for x in n:
			var p := Vector2((float(x) + 0.5) / n * 2.0 - 1.0, (float(y) + 0.5) / n * 2.0 - 1.0)
			img.set_pixel(x, y, mid.lerp(out, pow(clampf(p.length() / 1.15, 0.0, 1.0), 2.0)))
	return ImageTexture.create_from_image(img)

## Losa del tablero: cuadrícula de puntos y un borde fino.
func _plate_texture(hx: float, hz: float) -> ImageTexture:
	var n := 128
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	var base := _c(Color("e9dab8"), Color("2a3145"))
	var dot := _c(Color("cbb287"), Color("3d4761"))
	var line := _c(Color("a6c7ea"), Color("4a6f9e"))
	for y in n:
		var uy: float = (float(y) + 0.5) / n * 2.0 - 1.0
		for x in n:
			var ux: float = (float(x) + 0.5) / n * 2.0 - 1.0
			var col: Color = base
			var dx: float = absf(fposmod(ux * hx, 0.28) - 0.14)
			var dz: float = absf(fposmod(uy * hz, 0.28) - 0.14)
			col = col.lerp(dot, clampf(1.0 - sqrt(dx * dx + dz * dz) / 0.075, 0.0, 1.0))
			var d: float = UiTheme.sdf(Vector2(ux * hx, uy * hz), Vector2(hx, hz) - Vector2(0.11, 0.11), 0.16)
			col = col.lerp(line, clampf(1.0 - absf(d + 0.012) / 0.02, 0.0, 1.0) * 0.8)
			col = col.darkened(0.10 * clampf(1.0 + d / 0.06, 0.0, 1.0))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

## Entorno para los reflejos del metal: degradado con focos suaves (softbox).
func _make_sky() -> Sky:
	var img := Image.create_empty(512, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		var t: float = float(y) / 255.0
		var col: Color
		if t < 0.5:
			col = _c(Color("ffffff"), Color("2a3550")).lerp(_c(Color("dbe7ff"), Color("3a4a6b")), t * 2.0)
		else:
			col = _c(Color("93a8cf"), Color("202a40")).lerp(_c(Color("232a3c"), Color("0a0f1a")), (t - 0.5) * 2.0)
		img.fill_rect(Rect2i(0, y, 512, 1), col)
	for band in [[24, 48, 0.9], [104, 34, 0.6], [176, 40, 0.3]]:
		var y0: int = band[0]
		var h: int = band[1]
		for y in range(y0, y0 + h):
			var f: float = 1.0 - absf(float(y - y0) / float(h) - 0.5) * 2.0
			f = pow(clampf(f, 0.0, 1.0), 0.6) * float(band[2])
			img.fill_rect(Rect2i(0, y, 512, 1), (img.get_pixel(0, y) as Color).lerp(Color.WHITE, f))
	var sm := PanoramaSkyMaterial.new()
	sm.panorama = ImageTexture.create_from_image(img)
	sm.energy_multiplier = SKY_ENERGY
	var sky := Sky.new()
	sky.sky_material = sm
	return sky

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _ground_edge()
	env.sky = _make_sky()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _c(Color("cfe0f5"), Color("6f86b8"))
	env.ambient_light_energy = AMBIENT_ENERGY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ssao_enabled = true
	env.ssao_radius = 0.7
	env.ssao_intensity = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.25
	env.glow_intensity = 0.40
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.35
	env.set("glow_levels/1", 1.0)
	env.set("glow_levels/2", 0.6)
	env.set("glow_levels/3", 0.3)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, -28, 0)
	sun.light_color = _c(Color("fff4e2"), Color("cfe0ff"))
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
	fill.rotation_degrees = Vector3(-38, 152, 0)
	fill.light_color = _c(Color("cfe2ff"), Color("7893c8"))
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
	add_child(ground_pad)
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

func _build_board() -> void:
	if board != null:
		board.queue_free()
	board = Node3D.new()
	add_child(board)
	var w: float = float(cols) * ST + 0.5
	var h: float = float(rows) * ST + 0.5
	# Marco azul con barniz
	var fm := StandardMaterial3D.new()
	fm.albedo_color = _c(Color("2f86d6"), Color("1f4f86"))
	fm.roughness = 0.30
	fm.metallic = 0.25
	fm.clearcoat_enabled = true
	fm.clearcoat = 0.3
	var frame := MeshInstance3D.new()
	frame.mesh = TileMesh.slab((w + 0.45) * 0.5, (h + 0.45) * 0.5, 0.36, 0.16, 0.05, 5, 8)
	frame.material_override = fm
	frame.position.y = -0.245
	board.add_child(frame)
	# Losa clara con la cuadrícula de puntos
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = _plate_texture(w * 0.5, h * 0.5)
	pm.uv1_scale = Vector3(1.0 / w, 1.0 / h, 1.0)
	pm.uv1_offset = Vector3(0.5, 0.5, 0.0)
	pm.roughness = 0.85
	var plate := MeshInstance3D.new()
	plate.mesh = TileMesh.slab(w * 0.5, h * 0.5, 0.22, 0.09, 0.025, 5, 8)
	plate.material_override = pm
	plate.position.y = -0.15
	board.add_child(plate)

# ---------- Cámara ----------

func _process(_delta: float) -> void:
	_update_cam()

func _update_cam() -> void:
	cam_x = clampf(cam_x, -float(cols) * ST * 0.5, float(cols) * ST * 0.5)
	cam_z = clampf(cam_z, -float(rows) * ST * 0.5, float(rows) * ST * 0.5)
	var d: float = fit / zoom
	cam.position = Vector3(cam_x, d * cos(TILT), cam_z + d * sin(TILT))
	cam.look_at(Vector3(cam_x, 0.0, cam_z), Vector3.UP)

func _pan(delta: Vector2) -> void:
	var h: float = maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var upp: float = 2.0 * (fit / zoom) * tan(deg_to_rad(FOV * 0.5)) / h
	cam_x -= delta.x * upp
	cam_z -= delta.y * upp

func _zoom_by(f: float) -> void:
	zoom = clampf(zoom * f, 0.5, 3.0)

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
	if not active:
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
		press_tile = _tile_at(pos)
		press_start = pos
		moved = false
	else:
		if dragging and drag_tile != null:
			_return_home(drag_tile)
		dragging = false
		drag_tile = null
		moved = true
		press_tile = null
		pinch_d = _pinch_distance()

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
		if mode == "assoc" and press_tile != null and not press_tile.matched and not lock:
			_begin_drag(press_tile)
	if dragging and drag_tile != null:
		var g: Vector3 = _ground_point(pos)
		drag_tile.node.position.x = g.x
		drag_tile.node.position.z = g.z
	elif moved:
		_pan(delta)

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
	press_tile = null

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
		_glow(t, Color("3b82f6"), 1.2)
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
		t.halo = _ring_node(Color(col.r, col.g, col.b, 0.60), halo_mesh)
		t.halo.position.y = -0.075
		t.node.add_child(t.halo)
		var tw := t.halo.create_tween()
		tw.set_loops()
		tw.tween_property(t.halo, "scale", Vector3.ONE * 1.08, 0.9).set_trans(Tween.TRANS_SINE)
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
