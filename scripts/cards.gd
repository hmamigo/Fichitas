class_name Cards
extends RefCounted
## Caras 2D de las losetas del mundo. Se dibujan con los controles del tema y se
## hornean una sola vez (FaceTex). No llevan botones ni filo dorado: el filo lo
## pone la losa 3D y el toque lo resuelve `Pick3D`.

static var _th: Theme

static func theme() -> Theme:
	if _th == null:
		_th = UiTheme.build()
	return _th

static func _label(text: String, size: int, color: Color, title: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if title:
		l.add_theme_font_override("font", UiTheme.title_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func _icon(name: String, size: int, col: Color) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UiTheme.icon(name, size, col)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## Cara de la loseta: color de la materia con filo fino. El borde redondeado lo
## recorta la malla de la cara, así que aquí no hace falta radio grande.
static func _face_box(col: Color, locked: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col.lightened(0.08)
	s.set_corner_radius_all(10)
	s.border_color = Color("d7dce6") if locked else col.lightened(0.62)
	s.set_border_width_all(3)
	return s

static func _root(w: int, h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.size = Vector2(w, h)
	c.theme = theme()
	return c

## Fondo plano a sangre: el recorte redondeado lo hace la malla, y así las
## esquinas de la textura no muestran el color de limpieza del viewport.
static func _bg(root: Control, col: Color) -> void:
	var bg := ColorRect.new()
	bg.color = col
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

## Tarjeta de una materia, con el mismo contenido que la de la pantalla 2D.
static func subject(d: Dictionary, w: int, h: int) -> Control:
	var locked: bool = bool(d.get("locked", false))
	var col: Color = d["color"]
	if locked:
		col = col.lerp(UiTheme.LOCKED, 0.55)
	var ink: Color = UiTheme.INK if not locked else UiTheme.INK.lerp(Color.WHITE, 0.15)
	var root := _root(w, h)
	_bg(root, col.lightened(0.08))
	var pc := PanelContainer.new()
	pc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pc.add_theme_stylebox_override("panel", _face_box(col, locked))
	root.add_child(pc)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	pc.add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(row)
	# El icono grande a la izquierda deja espacio horizontal para el progreso.
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(76, 76)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color("fffdf7")
	bs.set_corner_radius_all(24)
	bs.border_color = col.darkened(0.14)
	bs.set_border_width_all(3)
	bs.set_content_margin_all(4)
	badge.add_theme_stylebox_override("panel", bs)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_name: String = str(d.get("icon", ""))
	if icon_name != "":
		badge.add_child(_icon(icon_name, 48, ink))
	else:
		badge.add_child(_label(str(d["name"]), UiTheme.T_WIN - 8, ink, true))
	row.add_child(badge)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var name_txt: String = str(d["name"])
	# El icono y sus márgenes dejan este ancho; el nombre se encoge y, si aun así no
	# cabe (paquetes externos largos), se corta con elipsis en vez de a media palabra.
	var avail: float = float(w) - 130.0
	var tsize: int = UiTheme.fit_font_size(name_txt, UiTheme.title_font(), UiTheme.T_NAME - 6, 22, avail)
	var title := _label(name_txt, tsize, ink, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(title)
	var subtitle := _label(str(d.get("sub", "")), UiTheme.T_SMALL, ink)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(subtitle)
	# Barra de progreso de niveles
	var frac: float = float(d.get("frac", -1.0))
	if frac >= 0.0 and not locked:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = frac
		bar.custom_minimum_size = Vector2(0, 14)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var track := StyleBoxFlat.new()
		track.bg_color = Color(1, 1, 1, 0.65)
		track.set_corner_radius_all(7)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("f0b232")
		fill.set_corner_radius_all(7)
		bar.add_theme_stylebox_override("background", track)
		bar.add_theme_stylebox_override("fill", fill)
		v.add_child(bar)
	for key in ["sub2", "sub3"]:
		var txt: String = str(d.get(key, ""))
		if txt != "":
			var detail := _label(txt, UiTheme.T_TINY, ink if key == "sub2" else UiTheme.BLUE_DARK)
			detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			v.add_child(detail)
	if locked:
		var lk := _icon("lock", 34, UiTheme.INK)
		lk.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 14)
		root.add_child(lk)
	return root

## Rótulo plano (no se toca): icono, título, una línea y, debajo, una barra de color o de
## progreso (`frac` entre 0 y 1). Fondo transparente: se pinta directo sobre la mesa.
## Las medidas escalan con el alto `h` (128 px = 1 unidad del mundo).
static func label(d: Dictionary, w: int, h: int) -> Control:
	var sc: float = float(h) / 128.0
	var col: Color = d["color"]
	var ink: Color = d["ink"] if d.has("ink") else col.darkened(0.6)
	var root := _root(w, h)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", int(8 * sc))
	m.add_theme_constant_override("margin_right", int(8 * sc))
	m.add_theme_constant_override("margin_top", int(2 * sc))
	m.add_theme_constant_override("margin_bottom", int(6 * sc))
	root.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(8 * sc))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", int(14 * sc))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var has_icon: bool = str(d.get("icon", "")) != ""
	if has_icon:
		row.add_child(_icon(str(d["icon"]), int(70 * sc), ink))
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tv)
	# Los textos se encogen hasta caber (un tablero estrecho deja poco ancho)
	var avail: float = float(w) - 16.0 * sc - (84.0 * sc if has_icon else 0.0)
	var tsize: int = UiTheme.fit_font_size(str(d["name"]), UiTheme.title_font(), int(44 * sc), int(20 * sc), avail)
	var title := _label(str(d["name"]), tsize, ink, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(title)
	# El subtítulo va con el mismo `ink` que el título: sobre la mesa clara y con
	# puntos, un gris aclarado se perdía (contraste < 3:1 en las cabeceras).
	var ssize: int = UiTheme.fit_font_size(str(d.get("sub", "")), UiTheme.body_font(), int(30 * sc), int(16 * sc), avail)
	var sub := _label(str(d.get("sub", "")), ssize, ink)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(sub)
	# Barra de abajo: de progreso si hay `frac`, y si no una línea de color
	var frac: float = float(d.get("frac", -1.0))
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, (14 if frac >= 0.0 else 7) * sc)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bar)
	var track := Panel.new()
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tb := StyleBoxFlat.new()
	tb.bg_color = Color(col.r, col.g, col.b, 0.6 if frac >= 0.0 else 0.95)
	tb.set_corner_radius_all(int(8 * sc))
	track.add_theme_stylebox_override("panel", tb)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(track)
	if frac > 0.0:
		var fill := Panel.new()
		fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fill.anchor_right = clampf(frac, 0.0, 1.0)
		var fb := StyleBoxFlat.new()
		fb.bg_color = col.darkened(0.12)
		fb.set_corner_radius_all(int(8 * sc))
		fill.add_theme_stylebox_override("panel", fb)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(fill)
	return root

## Cara de una acción del menú: icono (o punto de color), título y subtítulo.
static func action(title: String, sub: String, icon: String, dot: bool, bg: Color, ink: Color, w: int, h: int) -> Control:
	var root := _root(w, h)
	_bg(root, bg.lightened(0.08))
	var pc := PanelContainer.new()
	pc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pc.add_theme_stylebox_override("panel", _face_box(bg))
	root.add_child(pc)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	pc.add_child(m)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(row)
	if dot:
		var d := TextureRect.new()
		d.texture = UiTheme.icon_dot(30, Color.WHITE)
		d.custom_minimum_size = Vector2(54, 54)
		d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		d.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(d)
	elif icon != "":
		row.add_child(_icon(icon, 54, ink))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var avail: float = float(w) - 104.0   # márgenes, icono y separación (peor caso)
	var title_label := _label(title, UiTheme.fit_font_size(title, UiTheme.title_font(), 36, 26, avail), ink, true)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(title_label)
	if sub != "":
		var subtitle := _label(sub, UiTheme.fit_font_size(sub, UiTheme.body_font(), UiTheme.T_SMALL, 24, avail), ink)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(subtitle)
	return root
# ---------- Estación de "Nivel completado" ----------
# Las caras de la victoria se dibujan al doble de resolución (WIN_K): llevan
# icono y texto. Las medidas de diseño (`w`, `h`...)
# van en píxeles base (128 por unidad del mundo); la textura mide WIN_K veces más.
const WIN_K := 2

static func _wrap(l: Label, width: int) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return l

## Cabecera plana (no se toca): trofeo, título y mensaje, sin fondo, sobre la mesa.
static func win_header(title: String, msg: String, w: int, h: int) -> Control:
	var k: int = WIN_K
	var root := _root(w * k, h * k)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10 * k)
	root.add_child(m)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4 * k)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var trophy := _icon("trofeo", 84 * k, Color.WHITE)
	trophy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(trophy)
	var inner: int = (w - 20) * k
	v.add_child(_wrap(_label(title, 38 * k, UiTheme.BLUE_DARK, true), inner))
	v.add_child(_wrap(_label(msg, 26 * k, UiTheme.INK), inner))
	return root

## Cara de la ficha resumen "+N": las parejas que no entran en la victoria. Va sobre una
## ficha más del álbum (cuerpo dorado y bisel), así que solo pinta la crema y el número.
static func more_face(n: int, px: int) -> Control:
	var root := _root(px, px)
	_bg(root, Color("fff7e3"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fff7e3")
	sb.set_corner_radius_all(maxi(int(float(px) * 0.08), 8))
	sb.set_content_margin_all(maxi(int(float(px) * 0.04), 4))
	sb.set_border_width_all(maxi(int(float(px) * 0.02), 3))
	sb.border_color = Color("e3d4ad")
	var pc := PanelContainer.new()
	pc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pc.add_theme_stylebox_override("panel", sb)
	root.add_child(pc)
	var more := _label("+%d" % n, int(float(px) * 0.40), UiTheme.INK, true)
	more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pc.add_child(more)
	return root

# ---------- Estación "¿Cómo jugar?" ----------
# Las caras de la ayuda llevan texto chico: se dibujan al doble (HELP_K), como la victoria.
const HELP_K := 2

## Cabecera plana de la ayuda (no se toca): icono, título y una línea de resumen.
static func help_header(title: String, sub: String, w: int, h: int) -> Control:
	var k: int = HELP_K
	var root := _root(w * k, h * k)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10 * k)
	root.add_child(m)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4 * k)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var ic := _icon("dialogo", 72 * k, Color.WHITE)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var inner: int = (w - 24) * k
	v.add_child(_label(title, 40 * k, UiTheme.BLUE_DARK, true))
	var sub_l := _label(sub, 27 * k, UiTheme.INK)
	sub_l.custom_minimum_size.x = inner
	v.add_child(sub_l)
	return root

## Paso de la ayuda: icono, título, explicación de hasta dos líneas y una barra del
## color del paso. Es plano: la ayuda solo informa, no se toca.
static func help_row(title: String, text: String, icon: String, col: Color, w: int, h: int) -> Control:
	var k: int = HELP_K
	var sc: float = float(h * k) / 128.0
	var root := _root(w * k, h * k)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", int(12 * sc))
	m.add_theme_constant_override("margin_right", int(12 * sc))
	m.add_theme_constant_override("margin_top", int(5 * sc))
	m.add_theme_constant_override("margin_bottom", int(6 * sc))
	root.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(6 * sc))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(12 * sc))
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var ic := _icon(icon, int(60 * sc), Color.WHITE)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", int(2 * sc))
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tv)
	var avail: float = float(w * k) - float(int(24 * sc) + int(60 * sc) + int(12 * sc))
	var tsize: int = UiTheme.fit_font_size(title, UiTheme.title_font(), int(36 * sc), int(22 * sc), avail)
	var t := _label(title, tsize, UiTheme.INK, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tv.add_child(t)
	var s := _label(text, int(25 * sc), UiTheme.INK)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size.x = avail
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(s)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, int(7 * sc))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bar)
	var track := Panel.new()
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tb := StyleBoxFlat.new()
	tb.bg_color = Color(col.r, col.g, col.b, 0.95)
	tb.set_corner_radius_all(int(8 * sc))
	track.add_theme_stylebox_override("panel", tb)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(track)
	return root

## Botón de la victoria: la acción principal dorada del menú.
static func win_button(text: String, w: int, h: int) -> Control:
	var k: int = WIN_K
	var col := UiTheme.GOLD
	var root := _root(w * k, h * k)
	_bg(root, col.lightened(0.08))
	var pc := PanelContainer.new()
	pc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pc.add_theme_stylebox_override("panel", _face_box(col))
	root.add_child(pc)
	var l := _label(text, 40 * k, UiTheme.GOLD_INK, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pc.add_child(l)
	return root
