class_name UiTheme
extends RefCounted
## Tema de interfaz con aspecto de juguete: relieve, fuentes redondeadas y texturas
## dibujadas por código (pieles de botón, iconos, logotipo y patrón de fondo).
## Aquí no se guardan archivos de imagen: todo se genera al arrancar.

const BODY := "res://fonts/fredoka-600.woff2"
const TITLE := "res://fonts/lilita-one-400.woff2"
const INK := Color("1d2a44")
const INK_SOFT := Color("6b7a99")
const BLUE := Color("3b82f6")
const BLUE_DARK := Color("21539f")
const CREAM := Color("fffdf7")
const PACK_COLORS := {
	"mat": "ffd966", "qui": "8ee3b0", "fis": "9cc8ff", "ing": "ffb199",
	"bio": "d1b3ff", "geo": "7fd6d1", "ast": "a9b8ff", "inf": "ffc27a",
}

static func title_font() -> Font:
	return load(TITLE)

static func pack_color(id: String) -> Color:
	if PACK_COLORS.has(id):
		return Color(PACK_COLORS[id])
	return Color.from_hsv(float(id.hash() % 360) / 360.0, 0.4, 1.0)

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

## Flecha "<" para el botón de volver.
static func icon_chevron(size: int = 30, col: Color = INK) -> ImageTexture:
	var s := float(size)
	var hw: float = s * 0.08
	var a := Vector2(0.32, 0.22) * s
	var b := Vector2(0.60, 0.50) * s
	var c := Vector2(0.32, 0.78) * s
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var d: float = minf(seg_dist(p, a, b), seg_dist(p, b, c)) - hw
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * edge_cov(d)))
	return ImageTexture.create_from_image(img)

## Candado (cuerpo redondeado y arco) para las materias de pago.
static func icon_lock(size: int = 44, col: Color = INK) -> ImageTexture:
	var s := float(size)
	var body_c := Vector2(s * 0.5, s * 0.64)
	var body := Vector2(s * 0.29, s * 0.21)
	var arc_c := Vector2(s * 0.5, s * 0.42)
	var arc_r: float = s * 0.15
	var arc_w: float = s * 0.06
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var d: float = sdf(p - body_c, body, s * 0.07)
			if p.y < arc_c.y:
				d = minf(d, absf((p - arc_c).length() - arc_r) - arc_w)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * edge_cov(d)))
	return ImageTexture.create_from_image(img)

## Estrella de cuatro puntas para la pantalla de nivel completado.
static func sparkle(size: int = 36, col: Color = Color("ffd45e")) -> ImageTexture:
	var c := float(size) * 0.5
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := (Vector2(float(x) + 0.5, float(y) + 0.5) - Vector2(c, c)) / c
			var v: float = sqrt(absf(p.x)) + sqrt(absf(p.y))
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * clampf((1.0 - v) * 7.0, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

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

## Tesela repetible con dos fichas giradas en diagonal (fondo de las pantallas).
static func pattern_tile(size: int = 110, col: Color = Color(1, 1, 1, 0.5), angle: float = 0.32) -> ImageTexture:
	var s := float(size)
	var half := Vector2.ONE * (s * 0.125)
	var ca: float = cos(angle)
	var sa: float = sin(angle)
	var centers: Array = [Vector2(s * 0.27, s * 0.27), Vector2(s * 0.77, s * 0.77)]
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var d: float = 1e9
			for c in centers:
				var q: Vector2 = p - (c as Vector2)
				q = Vector2(q.x * ca - q.y * sa, q.x * sa + q.y * ca)
				d = minf(d, sdf(q, half, s * 0.04))
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * edge_cov(d)))
	return ImageTexture.create_from_image(img)

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
	th.default_font_size = 28
	var flat := button_skin(false)
	var down := button_skin(true)
	_button(th, "Button", BLUE, flat, down, Color.WHITE)
	# Variante "Alt": botón secundario
	th.set_type_variation("Alt", "Button")
	_button(th, "Alt", Color("dfe9ff"), flat, down, INK)
	# Variante "Pill": opción de un grupo, rellena cuando está activa
	th.set_type_variation("Pill", "Button")
	var soft := Color("e8eefc")
	var line := Color("c3cff0")
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
