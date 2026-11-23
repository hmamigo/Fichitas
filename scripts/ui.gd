class_name GameUI
extends CanvasLayer
## Pantallas 2D: menú, materias, barra de juego y dato curioso. Solo dibuja y emite señales.
## El nivel completado es una estación 3D (`StationWin`).

signal back_pressed
signal sound_toggled(on: bool)
signal vib_toggled(on: bool)
signal sfx(name: String)

var hud_bar: Control
var hud_back_button: Button   # el botón, no la franja entera: solo él bloquea toques del tablero
var menu: Control
var sound_btn: Button
var vib_btn: Button
var subjects: Control
var mode_screen: Control
var toast_label: Label
var toast_panel: Control
var album: Control
var fact: Control
var _th: Theme
var _fact_card: Control
var _fact_a: TextureRect
var _fact_b: TextureRect
var _fact_text: Label
var _bgs: Array = []   # materiales de los fondos, para reajustar el lienzo
var _safe_margins: Array = []   # [MarginContainer, margen base], para el área segura
var _toast_tween: Tween
# Piezas animadas del menú: halos, fichas decorativas y destellos.
var _menu_logo: TextureRect
var _menu_logo_wrap: Control
var _menu_logo_glow: TextureRect
var _menu_title_wrap: Control
var _menu_title_glow: TextureRect
var _menu_subtitle: Control
var _menu_opts: Control
var _menu_deco: Array = []
var _menu_title_tiles: Array = []
var _menu_tween: Tween
var _menu_clock: float = 0.0
var _logo_base: Vector2 = Vector2.ZERO

func _ready() -> void:
	_th = UiTheme.build()
	_build_hud()
	_build_menu()
	_build_subjects()
	_build_mode()
	_build_album()
	_build_fact()
	_build_toast()
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

## Márgenes del área segura (notch, barra de estado y barra de gestos) en píxeles del
## lienzo. `get_screen_transform()` pasa de lienzo a ventana; su inversa trae el rectángulo
## seguro al espacio donde viven los controles, sea cual sea el estiramiento de la pantalla.
func _safe_insets() -> Rect2:
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Rect2()
	var vp: Viewport = get_viewport()
	var inv: Transform2D = vp.get_screen_transform().affine_inverse()
	var origin: Vector2 = vp.get_visible_rect().position
	var visible: Vector2 = vp.get_visible_rect().size
	var tl: Vector2 = inv * Vector2(safe.position) - origin
	var br: Vector2 = inv * Vector2(safe.end) - origin
	return Rect2(maxf(0.0, tl.x), maxf(0.0, tl.y),
		maxf(0.0, visible.x - br.x), maxf(0.0, visible.y - br.y))

func _register_margin(m: MarginContainer, base: int) -> void:
	_safe_margins.append([m, base])
	_apply_safe_area()

func _apply_safe_area() -> void:
	if _safe_margins.is_empty():
		return
	var s: Rect2 = _safe_insets()
	for item in _safe_margins:
		var m: MarginContainer = item[0]
		var base: int = item[1]
		m.add_theme_constant_override("margin_left", maxi(base, int(ceil(s.position.x))))
		m.add_theme_constant_override("margin_right", maxi(base, int(ceil(s.size.x))))
		m.add_theme_constant_override("margin_top", maxi(base, int(ceil(s.position.y))))
		m.add_theme_constant_override("margin_bottom", maxi(base, int(ceil(s.size.y))))

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

## Tarjeta con el mismo aspecto que las losetas del mundo: filo dorado grueso con
## borde inferior oscuro (como `Plaque` y las fichas) y cara crema. Devuelve la caja
## vertical de la cara; el aro dorado es `result.get_parent().get_parent()`.
func _gold_panel(parent: Control, width: int, pad: int = 30) -> VBoxContainer:
	var rim := PanelContainer.new()
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color("f0b232")
	rs.set_corner_radius_all(46)
	rs.border_color = Color("a8690f")
	rs.border_width_bottom = 14
	rs.set_content_margin_all(10)
	rs.shadow_color = Color(0.08, 0.16, 0.34, 0.34)
	rs.shadow_size = 22
	rs.shadow_offset = Vector2(0, 12)
	rim.add_theme_stylebox_override("panel", rs)
	rim.custom_minimum_size = Vector2(width, 0)
	rim.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(rim)
	var face := PanelContainer.new()
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color("fffdf7")
	fs.set_corner_radius_all(36)
	fs.border_color = Color("fff3c4")
	fs.set_border_width_all(3)
	fs.set_content_margin_all(pad)
	face.add_theme_stylebox_override("panel", fs)
	rim.add_child(face)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	face.add_child(v)
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
	b.set_meta("label_on", text + ": sí")
	b.set_meta("label_off", text + ": no")
	b.toggled.connect(func(on: bool) -> void: _paint_toggle(b, on))
	parent.add_child(b)
	return b

func _paint_toggle(b: Button, on: bool) -> void:
	var icon_name: String = str(b.get_meta("icon_on" if on else "icon_off"))
	b.text = str(b.get_meta("label_on" if on else "label_off"))
	var tex: ImageTexture = UiTheme.icon(icon_name, 34, UiTheme.INK)
	# Activa, la pastilla es azul: el icono a color va sobre un círculo claro para que se vea
	b.icon = _chip(tex, 46) if on and tex != null else tex

## Icono centrado sobre un círculo blanco de diámetro `size`.
func _chip(tex: ImageTexture, size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: float = float(size) * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(Vector2(c, c))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(c - d, 0.0, 1.0) * 0.95))
	var icon_img: Image = tex.get_image()
	var off: int = (size - icon_img.get_width()) / 2
	img.blend_rect(icon_img, Rect2i(0, 0, icon_img.get_width(), icon_img.get_height()), Vector2i(off, off))
	return ImageTexture.create_from_image(img)

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
func _back_tile(text: String, out_button: Array) -> Control:
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
	back.focus_mode = Control.FOCUS_ALL  # estilo vacío: navegable sin recuadro visible
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		back.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	back.pressed.connect(func() -> void:
		sfx.emit("tap")
		back_pressed.emit())
	back.mouse_entered.connect(func() -> void: _juice_scale(back_tile, 1.03, 0.12))
	back.mouse_exited.connect(func() -> void: _juice_scale(back_tile, 1.0, 0.16))
	back.button_down.connect(func() -> void: _juice_scale(back_tile, 0.95, 0.08))
	back.button_up.connect(func() -> void: _juice_scale(back_tile, 1.0, 0.14))
	back_tile.add_child(back)  # sobre toda la ficha, no solo sobre el texto
	out_button.append(back)
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
	var parts: Array = [_menu_logo_wrap, _menu_title_wrap, _menu_subtitle]
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
	for i in _menu_deco.size():
		var w: Control = _menu_deco[i]["wrap"]
		_menu_tween.tween_property(w, "modulate:a", 1.0, 0.35).set_delay(0.06 + float(i) * 0.035)

## Movimiento ambiente del menú (solo mientras está visible).
func _process(delta: float) -> void:
	_menu_clock += delta
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
	mode_screen.visible = false
	album.visible = false
	fact.visible = false
	_hide_toast()

# ---------- Construcción ----------

func _build_hud() -> void:
	var m := MarginContainer.new()
	m.theme = _th
	m.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_register_margin(m, 14)
	add_child(m)
	hud_bar = m
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	m.add_child(h)
	var back_button: Array = []
	h.add_child(_back_tile("Atrás", back_button))
	hud_back_button = back_button[0] as Button

func _build_menu() -> void:
	menu = _screen("none")  # sin fondo: detrás se ve el suelo de cubos 3D
	# Velo suave: enfría el centro de la escena y da aire a los textos sin tapar los cubos.
	var veil := TextureRect.new()
	veil.texture = UiTheme.radial_glow(256, Color("e8f3ff"))
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.modulate = Color(1, 1, 1, 0.46)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(veil)

	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_register_margin(m, 30)
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
	# Lema bajo el logotipo: solo informa, así que va plano (con halo para leerse
	# sobre los cubos), sin plato ni filo que lo haga parecer un botón.
	_menu_subtitle = _halo(_label("Empareja fichas y practica a tu ritmo.", UiTheme.T_BODY, false, UiTheme.INK))
	_menu_subtitle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_menu_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_menu_subtitle)

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
	_menu_opts = opts_pill
	var opts := HBoxContainer.new()
	opts.alignment = BoxContainer.ALIGNMENT_CENTER
	opts.add_theme_constant_override("separation", 12)
	opts_pill.add_child(opts)
	sound_btn = _toggle("Sonido", "speaker", "speaker_mute", opts)
	sound_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_btn.toggled.connect(func(on: bool) -> void: sound_toggled.emit(on))
	sound_btn.pressed.connect(func() -> void: sfx.emit("tap"))
	_juice(sound_btn)
	vib_btn = _toggle("Vibración", "rumble_phone", "mobile_phone", opts)
	vib_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vib_btn.toggled.connect(func(on: bool) -> void: vib_toggled.emit(on))
	vib_btn.pressed.connect(func() -> void: sfx.emit("tap"))
	_juice(vib_btn)
	# La capa es solo texto: los toques van a las losetas 3D (menos los ajustes)
	_pass_through(menu)

func _build_subjects() -> void:
	subjects = _screen("none")  # sin fondo: las losetas 3D son la lista
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_register_margin(m, 26)
	subjects.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	m.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	v.add_child(head)
	head.add_child(_back_tile("Menú", []))
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap)
	# La capa no debe tragarse los toques: las losetas viven en la escena 3D
	_pass_through(subjects)

## Cabecera del paso "¿Cómo quieres jugar?": las dos losetas son 3D, acá solo van
## el botón de volver, el título y el detalle de la sesión que se va a empezar.
func _build_mode() -> void:
	mode_screen = _screen("none")  # sin fondo: las losetas de modo son 3D
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_register_margin(m, 26)
	mode_screen.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	m.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	v.add_child(head)
	head.add_child(_back_tile("Atrás", []))
	# La capa no debe tragarse los toques: las losetas viven en la escena 3D
	_pass_through(mode_screen)

## Cabecera del álbum: las fichas y las secciones son 3D, aquí solo queda el título.
func _build_album() -> void:
	album = _screen("none")  # sin fondo: el álbum es una mesa de la escena 3D
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_register_margin(m, 26)
	album.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	m.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	v.add_child(head)
	head.add_child(_back_tile("Menú", []))
	# La capa no debe tragarse los toques: las fichas viven en la escena 3D
	_pass_through(album)

## Ventana con las dos fichas de una pareja dominada y su dato curioso.
func _build_fact() -> void:
	fact = Control.new()
	fact.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fact.theme = _th
	fact.visible = false
	add_child(fact)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.11, 0.26, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # los toques no llegan a la escena 3D de detrás
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_fact_dim_input)    # tocar fuera de la tarjeta la cierra
	fact.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fact.add_child(center)
	var card := _gold_panel(center, 780, 34)
	_fact_card = card.get_parent().get_parent() as Control
	_fact_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var pair_row := HBoxContainer.new()
	pair_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pair_row.add_theme_constant_override("separation", 28)
	card.add_child(pair_row)
	_fact_a = _fact_face(pair_row)
	_fact_b = _fact_face(pair_row)
	card.add_child(_label("Dato curioso", UiTheme.T_HEAD - 8, true, UiTheme.BLUE_DARK))
	_fact_text = _label("", UiTheme.T_BODY, false, UiTheme.INK, true)
	_fact_text.custom_minimum_size = Vector2(680, 0)
	card.add_child(_fact_text)
	var close := Button.new()
	close.theme_type_variation = "Gold"
	close.text = "Cerrar"
	close.custom_minimum_size = Vector2(0, 96)
	close.pressed.connect(func() -> void:
		sfx.emit("tap")
		fact.visible = false)
	card.add_child(close)

## Aviso temporal fuera de las pantallas: así se puede mostrar sobre materias o álbum.
## Va abajo, centrado, sobre un plato claro, y no intercepta toques.
func _build_toast() -> void:
	var layer := MarginContainer.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_register_margin(layer, 26)
	add_child(layer)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_END
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(v)
	# Plato plano de papel: el aviso cae sobre cubos y mesas de colores muy distintos,
	# y solo con el halo del texto no siempre se leía.
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := UiTheme.box(Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.0), 0, 16, 16, 22, 0, 10, 0.22)
	plate.add_theme_stylebox_override("panel", sb)
	plate.visible = false
	v.add_child(plate)
	toast_panel = plate
	toast_label = _label("", UiTheme.T_SMALL, false, UiTheme.INK, true)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(toast_label)

func _fact_face(parent: Control) -> TextureRect:
	var rim := _enamel_tile(Vector2(300, 300), Color("fffdf7"), 8)
	var img := TextureRect.new()
	img.custom_minimum_size = Vector2(270, 270)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(rim.get_child(0) as Control).add_child(img)
	parent.add_child(rim)
	return img

func _on_fact_dim_input(e: InputEvent) -> void:
	var pressed: bool = false
	if e is InputEventMouseButton:
		pressed = (e as InputEventMouseButton).pressed
	elif e is InputEventScreenTouch:
		pressed = (e as InputEventScreenTouch).pressed
	if pressed:
		sfx.emit("tap")
		fact.visible = false

# ---------- API ----------

## Centro vertical del hueco libre del menú (fracción desde arriba): va del borde
## inferior del subtítulo al superior de la pastilla de ajustes. `Board.center_menu()`
## encuadra la mesa 3D ahí, así queda centrada en cualquier proporción de pantalla.
func menu_band_center() -> float:
	if menu == null or _menu_subtitle == null or _menu_opts == null or menu.size.y < 1.0:
		return 0.5
	var origin: float = menu.get_global_rect().position.y
	var top: float = _menu_subtitle.get_global_rect().end.y - origin
	var bottom: float = _menu_opts.get_global_rect().position.y - origin
	if bottom <= top:
		return 0.5
	return clampf((top + bottom) * 0.5 / menu.size.y, 0.05, 0.95)

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

## Barra superior de la partida: solo el botón de volver; el título va en la mesa del tablero.
func show_hud() -> void:
	hide_all()
	hud_bar.visible = true

## Las tarjetas de materia son losetas 3D: aquí solo queda la cabecera y el aviso.
func show_subjects() -> void:
	hide_all()
	_update_columns()
	subjects.visible = true

## Paso previo a la partida: solo el botón de volver; el título va en la mesa de modo.
func show_mode() -> void:
	hide_all()
	mode_screen.visible = true

func show_album() -> void:
	hide_all()
	album.visible = true

## La ayuda es una mesa de la escena 3D: la capa 2D solo lleva el botón de volver.
func show_help() -> void:
	hide_all()
	hud_bar.visible = true

## Dato curioso de una pareja dominada, con sus dos fichas.
func show_fact(a: Texture2D, b: Texture2D, text: String) -> void:
	_fact_a.texture = a
	_fact_b.texture = b
	_fact_text.text = text if text != "" else "Esta pareja aún no tiene dato curioso."
	_hide_toast()
	fact.visible = true
	if _fact_card != null:
		_pop(_fact_card)

## Cierra la ventana del dato curioso si está abierta; devuelve si había algo que cerrar.
func close_fact() -> bool:
	if fact != null and fact.visible:
		fact.visible = false
		return true
	return false

func toast(text: String) -> void:
	toast_label.text = text
	# El plato se ajusta al texto: con `autowrap` siempre activo, el ancho mínimo es
	# el de la palabra más larga y el aviso quedaba en una columna de una letra.
	var avail: float = get_viewport().get_visible_rect().size.x - 84.0
	var need: float = UiTheme.body_font().get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.T_SMALL).x
	var fits: bool = need <= avail
	toast_label.autowrap_mode = TextServer.AUTOWRAP_OFF if fits else TextServer.AUTOWRAP_WORD_SMART
	toast_label.custom_minimum_size.x = 0.0 if fits else avail
	toast_panel.modulate.a = 1.0
	toast_panel.visible = true
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.4)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_hide_toast)

func _hide_toast() -> void:
	if toast_panel != null:
		toast_panel.visible = false

func _update_columns() -> void:
	_apply_safe_area()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	UiTheme.bg_resize(vp)
	for m in _bgs:
		(m as ShaderMaterial).set_shader_parameter("res", vp)
	_layout_menu_deco()
