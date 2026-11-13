class_name GameUI
extends CanvasLayer
## Pantallas: menú, materias, barra de juego y nivel completado. Solo dibuja y emite señales.

signal play_general
signal play_subject(id: String)
signal play_review
signal open_subjects
signal back_pressed
signal next_pressed
signal mode_changed(mode: String)
signal sound_toggled(on: bool)
signal vib_toggled(on: bool)

var hud_bar: Control
var lv_label: Label
var menu: Control
var play_btn: Button
var mode_btns: Dictionary = {}
var sound_btn: Button
var vib_btn: Button
var subjects: Control
var grid: GridContainer
var toast_label: Label
var win: Control
var win_title: Label
var win_msg: Label
var win_btn: Button
var dom_grid: GridContainer
var _th: Theme
var _menu_card: Control
var _win_card: Control
var _bgs: Array = []   # materiales de los fondos, para reajustar el lienzo

func _ready() -> void:
	_th = UiTheme.build()
	_build_hud()
	_build_menu()
	_build_subjects()
	_build_win()
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

## Tarjeta clara con sombra; devuelve la caja vertical donde poner el contenido.
func _panel(parent: Control, width: int, pad: int = 30) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.panel_box(pad))
	pc.custom_minimum_size = Vector2(width, 0)
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	pc.add_child(v)
	return v

## Fila de tres fichas de colores; solo decora el menú.
func _chips() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	for d in [[Color("ffc629"), -8.0], [Color("42cd84"), 4.0], [Color("4a8ff5"), 12.0]]:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(92, 92)
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		p.add_theme_stylebox_override("panel", UiTheme.box(d[0], (d[0] as Color).darkened(0.38), 10, 0, 0, 24, 0, 14, 0.30))
		p.pivot_offset = Vector2(46, 46)
		p.rotation_degrees = d[1]
		row.add_child(p)
	return row

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
	var name: String = str(b.get_meta("icon_on" if on else "icon_off"))
	b.icon = UiTheme.icon(name, 34, Color.WHITE if on else UiTheme.INK)

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
	var back := Button.new()
	back.text = "Atrás"
	back.theme_type_variation = "Alt"
	back.icon = UiTheme.icon_chevron(34, UiTheme.INK)
	back.add_theme_constant_override("h_separation", 12)
	back.custom_minimum_size = Vector2(0, 74)
	back.pressed.connect(func() -> void: back_pressed.emit())
	h.add_child(back)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.HUD_BG, Color(1, 1, 1, 0.0), 0, 10, 10, 26, 0, 8, 0.16))
	lv_label = _label("", UiTheme.T_BODY, true, UiTheme.BLUE_DARK)
	pc.add_child(lv_label)
	h.add_child(pc)

func _build_menu() -> void:
	menu = _screen("none")  # sin fondo: detrás se ve el suelo de cubos 3D
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 30)
	menu.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	var logo := TextureRect.new()
	logo.texture = UiTheme.logo(190)
	logo.custom_minimum_size = Vector2(190, 190)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(logo)
	# Espacio push-down para que nombre y descripción no queden tan pegados arriba
	v.add_child(Control.new())
	v.add_child(Control.new())
	v.add_child(Control.new())
	v.add_child(_label("Fichitas", UiTheme.T_HERO + 12, true, UiTheme.BLUE_DARK))
	v.add_child(_halo(_label("Empareja fichas y practica a tu ritmo.", UiTheme.T_BODY + 4, false, UiTheme.INK, true)))
	var gap_mid := Control.new()
	gap_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap_mid.size_flags_stretch_ratio = 3.0  # más push-down para separar del menú
	v.add_child(gap_mid)
	var card := _panel(v, 700, 40)
	_menu_card = card.get_parent() as Control
	card.add_theme_constant_override("separation", 22)
	card.add_child(_label("Modo de juego", UiTheme.T_SMALL, false, UiTheme.INK_SOFT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var grp := ButtonGroup.new()
	for m2 in [["mem", "Memoria"], ["assoc", "Asociación"]]:
		var b := Button.new()
		b.text = m2[1]
		b.toggle_mode = true
		b.button_group = grp
		b.theme_type_variation = "Pill"
		b.custom_minimum_size = Vector2(0, 84)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = m2[0]
		b.pressed.connect(func() -> void: mode_changed.emit(key))
		row.add_child(b)
		mode_btns[key] = b
	card.add_child(row)
	var subj := Button.new()
	subj.text = "Elegir materia"
	subj.custom_minimum_size = Vector2(0, 100)
	subj.pressed.connect(func() -> void: open_subjects.emit())
	card.add_child(subj)
	play_btn = Button.new()
	play_btn.theme_type_variation = "Alt"
	play_btn.custom_minimum_size = Vector2(0, 100)
	play_btn.pressed.connect(func() -> void: play_general.emit())
	card.add_child(play_btn)
	var opts := HBoxContainer.new()
	opts.alignment = BoxContainer.ALIGNMENT_CENTER
	opts.add_theme_constant_override("separation", 12)
	card.add_child(opts)
	sound_btn = _toggle("Sonido", "speaker", "speaker_mute", opts)
	sound_btn.toggled.connect(func(on: bool) -> void: sound_toggled.emit(on))
	vib_btn = _toggle("Vibración", "rumble_phone", "mobile_phone", opts)
	vib_btn.toggled.connect(func(on: bool) -> void: vib_toggled.emit(on))
	var gap2 := Control.new()
	gap2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap2)
	v.add_child(_halo(_label("Sin cronómetro y sin puntuación.", UiTheme.T_TINY, false, UiTheme.INK)))

func _build_subjects() -> void:
	subjects = _screen("none")  # sin fondo: se ve el suelo de cubos 3D
	# Velo claro y translúcido: calma los cubos detrás de la lista sin taparlos del todo
	var veil := ColorRect.new()
	veil.color = Color(0.88, 0.93, 1.0, 0.58)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	subjects.add_child(veil)
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
	var back := Button.new()
	back.text = "Menú"
	back.theme_type_variation = "Alt"
	back.icon = UiTheme.icon_chevron(34, UiTheme.INK)
	back.add_theme_constant_override("h_separation", 12)
	back.custom_minimum_size = Vector2(0, 78)
	back.pressed.connect(func() -> void: back_pressed.emit())
	head.add_child(back)
	var hb := VBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 0)
	head.add_child(hb)
	var t := _label("Elige una materia", UiTheme.T_HEAD, true, UiTheme.BLUE_DARK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hb.add_child(t)
	var st := _halo(_label("Cada materia tiene sus propios niveles.", UiTheme.T_SMALL, false, UiTheme.INK))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hb.add_child(st)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	sc.add_child(grid)
	toast_label = _halo(_label("", UiTheme.T_SMALL, false, UiTheme.INK, true))
	v.add_child(toast_label)

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
	dim.color = UiTheme.DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win.add_child(dim)
	_backdrop(win, "scrim")
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win.add_child(center)
	var card := _panel(center, WIN_MAX_W, WIN_PAD)
	_win_card = card.get_parent() as Control
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var spr := TextureRect.new()
	spr.texture = UiTheme.icon("stars", 96, Color("ffd45e"))
	spr.custom_minimum_size = Vector2(96, 96)
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(spr)
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
	win_btn.custom_minimum_size = Vector2(0, 84)
	win_btn.pressed.connect(func() -> void: next_pressed.emit())
	card.add_child(win_btn)

# ---------- API ----------

## opts: {sound, vib, vib_visible}
func show_menu(level: int, mode: String, opts: Dictionary = {}) -> void:
	hide_all()
	(mode_btns[mode] as Button).button_pressed = true
	play_btn.text = "Recorrido general · Nivel %d" % level
	var snd: bool = bool(opts.get("sound", true))
	var vb: bool = bool(opts.get("vib", true))
	sound_btn.set_pressed_no_signal(snd)
	_paint_toggle(sound_btn, snd)
	vib_btn.visible = bool(opts.get("vib_visible", false))
	vib_btn.set_pressed_no_signal(vb)
	_paint_toggle(vib_btn, vb)
	menu.visible = true
	if _menu_card != null:
		_pop(_menu_card)

func show_hud(text: String) -> void:
	hide_all()
	lv_label.text = text
	hud_bar.visible = true

## cards: Array de {id, name, sub, sub2, color, locked, info}. id "" = recorrido general.
func show_subjects(cards: Array) -> void:
	hide_all()
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	for d in cards:
		grid.add_child(_card(d))
	toast_label.text = ""
	_update_columns()
	subjects.visible = true

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

func _update_columns() -> void:
	if grid == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	UiTheme.bg_resize(vp)
	for m in _bgs:
		(m as ShaderMaterial).set_shader_parameter("res", vp)
	grid.columns = maxi(2, floori((vp.x - 48.0) / 330.0))

func _card(d: Dictionary) -> Button:
	var locked: bool = d.get("locked", false)
	var col: Color = d["color"]
	if locked:
		col = col.lerp(UiTheme.LOCKED, 0.55)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 326)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var edge: Color = col.darkened(0.30)
	b.add_theme_stylebox_override("normal", UiTheme.box(col, edge, 8, 14, 14, 32, 0, 14, 0.22))
	b.add_theme_stylebox_override("hover", UiTheme.box(col.lightened(0.07), edge, 8, 14, 14, 32, 0, 14, 0.22))
	b.add_theme_stylebox_override("pressed", UiTheme.box(col.darkened(0.07), edge, 3, 19, 14, 32, 0, 14, 0.22))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ink: Color = UiTheme.INK if not locked else UiTheme.INK.lerp(Color.WHITE, 0.35)
	# Medallón con la inicial de la materia
	var badge := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = UiTheme.BADGE_BG
	bs.set_corner_radius_all(56)
	bs.set_content_margin_all(4)
	badge.add_theme_stylebox_override("panel", bs)
	badge.custom_minimum_size = Vector2(112, 112)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_name: String = str(d.get("icon", ""))
	if icon_name != "":
		var im := TextureRect.new()
		im.texture = UiTheme.icon(icon_name, 66, ink)
		im.custom_minimum_size = Vector2(66, 66)
		im.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		im.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		im.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(im)
	else:
		badge.add_child(_label(str(d["name"]).substr(0, 1).to_upper(), UiTheme.T_WIN, true, ink))
	v.add_child(badge)
	var parts: Array = [
		_label(str(d["name"]), UiTheme.T_NAME, false, ink),
		_label(str(d.get("sub", "")), UiTheme.T_SMALL, false, ink),
		_label(str(d.get("sub2", "")), UiTheme.T_TINY, false, ink),
	]
	var sub3: String = str(d.get("sub3", ""))
	if sub3 != "":
		parts.append(_label(sub3, UiTheme.T_TINY, false, UiTheme.BLUE_DARK))
	for l in parts:
		(l as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	if locked:
		var lk := TextureRect.new()
		lk.texture = UiTheme.icon_lock(44, UiTheme.INK_SOFT)
		lk.custom_minimum_size = Vector2(44, 44)
		lk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lk.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
		b.add_child(lk)
	var id: String = str(d["id"])
	var info: String = str(d.get("info", ""))
	b.pressed.connect(func() -> void:
		if locked:
			toast(info)
		elif id == "":
			play_general.emit()
		elif id == ":review":
			play_review.emit()
		else:
			play_subject.emit(id))
	return b
