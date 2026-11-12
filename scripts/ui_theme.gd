class_name UiTheme
extends RefCounted
## Tema de interfaz con aspecto de juguete: relieve, fuentes redondeadas, pieles de
## botón y logotipo dibujados por código, fondos de pantalla por shader
## (`assets/shaders/backdrop.gdshader`) e iconos SVG de `assets/icons/` (copia de
## @icons, licencia MIT) teñidos al vuelo.

const BODY := "res://fonts/fredoka-600.woff2"
const TITLE := "res://fonts/lilita-one-400.woff2"
const ICONS := "res://assets/icons/"
const PACK_COLORS := {
	"mat": "ffd966", "qui": "8ee3b0", "fis": "9cc8ff", "ing": "ffb199",
	"bio": "d1b3ff", "geo": "7fd6d1", "ast": "a9b8ff", "inf": "ffc27a",
}
const PACK_ICONS := {
	"mat": "calculator", "qui": "alembic", "fis": "atom", "ing": "book_open",
	"bio": "leaf", "geo": "globe", "ast": "planet", "inf": "laptop",
}
static var _icon_cache: Dictionary = {}

# ---------- Paleta ----------
# Colores fijos del tema claro. El tema oscuro se retiró, así que ya no hay cambio
# de paleta en caliente: son constantes.
const INK := Color("1d2a44")
const INK_SOFT := Color("6b7a99")
const BLUE := Color("3b82f6")
const BLUE_DARK := Color("21539f")
const CREAM := Color("fffdf7")
const ALT_BG := Color("dfe9ff")
const PILL_BG := Color("e8eefc")
const PILL_LINE := Color("c3cff0")
const HUD_BG := Color(1, 1, 1, 0.92)
const DIM := Color(0.06, 0.11, 0.26, 0.42)
const LOCKED := Color("c4cbd9")
const BADGE_BG := Color(1, 1, 1, 0.45)
const PLANT := Color("2f8f4e")
# ---------- Fondos de pantalla ----------
# El fondo de cada pantalla es un degradado de malla (focos de color muy suaves)
# con fichas redondeadas flotando en profundidad, viñeta y un grano fino que evita
# el bandeado. Se calcula en la GPU (`BACKDROP`), así que se ve nítido en cualquier
# pantalla y respira despacio. Sin archivos de imagen, como el resto del tema.
const BACKDROP := "res://assets/shaders/backdrop.gdshader"
## Focos: centro (x, y) en UV, radio (fracción del alto), intensidad y color.
const BG_BLOBS := [
	{"x": 0.50, "y": -0.05, "r": 0.55, "k": 0.55, "col": Color("ffffff")},
	{"x": 0.02, "y": 0.28, "r": 0.45, "k": 0.40, "col": Color("c9b6ff")},
	{"x": 1.00, "y": 0.62, "r": 0.45, "k": 0.35, "col": Color("93ebc6")},
	{"x": 0.20, "y": 1.02, "r": 0.45, "k": 0.30, "col": Color("ffd79e")},
]
const BG_TOP := Color("eaf4ff")
const BG_BOTTOM := Color("9dc4f5")
const BG_TILE := Color(1, 1, 1, 0.34)
const BG_VIGNETTE := 0.12
const BG_GRAIN := 0.012
# Velo de la pantalla de nivel completado: va sobre el tablero, así que es azul
# oscuro y translúcido en lugar del fondo claro de las demás pantallas.
const BG_SCRIM_TOP := Color(0.20, 0.34, 0.62, 0.0)
const BG_SCRIM_BOTTOM := Color(0.16, 0.30, 0.58, 0.52)
const BG_SCRIM_BLOB := Color("3a5a94")
static var _bg_shader: Shader = null
static var _bg_res := Vector2(960.0, 1707.0)

# ---------- Tipografía ----------
## Tamaños de texto en píxeles lógicos (el lienzo mide 960 de ancho). En un celular
## de 1080 px un píxel lógico equivale a poco más de un píxel físico, así que 36
## puntos lógicos se leen como ~15 sp en la mano: el cuerpo de texto ya no queda
## diminuto. Los títulos grandes no crecen porque el ancho es el mismo en todas
## las pantallas y se saldrían de la tarjeta.
const T_HERO := 96   # logotipo del menú
const T_WIN := 64    # título de nivel completado y letra del medallón
const T_HEAD := 56   # títulos de pantalla
const T_NAME := 40   # nombre de la materia en su tarjeta
const T_BODY := 36   # botones y textos principales
const T_SMALL := 30  # datos secundarios y avisos
const T_TINY := 28   # pies de pantalla y notas

static func title_font() -> Font:
	return load(TITLE)

## Color de la tarjeta de una materia: el de su paquete, o uno derivado de su id.
static func pack_color(id: String) -> Color:
	return Color(PACK_COLORS[id]) if PACK_COLORS.has(id) else Color.from_hsv(float(id.hash() % 360) / 360.0, 0.4, 1.0)

# ---------- Geometría ----------

## Distancia con signo a un rectángulo redondeado centrado en el origen (negativa dentro).
static func sdf(p: Vector2, half: Vector2, r: float) -> float:
	var q := Vector2(absf(p.x) - maxf(half.x - r, 0.0), absf(p.y) - maxf(half.y - r, 0.0))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r

static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (p - a - ab * t).length()

## Cobertura de un píxel a partir de la distancia: 1 dentro, 0 fuera, con 1 px de transición.
static func edge_cov(d: float) -> float:
	return clampf(0.5 - d, 0.0, 1.0)

# ---------- Texturas generadas ----------

## Piel de botón en gris (degradado vertical, borde inferior grueso y brillo arriba).
## Se colorea con `modulate_color`, así que una sola piel sirve para todos los botones.
static func button_skin(pressed: bool = false) -> ImageTexture:
	var size := Vector2i(112, 72)
	var half := Vector2(size.x, size.y) * 0.5
	var band: float = 4.0 if pressed else 9.0
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		var fy: float = float(y) + 0.5
		var t: float = fy / float(size.y)
		var base: float = lerpf(1.0, 0.88, t)
		for x in size.x:
			var d: float = sdf(Vector2(float(x) + 0.5, fy) - half, half - Vector2(1.0, 1.0), 24.0)
			var k: float = base
			if fy > float(size.y) - band:  # borde inferior: da el relieve
				k = lerpf(k, 0.60, clampf((fy - float(size.y) + band) / maxf(band * 0.6, 1.0), 0.0, 1.0))
			if t < 0.40:  # brillo superior
				k += 0.12 * pow(1.0 - t / 0.40, 2.0)
			k = lerpf(k, 0.74, clampf(d + 1.6, 0.0, 1.0))  # contorno
			img.set_pixel(x, y, Color(k, k, k, edge_cov(d)))
	return ImageTexture.create_from_image(img)

## Icono de `assets/icons/` teñido de `col` y cacheado por nombre, tamaño y color.
## El SVG se importa a 96 px (`svg/scale=6`) y se reduce a `size` para que quede nítido.
static func icon(name: String, size: int = 32, col: Color = INK) -> ImageTexture:
	var key: String = "%s|%d|%s" % [name, size, col.to_html(true)]
	if _icon_cache.has(key):
		return _icon_cache[key]
	var tex := load(ICONS + name + ".svg") as Texture2D
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != size or img.get_height() != size:
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	for y in size:
		for x in size:
			var a: float = img.get_pixel(x, y).a
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a))
	var out := ImageTexture.create_from_image(img)
	_icon_cache[key] = out
	return out

## Flecha para el botón de volver.
static func icon_chevron(size: int = 30, col: Color = INK) -> ImageTexture:
	return icon("arrow_left", size, col)

## Candado para las materias de pago.
static func icon_lock(size: int = 44, col: Color = INK) -> ImageTexture:
	return icon("lock", size, col)

## Planta de dominio: 0 = brote, 1 = hoja, 2 = árbol.
static func icon_plant(stage: int, size: int = 24, col: Color = PLANT) -> ImageTexture:
	var names: Array[String] = ["sprout", "leaf", "tree"]
	return icon(names[clampi(stage, 0, 2)], size, col)

## Estrella para la pantalla de nivel completado.
static func sparkle(size: int = 36, col: Color = Color("ffd45e")) -> ImageTexture:
	return icon("star", size, col)

## Nombre del icono de una materia (vacío si no hay).
static func pack_icon(id: String) -> String:
	return str(PACK_ICONS.get(id, ""))

## Logotipo: una ficha dorada con la cara azul, con bisel y brillo.
static func logo(size: int = 150) -> ImageTexture:
	var s := float(size)
	var half := Vector2(s, s) * 0.5
	var face := half - Vector2(s * 0.21, s * 0.21)
	var gold_a := Color("ffebad")
	var gold_b := Color("d59b1e")
	var blue_a := Color("6ba6ff")
	var blue_b := Color("2a63d4")
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		var fy: float = float(y) + 0.5
		for x in size:
			var q := Vector2(float(x) + 0.5, fy) - half
			var d: float = sdf(q, half - Vector2(1.0, 1.0), s * 0.24)
			var cov: float = edge_cov(d)
			if cov <= 0.0:
				continue
			var t: float = fy / s
			var col: Color = gold_a.lerp(gold_b, clampf(t * 1.15, 0.0, 1.0))
			var fd: float = sdf(q, face, s * 0.13)
			if fd < 0.0:
				col = blue_a.lerp(blue_b, clampf(t * 0.9, 0.0, 1.0))
			# Hueco alrededor de la cara azul
			col = col.darkened(0.42 * exp(-pow(absf(fd) / (s * 0.06), 2.0)))
			# Bisel: oscurece el borde y aclara un anillo por dentro (luz desde arriba)
			col = col.darkened(0.45 * exp(-pow((d + s * 0.026) / (s * 0.028), 2.0)))
			col = col.lightened(0.55 * exp(-pow((d + s * 0.075) / (s * 0.032), 2.0)) * clampf(0.55 - q.y / s, 0.0, 1.0))
			col = col.lerp(Color("7d5406"), clampf(d + 1.5, 0.0, 1.0) * 0.9)
			var hl: float = clampf(1.0 - (q + Vector2(s * 0.13, s * 0.15)).length() / (s * 0.5), 0.0, 1.0)
			col = col.lightened(0.16 * hl * hl)
			col.a = cov
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

# ---------- Fondos de pantalla ----------

static func _bg() -> Shader:
	if _bg_shader == null:
		_bg_shader = load(BACKDROP) as Shader
	return _bg_shader

## Tamaño del lienzo que usan los fondos (al cambiar el tamaño de la ventana).
static func bg_resize(size: Vector2) -> void:
	_bg_res = size

## Material del fondo de una pantalla. `kind`: "menu" (portada), "subjects" (lista
## de materias) o "scrim" (velo translúcido sobre el tablero, para el nivel
## completado). Las pantallas comparten paleta pero mueven los focos, así que el
## degradado se ve distinto en cada una sin perder la familia.
static func backdrop(kind: String = "menu") -> ShaderMaterial:
	var scrim: bool = kind == "scrim"
	var calm: float = 1.0 if kind == "menu" else 0.72  # la lista de materias, más tranquila
	var m := ShaderMaterial.new()
	m.shader = _bg()
	m.set_shader_parameter("res", _bg_res)
	m.set_shader_parameter("base_top", BG_SCRIM_TOP if scrim else BG_TOP)
	m.set_shader_parameter("base_bottom", BG_SCRIM_BOTTOM if scrim else BG_BOTTOM)
	for i in 4:
		var b: Dictionary = BG_BLOBS[i]
		var x: float = float(b["x"]) if kind == "menu" else 1.0 - float(b["x"])
		var k: float = float(b["k"]) * calm * (0.45 if scrim else 1.0)
		m.set_shader_parameter("blob%d" % i, Vector4(x, float(b["y"]), float(b["r"]), k))
		m.set_shader_parameter("col%d" % i, BG_SCRIM_BLOB if scrim else b["col"])
	m.set_shader_parameter("tile_col", Vector3(BG_TILE.r, BG_TILE.g, BG_TILE.b))
	m.set_shader_parameter("tile_amount", 0.0 if scrim else BG_TILE.a * calm)
	m.set_shader_parameter("tile_scale", 0.10)
	m.set_shader_parameter("tile_edge", 0.90 if kind == "menu" else 1.0)
	m.set_shader_parameter("vignette", BG_VIGNETTE * (1.5 if scrim else 1.0))
	m.set_shader_parameter("grain", BG_GRAIN)
	m.set_shader_parameter("speed", 0.05)
	return m

# ---------- Cajas de estilo ----------

## Tarjeta clara con sombra suave.
static func panel_box(pad: int = 30, radius: int = 34) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = CREAM
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.shadow_color = Color(0.09, 0.15, 0.30, 0.20)
	s.shadow_size = 18
	s.shadow_offset = Vector2(0, 8)
	return s

static func box(bg: Color, border: Color, bottom: int, pad_top: int, pad_bottom: int, radius: int = 18, all: int = 0, shadow: int = 0, shadow_alpha: float = 0.18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.border_width_bottom = bottom
	if all > 0:
		s.set_border_width_all(all)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = pad_top
	s.content_margin_bottom = pad_bottom
	if shadow > 0:
		s.shadow_color = Color(0.09, 0.15, 0.30, shadow_alpha)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.45)
	return s

## Caja con la piel de botón: se estira en nueve trozos y se tiñe con `modulate_color`.
static func _skin(tex: ImageTexture, tint: Color, pad_top: int, pad_bottom: int) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = 26
	s.texture_margin_right = 26
	s.texture_margin_top = 26
	s.texture_margin_bottom = 26
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	s.modulate_color = tint
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = pad_top
	s.content_margin_bottom = pad_bottom
	return s

static func _colors(th: Theme, type: String, c: Color) -> void:
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(k, type, c)

static func _button(th: Theme, type: String, base: Color, flat: ImageTexture, down: ImageTexture, ink: Color) -> void:
	th.set_stylebox("normal", type, _skin(flat, base, 11, 13))
	th.set_stylebox("hover", type, _skin(flat, base.lightened(0.10), 11, 13))
	th.set_stylebox("pressed", type, _skin(down, base.darkened(0.07), 16, 8))
	th.set_stylebox("hover_pressed", type, _skin(down, base.lightened(0.06), 16, 8))
	th.set_stylebox("disabled", type, _skin(flat, Color("c8d1e4"), 11, 13))
	th.set_stylebox("focus", type, StyleBoxEmpty.new())
	_colors(th, type, ink)

static func build() -> Theme:
	var th := Theme.new()
	th.default_font = load(BODY)
	th.default_font_size = T_BODY
	var flat := button_skin(false)
	var down := button_skin(true)
	_button(th, "Button", BLUE, flat, down, Color.WHITE)
	# Variante "Alt": botón secundario
	th.set_type_variation("Alt", "Button")
	_button(th, "Alt", ALT_BG, flat, down, INK)
	# Variante "Pill": opción de un grupo, rellena cuando está activa
	th.set_type_variation("Pill", "Button")
	var soft := PILL_BG
	var line := PILL_LINE
	th.set_stylebox("normal", "Pill", box(soft, line, 5, 10, 10, 30))
	th.set_stylebox("hover", "Pill", box(soft.lightened(0.35), line, 5, 10, 10, 30))
	th.set_stylebox("pressed", "Pill", box(BLUE, BLUE_DARK, 4, 12, 10, 30))
	th.set_stylebox("hover_pressed", "Pill", box(BLUE.lightened(0.08), BLUE_DARK, 4, 12, 10, 30))
	th.set_stylebox("focus", "Pill", StyleBoxEmpty.new())
	_colors(th, "Pill", INK)
	th.set_color("font_pressed_color", "Pill", Color.WHITE)
	th.set_color("font_hover_pressed_color", "Pill", Color.WHITE)
	th.set_color("font_color", "Label", INK)
	# Barra de desplazamiento fina y redondeada, sin flechas
	var none := ImageTexture.create_from_image(Image.create_empty(2, 2, false, Image.FORMAT_RGBA8))
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.45, 0.58, 0.80, 0.14)
	track.set_corner_radius_all(8)
	track.content_margin_left = 6
	track.content_margin_right = 6
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.32, 0.50, 0.80, 0.50)
	grab.set_corner_radius_all(8)
	grab.content_margin_left = 6
	grab.content_margin_right = 6
	th.set_icon("increment", "VScrollBar", none)
	th.set_icon("decrement", "VScrollBar", none)
	th.set_stylebox("scroll", "VScrollBar", track)
	th.set_stylebox("scroll_focus", "VScrollBar", track)
	th.set_stylebox("grabber", "VScrollBar", grab)
	th.set_stylebox("grabber_highlight", "VScrollBar", grab)
	th.set_stylebox("grabber_pressed", "VScrollBar", grab)
	return th
