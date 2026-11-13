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
	var ink: Color = UiTheme.INK if not locked else UiTheme.INK.lerp(Color.WHITE, 0.35)
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
	var title := _label(str(d["name"]), UiTheme.T_NAME - 6, ink, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
		var lk := _icon("lock", 34, UiTheme.INK_SOFT)
		lk.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 14)
		root.add_child(lk)
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
	var title_label := _label(title, 36, ink, true)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(title_label)
	if sub != "":
		var subtitle := _label(sub, UiTheme.T_TINY, ink)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(subtitle)
	return root