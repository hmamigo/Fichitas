class_name GameUI
extends CanvasLayer
## Pantallas: menú, materias, barra de juego y nivel completado. Solo dibuja y emite señales.

signal back_pressed
signal next_pressed
signal sound_toggled(on: bool)
signal vib_toggled(on: bool)
signal album_pressed

var hud_bar: Control
var lv_label: Label
var menu: Control
var sound_btn: Button
var vib_btn: Button
var subjects: Control
var toast_label: Label
var win: Control
var album: Control
var album_grid: GridContainer
var album_chips: HBoxContainer
var album_name: Label
var album_count: Label
var win_title: Label
var win_msg: Label
var win_btn: Button
var dom_grid: GridContainer
var _th: Theme
var _win_card: Control
var _album_card: Control
var _album_detail: Control
var _detail_card: Control
var _detail_a: TextureRect
var _detail_b: TextureRect
var _detail_fact: Label
var _album_data: Array = []
var _album_sel: int = 0
var _bgs: Array = []   # materiales de los fondos, para reajustar el lienzo
var _toast_tween: Tween
# Piezas animadas del menú: halos, fichas decorativas y destellos.
var _menu_logo: TextureRect
var _menu_logo_wrap: Control
var _menu_logo_glow: TextureRect
var _menu_title_wrap: Control
var _menu_title_glow: TextureRect
var _menu_subtitle: Control
var _menu_footer: Control
var _menu_deco: Array = []
var _menu_title_tiles: Array = []
var _win_medal: Control
var _menu_tween: Tween
var _menu_clock: float = 0.0
var _logo_base: Vector2 = Vector2.ZERO

func _ready() -> void:
	_th = UiTheme.build()
	_build_hud()
	_build_menu()
	_build_subjects()
	_build_win()
	_build_album()
	get_viewport().size_changed.connect(_update_columns)
	_update_columns()
	hide_all()

# ---------- Utilidades ----------

func _label(text: String, size: int, title: bool = false, color: Color = Color(0, 0, 0, 0), autowrap: bool = false) -> Label:
	var l := Label.new()
	if color.a == 0.0:
		color = UiTheme.INK
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if title:
		l.add_theme_font_override("font", UiTheme.title_font())
		var oc := UiTheme.CREAM
		l.add_theme_color_override("font_outline_color", Color(oc.r, oc.g, oc.b, 0.92))
		l.add_theme_constant_override("outline_size", maxi(5, int(size / 7.0)))
	if autowrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_constant_override("line_spacing", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## Fondo de pantalla: degradado de malla con fichas flotantes, por shader
## (`UiTheme.backdrop`). El material se guarda para reajustarlo al redimensionar.
func _backdrop(parent: Control, kind: String) -> void:
	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.material = UiTheme.backdrop(kind)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	_bgs.append(bg.material)

## Contorno claro alrededor del texto, para que se lea sobre la escena 3D.
func _halo(l: Label) -> Label:
	var oc := UiTheme.CREAM
	l.add_theme_color_override("font_outline_color", Color(oc.r, oc.g, oc.b, 0.95))
	l.add_theme_constant_override("outline_size", 8)
	return l

## Pantalla completa con su propio fondo (`kind`: ver `UiTheme.backdrop`).
func _screen(kind: String) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.theme = _th
	add_child(c)
	if kind != "none":
		_backdrop(c, kind)
	return c

## Deja pasar los toques a la escena 3D: solo los botones siguen capturándolos.
func _pass_through(c: Node) -> void:
	if c is Control:
		var k := c as Control
		if not (k is BaseButton):
			k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in c.get_children():
		_pass_through(ch)

## Tarjeta clara con sombra; devuelve la caja vertical donde poner el contenido.
func _panel(parent: Control, width: int, pad: int = 30, style: StyleBoxFlat = null) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", style if style != null else UiTheme.panel_box(pad))
	pc.custom_minimum_size = Vector2(width, 0)
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	pc.add_child(v)
	return v

## Interruptor de ajustes: pastilla que se rellena cuando está activa.
## `icon_on`/`icon_off` se tiñen según el estado (blanco al estar activo).
func _toggle(text: String, icon_on: String, icon_off: String, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.theme_type_variation = "Pill"
	b.custom_minimum_size = Vector2(0, 76)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("h_separation", 10)
	b.add_theme_font_size_override("font_size", UiTheme.T_SMALL)
	b.set_meta("icon_on", icon_on)
	b.set_meta("icon_off", icon_off)
	b.toggled.connect(func(on: bool) -> void: _paint_toggle(b, on))
	parent.add_child(b)
	return b

func _paint_toggle(b: Button, on: bool) -> void:
	var icon_name: String = str(b.get_meta("icon_on" if on else "icon_off"))
	b.icon = UiTheme.icon(icon_name, 34, Color.WHITE if on else UiTheme.INK)

## Punto de color del modo: blanco cuando la pastilla está activa.
func _star_icon(size: int, col: Color) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UiTheme.sparkle(size, col)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## Micro-rebote de los botones al pasar el puntero, pulsar o tocar.
func _juice(b: Button) -> void:
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func() -> void: _juice_scale(b, 1.025, 0.12))
	b.mouse_exited.connect(func() -> void: _juice_scale(b, 1.0, 0.16))
	b.button_down.connect(func() -> void: _juice_scale(b, 0.97, 0.08))
	b.button_up.connect(func() -> void: _juice_scale(b, 1.0, 0.14))

func _juice_scale(b: Control, s: float, secs: float) -> void:
	var old: Variant = null
	if b.has_meta("juice"):
		old = b.get_meta("juice")
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * s, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	b.set_meta("juice", tw)

## Ficha esmaltada: filo dorado, borde inferior grueso y cara de color. Devuelve el
## aro; el contenido va dentro de `get_child(0)` (la cara).
func _enamel_tile(min_size: Vector2, face_col: Color, pad_h: int = 0, radius: int = 26) -> PanelContainer:
	var rim := PanelContainer.new()
	rim.custom_minimum_size = min_size
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color("f0b232")
	rs.set_corner_radius_all(radius)
	rs.border_color = Color("a8690f")
	rs.border_width_bottom = 9
	rs.set_content_margin_all(7)
	rs.shadow_color = Color(0.08, 0.16, 0.34, 0.30)
	rs.shadow_size = 12
	rs.shadow_offset = Vector2(0, 8)
	rim.add_theme_stylebox_override("panel", rs)
	var face := PanelContainer.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := StyleBoxFlat.new()
	fs.bg_color = face_col
	fs.set_corner_radius_all(radius - 7)
	fs.border_color = face_col.lightened(0.55)
	fs.set_border_width_all(3)
	fs.content_margin_left = pad_h
	fs.content_margin_right = pad_h
	face.add_theme_stylebox_override("panel", fs)
	rim.add_child(face)
	rim.resized.connect(func() -> void: rim.pivot_offset = rim.size * 0.5)
	return rim

## Botón de volver: ficha esmaltada con un botón transparente encima que cubre toda la ficha.
func _back_tile(text: String) -> Control:
	var back_tile := _enamel_tile(Vector2(0, 90), Color("dfeaff"), 16)
	var bface := back_tile.get_child(0) as Control
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 8)
	brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chev := TextureRect.new()
	chev.texture = UiTheme.icon_chevron(34, UiTheme.INK)
	chev.custom_minimum_size = Vector2(34, 34)
	chev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brow.add_child(chev)
	var btxt := _label(text, UiTheme.T_BODY, true, UiTheme.INK)
	btxt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brow.add_child(btxt)
	bface.add_child(brow)
	var back := Button.new()
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		back.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	back.pressed.connect(func() -> void: back_pressed.emit())
	back.mouse_entered.connect(func() -> void: _juice_scale(back_tile, 1.03, 0.12))
	back.mouse_exited.connect(func() -> void: _juice_scale(back_tile, 1.0, 0.16))
	back.button_down.connect(func() -> void: _juice_scale(back_tile, 0.95, 0.08))
	back.button_up.connect(func() -> void: _juice_scale(back_tile, 1.0, 0.14))
	back_tile.add_child(back)  # sobre toda la ficha, no solo sobre el texto
	return back_tile

## Rótulo hecho con fichas: una ficha esmaltada por letra, con el filo dorado y el
## borde inferior grueso de las fichas del tablero.
func _title_tiles(word: String) -> HBoxContainer:
	var faces: Array = [
		[Color("fff0a8"), Color("6b4a14")], [Color("b9f3d3"), Color("1f6b45")],
		[Color("bfdcff"), Color("1d4f9a")], [Color("ffd3c2"), Color("9a3d1f")],
		[Color("e3d7ff"), Color("4b3a9a")],
	]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_title_tiles.clear()
	for i in word.length():
		var f: Array = faces[i % faces.size()]
		var rim := _enamel_tile(Vector2(98, 104), f[0])
		var l := _label(word.substr(i, 1), 90, true, f[1])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		(rim.get_child(0) as Control).add_child(l)
		row.add_child(rim)
		_menu_title_tiles.append(rim)
	return row

## Fichas y destellos flotantes alrededor del menú. Se colocan por fracción de
## pantalla y se mecen en `_process`, sin tapar los controles.
func _build_menu_deco(parent: Control) -> void:
	var specs: Array = [
		{"rel": Vector2(0.075, 0.17), "size": 58, "color": UiTheme.LAVENDER, "rot": -14.0, "star": false},
		{"rel": Vector2(0.925, 0.13), "size": 48, "color": UiTheme.GOLD, "rot": 12.0, "star": false},
		{"rel": Vector2(0.940, 0.60), "size": 62, "color": UiTheme.MINT, "rot": 16.0, "star": false},
		{"rel": Vector2(0.060, 0.66), "size": 52, "color": UiTheme.CORAL, "rot": -11.0, "star": false},
		{"rel": Vector2(0.140, 0.32), "size": 30, "color": UiTheme.GOLD, "rot": 0.0, "star": true},
		{"rel": Vector2(0.860, 0.30), "size": 26, "color": UiTheme.MINT, "rot": 0.0, "star": true},
		{"rel": Vector2(0.930, 0.82), "size": 24, "color": UiTheme.LAVENDER, "rot": 0.0, "star": true},
		{"rel": Vector2(0.080, 0.88), "size": 22, "color": UiTheme.CORAL, "rot": 0.0, "star": true},
		{"rel": Vector2(0.200, 0.10), "size": 18, "color": UiTheme.SKY, "rot": 0.0, "star": true},
	]
	for spec in specs:
		var size: float = float(spec["size"])
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.size = Vector2(size, size)
		parent.add_child(holder)
		var vis: Control
		if bool(spec["star"]):
			var t := TextureRect.new()
			t.texture = UiTheme.sparkle(int(size), spec["color"])
			t.custom_minimum_size = Vector2(size, size)
			t.size = Vector2(size, size)
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vis = t
		else:
			var p := PanelContainer.new()
			p.custom_minimum_size = Vector2(size, size)
			p.size = Vector2(size, size)
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sb := StyleBoxFlat.new()
			sb.bg_color = spec["color"]
			sb.set_corner_radius_all(int(size * 0.28))
			sb.border_color = (spec["color"] as Color).darkened(0.38)
			sb.border_width_bottom = maxi(3, int(size * 0.10))
			sb.shadow_color = Color(0.08, 0.16, 0.32, 0.20)
			sb.shadow_size = 10
			sb.shadow_offset = Vector2(0, 4)
			p.add_theme_stylebox_override("panel", sb)
			var center := CenterContainer.new()
			center.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			p.add_child(center)
			var dot := TextureRect.new()
			dot.texture = UiTheme.icon_dot(int(size * 0.30), Color(1, 1, 1, 0.55))
			dot.custom_minimum_size = Vector2(size * 0.30, size * 0.30)
			dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.add_child(dot)
			vis = p
		vis.position = Vector2.ZERO
		vis.pivot_offset = Vector2(size, size) * 0.5
		vis.rotation = deg_to_rad(float(spec["rot"]))
		holder.add_child(vis)
		var i: int = _menu_deco.size()
		_menu_deco.append({
			"wrap": holder, "vis": vis, "rel": spec["rel"], "size": size,
			"rot": deg_to_rad(float(spec["rot"])),
			"phase": float(i) * 1.37,
			"amp": 7.0 + float(i % 3) * 2.0,
			"star": bool(spec["star"]),
		})

func _layout_menu_deco() -> void:
	if _menu_deco.is_empty():
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	for d in _menu_deco:
		var holder: Control = d["wrap"]
		var size: float = float(d["size"])
		var rel: Vector2 = d["rel"]
		holder.position = Vector2(vp.x * rel.x, vp.y * rel.y) - Vector2(size, size) * 0.5

## Entrada escalonada del menú: el logotipo, el título y la tarjeta aparecen con
## un pequeño rebote. Los halos y las fichas siguen vivos en `_process`.
func _animate_menu() -> void:
	if _menu_tween != null:
		_menu_tween.kill()
	var parts: Array = [_menu_logo_wrap, _menu_title_wrap, _menu_subtitle, _menu_footer]
	for p in parts:
		if p != null:
			p.modulate.a = 0.0
			p.scale = Vector2(0.94, 0.94)
	for d in _menu_deco:
		(d["wrap"] as Control).modulate.a = 0.0
	await get_tree().process_frame
	for p in parts:
		if p != null:
			p.pivot_offset = p.size * 0.5
	_menu_tween = create_tween()
	_menu_tween.set_parallel(true)
	_menu_tween.tween_property(_menu_logo_wrap, "modulate:a", 1.0, 0.30)
	_menu_tween.tween_property(_menu_logo_wrap, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_menu_tween.tween_property(_menu_title_wrap, "modulate:a", 1.0, 0.32).set_delay(0.07)
	_menu_tween.tween_property(_menu_title_wrap, "scale", Vector2.ONE, 0.50).set_delay(0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_menu_tween.tween_property(_menu_subtitle, "modulate:a", 1.0, 0.30).set_delay(0.14)
	_menu_tween.tween_property(_menu_subtitle, "scale", Vector2.ONE, 0.45).set_delay(0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_menu_tween.tween_property(_menu_footer, "modulate:a", 1.0, 0.30).set_delay(0.30)
	for i in _menu_deco.size():
		var w: Control = _menu_deco[i]["wrap"]
		_menu_tween.tween_property(w, "modulate:a", 1.0, 0.35).set_delay(0.06 + float(i) * 0.035)

## Movimiento ambiente del menú (solo mientras está visible).
func _process(delta: float) -> void:
	_menu_clock += delta
	if _win_medal != null and win != null and win.visible:
		_win_medal.rotation = sin(_menu_clock * 1.5) * 0.07
	if menu == null or not menu.visible:
		return
	if _menu_logo != null:
		_menu_logo.position.y = _logo_base.y + sin(_menu_clock * 1.15) * 5.0
		_menu_logo.rotation = sin(_menu_clock * 0.90) * 0.035
	if _menu_logo_glow != null:
		_menu_logo_glow.modulate.a = 0.48 + 0.15 * (0.5 + 0.5 * sin(_menu_clock * 1.15 + 0.5))
	if _menu_title_glow != null:
		_menu_title_glow.modulate.a = 0.40 + 0.14 * (0.5 + 0.5 * sin(_menu_clock * 0.85 + 1.1))
	for i in _menu_title_tiles.size():
		var tile: Control = _menu_title_tiles[i]
		tile.rotation = sin(_menu_clock * 0.9 + float(i) * 0.8) * 0.045
	for d in _menu_deco:
		var vis: Control = d["vis"]
		var ph: float = float(d["phase"])
		vis.position.y = sin(_menu_clock * 0.90 + ph) * float(d["amp"])
		vis.rotation = float(d["rot"]) + sin(_menu_clock * 0.70 + ph) * 0.06
		if bool(d["star"]):
			vis.modulate.a = 0.50 + 0.40 * (0.5 + 0.5 * sin(_menu_clock * 1.60 + ph))

## Pequeño rebote al aparecer una tarjeta.
func _pop(c: Control) -> void:
	c.scale = Vector2(0.92, 0.92)
	await get_tree().process_frame
	c.pivot_offset = c.size * 0.5
	var tw := create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_all() -> void:
	hud_bar.visible = false
	menu.visible = false
	subjects.visible = false
	win.visible = false
	album.visible = false

# ---------- Construcción ----------

func _build_hud() -> void:
	var m := MarginContainer.new()
	m.theme = _th
	m.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 14)
	add_child(m)
	hud_bar = m
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	m.add_child(h)
	h.add_child(_back_tile("Atrás"))
	# Nivel y modo: placa crema con el mismo filo dorado
	var plate := _enamel_tile(Vector2(0, 90), Color("fffdf7"), 28)
	lv_label = _label("", UiTheme.T_BODY, true, UiTheme.BLUE_DARK)
	lv_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	(plate.get_child(0) as Control).add_child(lv_label)
	h.add_child(plate)

func _build_menu() -> void:
	menu = _screen("none")  # sin fondo: detrás se ve el suelo de cubos 3D
	# Velo suave: enfría el centro de la escena y da aire a los textos sin tapar los cubos.
	var veil := TextureRect.new()
	veil.texture = UiTheme.radial_glow(256, Color("e8f3ff"))
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.modulate = Color(1, 1, 1, 0.34)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(veil)

	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 30)
	menu.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	# Logotipo con halo cálido y balanceo lento.
	var logo_wrap := Control.new()
	logo_wrap.custom_minimum_size = Vector2(210, 210)
	logo_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(logo_wrap)
	_menu_logo_wrap = logo_wrap
	_menu_logo = TextureRect.new()
	_menu_logo.texture = UiTheme.logo(165)
	_menu_logo.custom_minimum_size = Vector2(165, 165)
	_menu_logo.size = Vector2(165, 165)
	_menu_logo.position = Vector2(22, 22)
	_logo_base = _menu_logo.position
	_menu_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_menu_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_menu_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_wrap.add_child(_menu_logo)
	# Título: una ficha esmaltada por letra, con filo dorado como las del tablero.
	var title_wrap := CenterContainer.new()
	title_wrap.custom_minimum_size = Vector2(0, 118)
	title_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title_wrap)
	_menu_title_wrap = title_wrap
	title_wrap.add_child(_title_tiles("FICHITAS"))
	# Descripción en una pastilla translúcida, para que se lea sobre los cubos.
	var sub_pill := PanelContainer.new()
	sub_pill.add_theme_stylebox_override("panel", UiTheme.box(Color("fffdf7"), Color("e6d6a6"), 4, 12, 12, 28, 0, 10, 0.16))
	sub_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sub_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sub_pill)
	_menu_subtitle = sub_pill
	var sub_row := HBoxContainer.new()
	sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sub_row.add_theme_constant_override("separation", 10)
	sub_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_pill.add_child(sub_row)
	sub_row.add_child(_label("Empareja fichas y practica a tu ritmo.", UiTheme.T_BODY, false, UiTheme.INK))

	var gap_mid := Control.new()
	gap_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap_mid.size_flags_stretch_ratio = 2.0
	v.add_child(gap_mid)
	# Ajustes: una pastilla translúcida bajo las losetas 3D del menú
	var opts_pill := PanelContainer.new()
	opts_pill.add_theme_stylebox_override("panel", UiTheme.box(Color("fffdf7"), Color("e6d6a6"), 4, 10, 10, 28, 0, 10, 0.30))
	opts_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	opts_pill.custom_minimum_size = Vector2(560, 0)
	v.add_child(opts_pill)
	var opts := HBoxContainer.new()
	opts.alignment = BoxContainer.ALIGNMENT_CENTER
	opts.add_theme_constant_override("separation", 12)
	opts_pill.add_child(opts)
	var album_btn := Button.new()
	album_btn.text = "Álbum"
	album_btn.theme_type_variation = "Gold"
	album_btn.custom_minimum_size = Vector2(0, 76)
	album_btn.icon = UiTheme.icon("book_open", 34, UiTheme.GOLD_INK)
	album_btn.add_theme_constant_override("h_separation", 10)
	album_btn.add_theme_font_size_override("font_size", UiTheme.T_SMALL)
	album_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	album_btn.pressed.connect(func() -> void: album_pressed.emit())
	opts.add_child(album_btn)
	_juice(album_btn)
	sound_btn = _toggle("Sonido", "speaker", "speaker_mute", opts)
	sound_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_btn.toggled.connect(func(on: bool) -> void: sound_toggled.emit(on))
	_juice(sound_btn)
	vib_btn = _toggle("Vibración", "rumble_phone", "mobile_phone", opts)
	vib_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vib_btn.toggled.connect(func(on: bool) -> void: vib_toggled.emit(on))
	_juice(vib_btn)
	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", UiTheme.box(Color("fffdf7"), Color("e6d6a6"), 3, 8, 8, 20, 0, 8, 0.14))
	foot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)
	_menu_footer = foot
	var foot_row := HBoxContainer.new()
	foot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	foot_row.add_theme_constant_override("separation", 8)
	foot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(foot_row)
	foot_row.add_child(_label("Sin cronómetro y sin puntuación.", UiTheme.T_TINY, false, UiTheme.INK))
	# La capa es solo texto: los toques van a las losetas 3D (menos los ajustes)
	_pass_through(menu)

func _build_subjects() -> void:
	subjects = _screen("none")  # sin fondo: las losetas 3D son la lista
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 26)
	subjects.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	m.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	v.add_child(head)
	head.add_child(_back_tile("Menú"))
	var plate := _enamel_tile(Vector2(0, 96), Color("fffdf7"), 28)
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(plate)
	var hb := VBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 0)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(plate.get_child(0) as Control).add_child(hb)
	var t := _label("Elige una materia", UiTheme.T_HEAD - 6, true, UiTheme.BLUE_DARK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hb.add_child(t)
	var st := _label("Cada materia tiene sus propios niveles.", UiTheme.T_SMALL, false, UiTheme.INK_SOFT)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hb.add_child(st)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap)
	toast_label = _halo(_label("", UiTheme.T_SMALL, false, UiTheme.INK, true))
	v.add_child(toast_label)
	# La capa no debe tragarse los toques: las losetas viven en la escena 3D
	_pass_through(subjects)

const WIN_PAD := 34        # margen interior de la tarjeta de nivel completado
const WIN_MAX_W := 860     # ancho máximo de esa tarjeta
const WIN_MIN_W := 660     # ancho mínimo (para que quepa el título)
const DOM_MAX := 148       # lado máximo de cada miniatura de pareja
const DOM_SEP := 10        # separación entre miniaturas

func _build_win() -> void:
	win = Control.new()
	win.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win.theme = _th
	add_child(win)
	var dim := ColorRect.new()
	dim.color = Color(0.86, 0.93, 1.0, 0.46)  # velo claro: el tablero y los cubos siguen brillantes
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win.add_child(center)
	var card := _panel(center, WIN_MAX_W, WIN_PAD, UiTheme.menu_panel_box(WIN_PAD))
	_win_card = card.get_parent() as Control
	# Medalla: una ficha dorada con destellos, que se balancea despacio
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_win_medal = _enamel_tile(Vector2(132, 132), Color("fff0a8"))
	var spr := TextureRect.new()
	spr.texture = UiTheme.icon("stars", 88, Color("d08a12"))
	spr.custom_minimum_size = Vector2(88, 88)
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_win_medal.get_child(0) as Control).add_child(spr)
	row.add_child(_win_medal)
	card.add_child(row)
	win_title = _label("", UiTheme.T_WIN, true, UiTheme.BLUE_DARK)
	card.add_child(win_title)
	win_msg = _label("", UiTheme.T_BODY, false, UiTheme.INK, true)
	card.add_child(win_msg)
	dom_grid = GridContainer.new()
	dom_grid.columns = 5
	dom_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dom_grid.add_theme_constant_override("h_separation", DOM_SEP)
	dom_grid.add_theme_constant_override("v_separation", DOM_SEP)
	card.add_child(dom_grid)
	win_btn = Button.new()
	win_btn.theme_type_variation = "Gold"  # la misma acción principal dorada del menú
	win_btn.custom_minimum_size = Vector2(0, 96)
	win_btn.pressed.connect(func() -> void: next_pressed.emit())
	card.add_child(win_btn)

# ---------- Álbum ----------

const ALBUM_W := 860       # ancho de la tarjeta del álbum
const ALBUM_PAD := 30
const CHIP_SEP := 8        # separación entre las pestañas de materia

func _build_album() -> void:
	album = Control.new()
	album.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	album.theme = _th
	add_child(album)
	var dim := ColorRect.new()
	dim.color = Color(0.86, 0.93, 1.0, 0.46)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # los toques no deben llegar a la escena 3D de detrás
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	album.add_child(dim)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 26)
	album.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	m.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	v.add_child(head)
	head.add_child(_back_tile("Menú"))
	var plate := _enamel_tile(Vector2(0, 96), Color("fffdf7"), 28)
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(plate)
	var hb := VBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 0)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(plate.get_child(0) as Control).add_child(hb)
	var t := _label("Álbum", UiTheme.T_HEAD - 6, true, UiTheme.BLUE_DARK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hb.add_child(t)
	var st := _label("Las parejas que ya dominas.", UiTheme.T_SMALL, false, UiTheme.INK_SOFT)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hb.add_child(st)
	# Tarjeta central: pestañas de materia, nombre, cuenta y cuadrícula de parejas (sin scroll)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(center)
	var card := _panel(center, ALBUM_W, ALBUM_PAD, UiTheme.menu_panel_box(ALBUM_PAD))
	_album_card = card.get_parent() as Control
	album_chips = HBoxContainer.new()
	album_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	album_chips.add_theme_constant_override("separation", CHIP_SEP)
	card.add_child(album_chips)
	album_name = _label("", UiTheme.T_HEAD - 8, true, UiTheme.BLUE_DARK)
	card.add_child(album_name)
	album_count = _label("", UiTheme.T_SMALL, false, UiTheme.INK_SOFT)
	card.add_child(album_count)
	album_grid = GridContainer.new()
	album_grid.columns = 5
	album_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	album_grid.add_theme_constant_override("h_separation", DOM_SEP)
	album_grid.add_theme_constant_override("v_separation", DOM_SEP)
	card.add_child(album_grid)
	_build_album_detail()

## Ventana con las dos fichas de una pareja dominada y su dato curioso.
func _build_album_detail() -> void:
	_album_detail = Control.new()
	_album_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_album_detail.visible = false
	album.add_child(_album_detail)
	var ddim := ColorRect.new()
	ddim.color = Color(0.06, 0.11, 0.26, 0.55)
	ddim.mouse_filter = Control.MOUSE_FILTER_STOP
	ddim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ddim.gui_input.connect(_on_detail_dim_input)  # tocar fuera de la tarjeta la cierra
	_album_detail.add_child(ddim)
	var dcenter := CenterContainer.new()
	dcenter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dcenter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_album_detail.add_child(dcenter)
	var dcard := _panel(dcenter, 780, 34, UiTheme.menu_panel_box(34))
	_detail_card = dcard.get_parent() as Control
	_detail_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var pair_row := HBoxContainer.new()
	pair_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pair_row.add_theme_constant_override("separation", 28)
	dcard.add_child(pair_row)
	_detail_a = _detail_face(pair_row)
	_detail_b = _detail_face(pair_row)
	dcard.add_child(_label("Dato curioso", UiTheme.T_HEAD - 8, true, UiTheme.BLUE_DARK))
	_detail_fact = _label("", UiTheme.T_BODY, false, UiTheme.INK, true)
	_detail_fact.custom_minimum_size = Vector2(680, 0)
	dcard.add_child(_detail_fact)
	var close := Button.new()
	close.theme_type_variation = "Gold"
	close.text = "Cerrar"
	close.custom_minimum_size = Vector2(0, 96)
	close.pressed.connect(func() -> void: _album_detail.visible = false)
	dcard.add_child(close)

func _detail_face(parent: Control) -> TextureRect:
	var rim := _enamel_tile(Vector2(300, 300), Color("fffdf7"), 8)
	var img := TextureRect.new()
	img.custom_minimum_size = Vector2(270, 270)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(rim.get_child(0) as Control).add_child(img)
	parent.add_child(rim)
	return img

func _on_detail_dim_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		_album_detail.visible = false

# ---------- API ----------

## opts: {sound, vib, vib_visible}. Las acciones están en las losetas 3D del menú.
func show_menu(opts: Dictionary = {}) -> void:
	hide_all()
	var snd: bool = bool(opts.get("sound", true))
	var vb: bool = bool(opts.get("vib", true))
	sound_btn.set_pressed_no_signal(snd)
	_paint_toggle(sound_btn, snd)
	vib_btn.visible = bool(opts.get("vib_visible", false))
	vib_btn.set_pressed_no_signal(vb)
	_paint_toggle(vib_btn, vb)
	menu.visible = true
	_layout_menu_deco()
	_animate_menu()

func show_hud(text: String) -> void:
	hide_all()
	lv_label.text = text
	hud_bar.visible = true

## Las tarjetas de materia son losetas 3D: aquí solo queda la cabecera y el aviso.
func show_subjects() -> void:
	hide_all()
	toast_label.text = ""
	toast_label.modulate.a = 1.0
	_update_columns()
	subjects.visible = true

## Álbum. data: Array de {id, name, icon, color, locked, pairs: [{a, b, fact, stage}]}.
## Las parejas dominadas (stage 2) se pueden abrir; las demás aparecen atenuadas.
func show_album(data: Array) -> void:
	hide_all()
	_album_data = data
	_album_detail.visible = false
	if _album_sel < 0 or _album_sel >= data.size() or bool((data[_album_sel] as Dictionary).get("locked", false)):
		_album_sel = 0
	_fill_album_chips()
	_album_select(_album_sel)
	album.visible = true
	if _album_card != null:
		_pop(_album_card)

## Cierra la ventana de dato curioso si está abierta; devuelve si había algo que cerrar.
func close_album_detail() -> bool:
	if _album_detail != null and _album_detail.visible:
		_album_detail.visible = false
		return true
	return false

func _fill_album_chips() -> void:
	for c in album_chips.get_children():
		album_chips.remove_child(c)
		c.queue_free()
	var n: int = _album_data.size()
	if n == 0:
		return
	var cw: int = clampi(int(float(ALBUM_W - 2 * ALBUM_PAD - (n - 1) * CHIP_SEP) / float(n)), 52, 84)
	var grp := ButtonGroup.new()
	for i in n:
		var p: Dictionary = _album_data[i]
		var locked: bool = bool(p.get("locked", false))
		var b := Button.new()
		b.theme_type_variation = "Pill"
		b.toggle_mode = true
		b.button_group = grp
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = locked
		b.custom_minimum_size = Vector2(cw, 76)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var icon_name: String = "lock" if locked else str(p.get("icon", ""))
		b.set_meta("icon", icon_name if icon_name != "" else "book")
		b.toggled.connect(func(on: bool) -> void: _paint_chip(b, on))
		b.pressed.connect(func() -> void: _album_select(i))
		album_chips.add_child(b)
		b.set_pressed_no_signal(i == _album_sel)
		_paint_chip(b, i == _album_sel)

func _paint_chip(b: Button, on: bool) -> void:
	b.icon = UiTheme.icon(str(b.get_meta("icon")), 38, Color.WHITE if on else UiTheme.INK)

func _album_select(i: int) -> void:
	_album_sel = i
	for c in album_grid.get_children():
		album_grid.remove_child(c)
		c.queue_free()
	if i < 0 or i >= _album_data.size():
		album_name.text = ""
		album_count.text = ""
		return
	var p: Dictionary = _album_data[i]
	var pairs: Array = p["pairs"]
	var dom: int = 0
	for pr in pairs:
		if int((pr as Dictionary)["stage"]) == 2:
			dom += 1
	album_name.text = str(p["name"])
	album_count.text = "Dominadas %d de %d" % [dom, pairs.size()]
	album_grid.visible = not pairs.is_empty()
	if pairs.is_empty():
		return
	var cols: int = _dom_columns(pairs.size())
	var side: int = _dom_side(cols)
	album_grid.columns = cols
	for pr in pairs:
		var stage: int = int((pr as Dictionary)["stage"])
		var tile: Control = _dom_tile({"tex": pr["a"], "stage": stage, "dim": stage < 2}, side)
		if stage == 2:
			tile.add_child(_album_tap(pr))
		album_grid.add_child(tile)

## Botón transparente sobre toda la miniatura (como el de `_back_tile`).
func _album_tap(pr: Dictionary) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	btn.pressed.connect(func() -> void: _album_open(pr))
	return btn

func _album_open(pr: Dictionary) -> void:
	_detail_a.texture = pr["a"]
	_detail_b.texture = pr["b"]
	var fact: String = str(pr.get("fact", ""))
	_detail_fact.text = fact if fact != "" else "Esta pareja aún no tiene dato curioso."
	_album_detail.visible = true
	if _detail_card != null:
		_pop(_detail_card)

func show_win(title: String, msg: String, button: String, doms: Array = []) -> void:
	win_title.text = title
	win_msg.text = msg
	win_btn.text = button
	_fill_doms(doms)
	win.visible = true
	if _win_card != null:
		_pop(_win_card)

## Miniaturas de las parejas del nivel con su estado de dominio.
## doms: Array de {tex, stage, up}; `up` = mejoró en esta partida (lleva contorno).
## El tamaño se adapta a cuántas parejas hay: pocas → miniaturas grandes.
func _fill_doms(doms: Array) -> void:
	for c in dom_grid.get_children():
		dom_grid.remove_child(c)
		c.queue_free()
	var n: int = doms.size()
	dom_grid.visible = n > 0
	if n == 0:
		return
	var cols: int = _dom_columns(n)
	var side: int = _dom_side(cols)
	dom_grid.columns = cols
	for d in doms:
		dom_grid.add_child(_dom_tile(d, side))
	var grid_w: int = cols * (side + 10) + (cols - 1) * DOM_SEP
	if _win_card != null:
		_win_card.custom_minimum_size.x = clampi(grid_w + 2 * WIN_PAD, WIN_MIN_W, WIN_MAX_W)

## Columnas y filas equilibradas (máximo 5 filas); menos huecos y miniaturas grandes.
func _dom_columns(n: int) -> int:
	var best: int = 3
	var best_score: float = 1e9
	for cols in range(3, 7):
		var rows: int = ceili(float(n) / float(cols))
		if rows > 5:
			continue
		var empty: int = rows * cols - n
		var side: int = _dom_side(cols)
		var score: float = float(empty * 20 + rows * 2) - float(side)
		if score < best_score:
			best_score = score
			best = cols
	return best

## Lado de la imagen de cada miniatura: cabe en el ancho de la tarjeta y tiene tope.
func _dom_side(cols: int) -> int:
	var content: int = WIN_MAX_W - 2 * WIN_PAD
	var by_w: int = int((content - (cols - 1) * DOM_SEP) / cols) - 10
	return clampi(mini(DOM_MAX, by_w), 56, DOM_MAX)

func _dom_tile(d: Dictionary, side: int = 72) -> Control:
	var stage: int = int(d.get("stage", 0))
	var up: bool = bool(d.get("up", false))
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(side + 10, side + 46)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.CREAM
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(5)
	if up:
		sb.set_border_width_all(4)
		sb.border_color = Color("42cd84")
	elif stage > 0:
		sb.set_border_width_all(2)
		sb.border_color = Color(0.26, 0.70, 0.44, 0.45)
	pc.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	var img := TextureRect.new()
	img.texture = d.get("tex", null)
	if bool(d.get("dim", false)):  # álbum: pareja aún sin dominar
		img.modulate = Color(0.60, 0.62, 0.70, 0.45)
	img.custom_minimum_size = Vector2(side, side)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(img)
	# Estado de dominio debajo de la miniatura: brote, dos hojas o árbol
	var row := CenterContainer.new()
	row.custom_minimum_size = Vector2(0, 34)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var icon: int = clampi(int(round(float(side) * 0.25)), 26, 34)
	var pi := TextureRect.new()
	pi.texture = UiTheme.icon_plant(stage, icon, UiTheme.PLANT)
	pi.custom_minimum_size = Vector2(icon, icon)
	pi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pi)
	return pc

func toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.4)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.4)

func _update_columns() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	UiTheme.bg_resize(vp)
	for m in _bgs:
		(m as ShaderMaterial).set_shader_parameter("res", vp)
	_layout_menu_deco()
