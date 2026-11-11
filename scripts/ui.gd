class_name GameUI
extends CanvasLayer
## Pantallas: menú, materias, barra de juego y nivel completado. Solo dibuja y emite señales.

signal play_general
signal play_subject(id: String)
signal open_subjects
signal back_pressed
signal next_pressed
signal mode_changed(mode: String)

var hud_bar: Control
var lv_label: Label
var menu: Control
var play_btn: Button
var mode_btns: Dictionary = {}
var subjects: Control
var grid: GridContainer
var toast_label: Label
var win: Control
var win_title: Label
var win_msg: Label
var win_btn: Button
var _th: Theme
var _menu_card: Control
var _win_card: Control

func _ready() -> void:
	_th = UiTheme.build()
	_build_hud()
	_build_menu()
	_build_subjects()
	_build_win()
	get_viewport().size_changed.connect(_update_columns)
	hide_all()

# ---------- Utilidades ----------

func _label(text: String, size: int, title: bool = false, color: Color = UiTheme.INK, autowrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if title:
		l.add_theme_font_override("font", UiTheme.title_font())
		l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.92))
		l.add_theme_constant_override("outline_size", maxi(5, int(size / 7.0)))
	if autowrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## Fondo de pantalla: degradado vertical y, opcionalmente, un patrón de fichas.
func _backdrop(parent: Control, stops: Array, pattern: float = 0.0) -> void:
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for s in stops:
		offs.append(float(s[0]))
		cols.append(s[1])
	var g := Gradient.new()
	g.offsets = offs
	g.colors = cols
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0.0, 0.0)
	gt.fill_to = Vector2(0.0, 1.0)
	var bg := TextureRect.new()
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	if pattern <= 0.0:
		return
	var pt := TextureRect.new()
	pt.texture = UiTheme.pattern_tile(110, Color(1, 1, 1, pattern))
	pt.stretch_mode = TextureRect.STRETCH_TILE
	pt.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	pt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(pt)

## Pantalla completa con su propio fondo.
func _screen(stops: Array, pattern: float = 0.0) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.theme = _th
	add_child(c)
	_backdrop(c, stops, pattern)
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
	back.icon = UiTheme.icon_chevron(30, UiTheme.INK)
	back.add_theme_constant_override("h_separation", 4)
	back.custom_minimum_size = Vector2(0, 68)
	back.pressed.connect(func() -> void: back_pressed.emit())
	h.add_child(back)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.92), Color(1, 1, 1, 0.0), 0, 10, 10, 26, 0, 8, 0.16))
	lv_label = _label("", 27, true, UiTheme.BLUE_DARK)
	pc.add_child(lv_label)
	h.add_child(pc)

func _build_menu() -> void:
	menu = _screen([[0.0, Color(0.84, 0.91, 1.0, 0.94)], [0.45, Color(0.93, 0.97, 1.0, 0.30)], [1.0, Color(0.68, 0.81, 0.97, 0.88)]], 0.26)
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
	v.add_child(_label("Fichas del saber", 96, true, UiTheme.BLUE_DARK))
	v.add_child(_label("Empareja fichas y practica a tu ritmo.", 27, false, UiTheme.INK_SOFT, true))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 34)
	v.add_child(gap)
	# Tres fichas de muestra, como decoración
	v.add_child(_chips())
	var gap_mid := Control.new()
	gap_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap_mid)
	var card := _panel(v, 700, 40)
	_menu_card = card.get_parent() as Control
	card.add_theme_constant_override("separation", 22)
	card.add_child(_label("Modo de juego", 25, false, UiTheme.INK_SOFT))
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
	var gap2 := Control.new()
	gap2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap2)
	v.add_child(_label("Sin cronómetro y sin puntuación.", 22, false, UiTheme.INK_SOFT))

func _build_subjects() -> void:
	subjects = _screen([[0.0, Color(0.94, 0.97, 1.0, 0.97)], [1.0, Color(0.73, 0.85, 0.98, 0.97)]], 0.30)
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
	back.icon = UiTheme.icon_chevron(30, UiTheme.INK)
	back.add_theme_constant_override("h_separation", 4)
	back.custom_minimum_size = Vector2(0, 72)
	back.pressed.connect(func() -> void: back_pressed.emit())
	head.add_child(back)
	var hb := VBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 0)
	head.add_child(hb)
	var t := _label("Elige una materia", 52, true, UiTheme.BLUE_DARK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hb.add_child(t)
	var st := _label("Cada materia tiene sus propios niveles.", 23, false, UiTheme.INK_SOFT)
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
	toast_label = _label("", 24, false, UiTheme.INK, true)
	v.add_child(toast_label)

func _build_win() -> void:
	win = Control.new()
	win.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win.theme = _th
	add_child(win)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.11, 0.26, 0.42)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win.add_child(dim)
	_backdrop(win, [[0.0, Color(0.45, 0.62, 0.92, 0.0)], [1.0, Color(0.30, 0.48, 0.84, 0.30)]], 0.18)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win.add_child(center)
	var card := _panel(center, 640, 34)
	_win_card = card.get_parent() as Control
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	for sp in [[32, Color("ffd45e")], [48, Color("ffc93c")], [32, Color("ffd45e")]]:
		var spr := TextureRect.new()
		spr.texture = UiTheme.sparkle(int(sp[0]), sp[1])
		spr.custom_minimum_size = Vector2(float(sp[0]) * 1.25, float(sp[0]) * 1.25)
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(spr)
	card.add_child(row)
	win_title = _label("", 58, true, UiTheme.BLUE_DARK)
	card.add_child(win_title)
	win_msg = _label("", 26, false, UiTheme.INK, true)
	card.add_child(win_msg)
	win_btn = Button.new()
	win_btn.custom_minimum_size = Vector2(0, 84)
	win_btn.pressed.connect(func() -> void: next_pressed.emit())
	card.add_child(win_btn)

# ---------- API ----------

func show_menu(level: int, mode: String) -> void:
	hide_all()
	(mode_btns[mode] as Button).button_pressed = true
	play_btn.text = "Recorrido general · Nivel %d" % level
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

func show_win(title: String, msg: String, button: String) -> void:
	win_title.text = title
	win_msg.text = msg
	win_btn.text = button
	win.visible = true
	if _win_card != null:
		_pop(_win_card)

func toast(text: String) -> void:
	toast_label.text = text

func _update_columns() -> void:
	if grid == null:
		return
	var w: float = get_viewport().get_visible_rect().size.x - 48.0
	grid.columns = maxi(2, floori(w / 330.0))

func _card(d: Dictionary) -> Button:
	var locked: bool = d.get("locked", false)
	var col: Color = d["color"]
	if locked:
		col = col.lerp(Color("c4cbd9"), 0.55)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 262)
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
	bs.bg_color = Color(1, 1, 1, 0.45)
	bs.set_corner_radius_all(56)
	bs.set_content_margin_all(4)
	badge.add_theme_stylebox_override("panel", bs)
	badge.custom_minimum_size = Vector2(112, 112)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(_label(str(d["name"]).substr(0, 1).to_upper(), 58, true, ink))
	v.add_child(badge)
	var parts: Array = [
		_label(str(d["name"]), 32, false, ink),
		_label(str(d.get("sub", "")), 23, false, ink),
		_label(str(d.get("sub2", "")), 21, false, ink),
	]
	for l in parts:
		(l as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	if locked:
		var lk := TextureRect.new()
		lk.texture = UiTheme.icon_lock(44, Color(0.15, 0.22, 0.36, 0.55))
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
		else:
			play_subject.emit(id))
	return b
