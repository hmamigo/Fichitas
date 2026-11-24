extends Node
## Orquestador: menús, niveles y guardado. El tablero y la interfaz solo emiten señales.

enum S { MENU, SUBJECTS, MODE, GAME, WIN, ALBUM, HELP }
const COMING := ["Historia", "Más materias"]

var board: Board
var ui: GameUI
var audio: GameAudio
var packs: Array = []
var groups: Array = []              # materias que agrupan temas (Packs.load_groups)
var _group_open: String = ""        # materia abierta en la lista ("" = la lista general)
var _top_view: Dictionary = {}      # desplazamiento de la lista general mientras se mira una materia
var state: int = S.MENU
var cur_sid: String = ""
var cur_level: int = 1
var cur_last: bool = false
var cur_review: bool = false
var cur_pairs: Array = []
var stage_before: Dictionary = {}
var _pack_dialog: FileDialog
# Sesión preparada para el paso "¿Cómo quieres jugar?".
var _pending_pairs: Array = []
var _pending_label: String = ""
var _mode_from: int = S.SUBJECTS   # estación a la que vuelve "Atrás" desde el modo

func _ready() -> void:
	Progress.load_data()
	groups = Packs.load_groups()
	packs = Packs.load_all()
	audio = GameAudio.new()
	add_child(audio)
	audio.enabled = bool(Progress.data["sound"])
	board = Board.new()
	add_child(board)
	ui = GameUI.new()
	add_child(ui)
	board.blockers = [ui.hud_back_button]
	board.won.connect(_on_won)
	board.sfx.connect(_on_sfx)
	board.pair_done.connect(func(id: String, clean: bool) -> void:
		Progress.record(id, clean)
		board.set_progress(board.matched_pairs()))
	board.menu_station.play_general.connect(func() -> void: _play("", S.MENU))
	board.menu_station.open_subjects.connect(_go_subjects)
	board.menu_station.open_help.connect(_go_help)
	board.menu_station.open_album.connect(_go_album)
	board.subject_station.chosen.connect(_on_subject)
	board.subject_station.info.connect(ui.toast)
	board.mode_station.chosen.connect(_on_mode_chosen)
	board.album_station.opened.connect(_on_album_open)
	board.album_station.hint.connect(ui.toast)
	ui.back_pressed.connect(_on_back)
	ui.sfx.connect(_on_sfx)
	board.win_station.next.connect(_on_next)
	ui.sound_toggled.connect(_on_sound)
	ui.vib_toggled.connect(_on_vib)
	get_viewport().size_changed.connect(_on_view_resized)
	_go_menu()

func _remember_mode(m: String) -> void:
	Progress.data["mode"] = m
	Progress.save()
	board.mode = m
	_on_sfx("flip")

func _on_subject(id: String) -> void:
	if id == ":review":
		_play_review()
	elif id == ":import":
		_pick_pack()
	elif id == "":
		_play("")
	elif id.begins_with("grp:"):
		_open_group(id.substr(4))
	else:
		_play(id)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:  # botón Atrás de Android
		if state == S.MENU:
			get_tree().quit()
		else:
			_on_back()

func _pack(id: String) -> Dictionary:
	for p in packs:
		if p["id"] == id:
			return p
	return {}

func _go_menu() -> void:
	state = S.MENU
	board.build_menu(Progress.level())
	ui.show_menu({
		"sound": bool(Progress.data["sound"]),
		"vib": bool(Progress.data["vib"]),
		"vib_visible": OS.has_feature("mobile"),
	})
	_center_menu()
	board.fly_to_station("menu", 0.9 if board.station != "menu" else 0.0)
	if _group_open != "":   # al volver a Materias se ve la lista general donde estaba
		_group_open = ""
		board.restore_view("subjects", _top_view)
	_center_menu_later()  # el primer layout del arranque puede llegar un frame tarde

## La mesa 3D del menú se encuadra en el hueco que dejan la cabecera y los ajustes 2D.
func _center_menu() -> void:
	if state == S.MENU:
		board.center_menu(ui.menu_band_center())

## Recalcula un frame después: al cambiar el tamaño, los contenedores aún no tienen
## su rectángulo nuevo cuando llega `size_changed`.
func _center_menu_later() -> void:
	await get_tree().process_frame
	_center_menu()

## Al cambiar la proporción de la ventana, la franja 2D se mueve y la cámara la sigue.
func _on_view_resized() -> void:
	if state == S.MENU:
		_center_menu_later()

## Sonido y vibración: los efectos llegan del tablero y de la interfaz.
func _on_sfx(name: String) -> void:
	audio.play(name)
	if bool(Progress.data["vib"]) and OS.has_feature("mobile"):
		var ms: int = 35 if name == "err" else (60 if name == "win" else (8 if name == "tap" else 12))
		Input.vibrate_handheld(ms)

func _on_sound(on: bool) -> void:
	Progress.data["sound"] = on
	Progress.save()
	audio.enabled = on
	if on:
		audio.play("flip")

func _on_vib(on: bool) -> void:
	Progress.data["vib"] = on
	Progress.save()
	if on and OS.has_feature("mobile"):
		Input.vibrate_handheld(35)

func _go_subjects() -> void:
	state = S.SUBJECTS
	var g: Dictionary = Packs.group_by_id(groups, _group_open)
	if g.is_empty():
		_group_open = ""   # esa materia ya no existe (p. ej. tras recargar los paquetes)
	board.build_subjects(_group_cards(g) if not g.is_empty() else _top_cards())
	board.fly_to_station("subjects", 0.9 if board.station != "subjects" else 0.0)
	ui.show_subjects()
	ui.set_subjects_back("Materias" if not g.is_empty() else "Menú")
	_show_pan_hint()

## Abre una materia con temas: la misma lista pasa a mostrar sus paquetes.
func _open_group(gid: String) -> void:
	if Packs.group_by_id(groups, gid).is_empty():
		return
	_top_view = board.view_snapshot("subjects")
	_group_open = gid
	board.set_subjects_view({})   # la lista de temas empieza por arriba
	_go_subjects()

## Vuelve de una materia a la lista general, en el mismo punto donde se había dejado.
func _close_group() -> void:
	_group_open = ""
	board.set_subjects_view(_top_view)
	_go_subjects()

func _top_cards() -> Array:
	var cards: Array = []
	var due: Array = Levels.due_pairs(packs)
	var due_txt: String = ("%d por repasar" % due.size()) if not due.is_empty() else ""
	# Cada cabecera abre una mesa nueva con su rótulo plano (no se toca) y el color de su marco
	cards.append({"id": "hdr:todos", "header": true, "name": "Para todos", "sub": "Mezcla las materias abiertas",
		"icon": "juego", "color": "9cc8ff", "ink": "1f5fa8", "frame": "2f86d6"})
	cards.append({"id": "", "name": "Recorrido general", "icon": "brujula", "sub": "Nivel %d de %d" % [mini(Progress.level(), Levels.max_level()), Levels.max_level()], "sub2": "", "frac": float(mini(Progress.level(), Levels.max_level()) - 1) / float(Levels.max_level()), "sub3": due_txt, "color": Color("9cc8ff")})
	if due.size() >= 3:  # el repaso necesita al menos tres parejas
		cards.append({"id": ":review", "name": "Repaso", "icon": "cerebro", "sub": "%d parejas esperando" % due.size(),
			"sub2": "De todas las materias", "color": Color("ffce6b")})
	var last_cat: String = ""
	for e in Packs.top_level(packs, groups):   # `packs` viene agrupado por categoría: una cabecera por grupo
		var cat: String = str(((e["group"] if e.has("group") else e["pack"]) as Dictionary).get("category", Packs.DEFAULT_CATEGORY))
		if cat != last_cat:
			last_cat = cat
			cards.append(_category_header(cat))
		cards.append(_group_card(e["group"], e["packs"]) if e.has("group") else _pack_card(e["pack"]))
	cards.append({"id": "hdr:mas", "header": true, "name": "Más", "sub": "Tus paquetes y lo que viene",
		"icon": "magia", "color": "b9c6d9", "ink": "3f526e", "frame": "6b82a3"})
	cards.append({"id": ":import", "name": "Cargar paquete", "icon": "paquete", "sub": "Una materia tuya (.zip)",
		"sub2": "", "color": Color("b8e6c9")})
	for n in COMING:
		var exists: bool = false
		for p in packs:
			if p["name"] == n:
				exists = true
		if not exists:
			cards.append({"id": "coming:" + n, "name": n, "icon": "templo" if n == "Historia" else "magia", "sub": "Próximamente", "sub2": "", "color": Color("c9cfdb"), "locked": true,
				"info": "«%s» llegará pronto." % n})
	return cards

## La lista de una materia con temas: su cabecera y un paquete por cada tema.
func _group_cards(g: Dictionary) -> Array:
	var kids: Array = []
	for p in packs:
		if str(p.get("group", "")) == g["id"]:
			kids.append(p)
	var head: Dictionary = _category_header(str(g["category"]))
	head["id"] = "hdr:grp"
	head["name"] = g["name"]
	head["sub"] = _themes_text(kids.size())
	head["icon"] = g["icon"]
	var cards: Array = [head]
	for p in kids:
		cards.append(_pack_card(p))
	return cards

func _themes_text(n: int) -> String:
	return "1 tema" if n == 1 else "%d temas" % n

func _category_header(cat: String) -> Dictionary:
	for c in Packs.CATEGORIES:
		if c["id"] == cat:
			return {"id": "hdr:" + cat, "header": true, "name": c["name"], "sub": c["sub"],
				"icon": c["icon"], "color": c["color"], "ink": c["ink"], "frame": c["frame"]}
	return {}

## Tarjeta de una materia con temas: suma lo de todos sus temas.
func _group_card(g: Dictionary, kids: Array) -> Dictionary:
	var dom: int = 0
	var total: int = 0
	var due: int = 0
	var done_lv: int = 0
	var all_lv: int = 0
	var open_n: int = 0
	for p in kids:
		var steps: int = Levels.steps_for(p).size()
		done_lv += mini(Progress.subj_level(p["id"]) - 1, steps)
		all_lv += steps
		for pr in p["pairs"]:
			total += 1
			if Progress.pair_stage(pr["id"]) == 2:
				dom += 1
		if Levels.is_open(p):
			open_n += 1
			due += Levels.due_count(p)
	var locked: bool = open_n == 0
	return {"id": "grp:" + str(g["id"]), "name": g["name"], "icon": g["icon"], "sub": _themes_text(kids.size()),
		"sub2": "" if locked else "Dominadas %d de %d" % [dom, total],
		"sub3": ("%d por repasar" % due) if due > 0 else "",
		"frac": float(done_lv) / float(maxi(all_lv, 1)),
		"color": Color(str(g["color"])) if str(g["color"]) != "" else UiTheme.pack_color(str(kids[0]["id"])),
		"locked": locked, "info": "«%s» todavía no está disponible." % g["name"] if locked else ""}

## Tarjeta de un paquete (materia suelta o tema).
func _pack_card(p: Dictionary) -> Dictionary:
	var steps: Array = Levels.steps_for(p)
	var v: int = Progress.subj_level(p["id"])
	var dom: int = 0
	for pr in p["pairs"]:
		if Progress.pair_stage(pr["id"]) == 2:
			dom += 1
	var locked: bool = not Levels.is_open(p)
	var pdue: int = 0 if locked else Levels.due_count(p)
	return {
		"id": p["id"], "name": p["name"], "icon": UiTheme.pack_icon(p["id"]),
		"sub": "No disponible" if locked else ("Completada" if v > steps.size() else "Nivel %d de %d" % [v, steps.size()]),
		"sub2": "" if locked else "Dominadas %d de %d" % [dom, (p["pairs"] as Array).size()],
		"sub3": ("%d por repasar" % pdue) if pdue > 0 else ("Paquete propio" if bool(p.get("external", false)) else ""),
		"frac": 1.0 if v > steps.size() else float(v - 1) / float(maxi(steps.size(), 1)),
		"color": UiTheme.pack_color(p["id"]), "locked": locked,
		"info": "«%s» todavía no está disponible." % p["name"] if locked else ""}

## Ayuda: mesa 3D a la izquierda del álbum con los pasos para jugar. Solo informa.
func _go_help() -> void:
	state = S.HELP
	board.build_help()
	ui.show_help()
	board.fly_to_station("help", 0.9 if board.station != "help" else 0.0)

## Álbum: mesa 3D con todas las parejas de cada materia; las dominadas, boca arriba.
func _go_album() -> void:
	state = S.ALBUM
	var data: Array = []
	for p in packs:
		var locked: bool = not Levels.is_open(p)
		var pairs: Array = []
		if not locked:
			for pr in p["pairs"]:
				pairs.append({"id": pr["id"], "a": pr["a"], "b": pr["b"], "fact": str(pr.get("fact", "")),
					"stage": Progress.pair_stage(pr["id"])})
		data.append({"id": p["id"], "name": p["name"], "icon": UiTheme.pack_icon(p["id"]),
			"color": UiTheme.pack_color(p["id"]), "locked": locked, "pairs": pairs})
	board.build_album(data)
	board.fly_to_station("album", 0.9 if board.station != "album" else 0.0)
	ui.show_album()
	_show_pan_hint()

## La primera vez que se abre una lista larga: cómo se recorre (se recuerda en el guardado).
func _show_pan_hint() -> void:
	if bool(Progress.data.get("hint", false)):
		return
	Progress.data["hint"] = true
	Progress.save()
	ui.toast("Deslizá para recorrer y usá dos dedos para acercar.")

func _on_album_open(pr: Dictionary) -> void:
	ui.show_fact(pr["a"], pr["b"], str(pr.get("fact", "")))

## Cargar paquete: el selector de archivos del sistema (en Android, el de documentos) devuelve un .zip.
func _pick_pack() -> void:
	if _pack_dialog == null:
		_pack_dialog = FileDialog.new()
		_pack_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_pack_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_pack_dialog.use_native_dialog = true
		_pack_dialog.title = "Cargar paquete"
		_pack_dialog.add_filter("*.zip", "Paquetes de Fichitas", "application/zip,application/x-zip-compressed")
		_pack_dialog.file_selected.connect(_on_pack_file)
		add_child(_pack_dialog)
	_pack_dialog.popup_centered_ratio(0.85)

func _on_pack_file(path: String) -> void:
	var res: Dictionary = PackImport.import_file(path, Packs.official_ids())
	if not bool(res["ok"]):
		ui.toast(str(res["error"]))
		return
	packs = Packs.load_all()
	_go_subjects()  # redibuja la lista con la materia nueva
	ui.toast("«%s» agregada: %d parejas." % [res["name"], res["pairs"]])

## Prepara la sesión y lleva al paso "¿Cómo quieres jugar?".
## `origin` es la estación a la que vuelve "Atrás" si no se empieza la partida.
func _play(sid: String, origin: int = S.SUBJECTS) -> void:
	if not _prepare(sid):
		return
	_go_mode(origin)

## Calcula las parejas del nivel y deja la sesión lista. Devuelve false si no hay
## suficientes parejas para jugar.
func _prepare(sid: String) -> bool:
	cur_sid = sid
	cur_review = false
	var pairs: Array = []
	var label: String = ""
	var last_level: int = Levels.max_level()
	if sid == "":
		cur_level = clampi(Progress.level(), 1, Levels.max_level())
		pairs = Levels.pick_general(packs, cur_level)
		label = "Nivel %d" % cur_level
	else:
		var p: Dictionary = _pack(sid)
		if p.is_empty():
			return false
		var steps: Array = Levels.steps_for(p)
		last_level = steps.size()
		var v: int = Progress.subj_level(sid)
		cur_level = 1 if v > steps.size() else v
		pairs = Levels.pick_subject(p, cur_level)
		label = "%s · Nivel %d" % [p["name"], cur_level]
	if pairs.size() < 3:
		return false
	cur_last = cur_level >= last_level
	_pending_pairs = pairs
	_pending_label = label
	return true

## Icono y color de la sesión actual (repaso, recorrido general o una materia).
func _session_look() -> Dictionary:
	if cur_review:
		return {"icon": "cerebro", "color": Color("ffce6b")}
	if cur_sid == "":
		return {"icon": "brujula", "color": Color("9cc8ff")}
	return {"icon": UiTheme.pack_icon(cur_sid), "color": UiTheme.pack_color(cur_sid)}

## Rótulo plano que va sobre una mesa: lo que antes decía la barra superior 2D.
func _title_data(name: String, sub: String) -> Dictionary:
	var look: Dictionary = _session_look()
	var col: Color = look["color"]
	return {"name": name, "sub": sub, "icon": look["icon"], "color": col, "ink": col.darkened(0.62)}

## Detalle de la sesión que se muestra en el rótulo del paso de modo.
func _pending_detail() -> String:
	if cur_review:
		return "Repaso · %d parejas" % _pending_pairs.size()
	if cur_sid == "":
		return "Recorrido general · Nivel %d" % cur_level
	return "%s · Nivel %d" % [_pack(cur_sid)["name"], cur_level]

## Estación del modo: la cámara se detiene sobre las dos losetas y espera la elección.
func _go_mode(origin: int) -> void:
	_mode_from = origin
	state = S.MODE
	ui.show_mode()
	board.build_mode(str(Progress.data["mode"]), _title_data("¿Cómo quieres jugar?", _pending_detail()))
	board.fly_to_station("mode", 0.9 if board.station != "mode" else 0.0)

func _on_mode_chosen(m: String) -> void:
	if state != S.MODE:
		return  # un segundo toque no debe reiniciar la partida que acaba de arrancar
	state = S.GAME
	_remember_mode(m)
	_start(_pending_pairs, _pending_label)

## Repaso: hasta 10 parejas pendientes de todas las materias abiertas, en una sola sesión.
func _play_review() -> void:
	var due: Array = Levels.due_pairs(packs)
	if due.size() < 3:
		return
	cur_review = true
	cur_sid = ""
	cur_level = 0
	cur_last = true
	_pending_pairs = due.slice(0, mini(10, due.size()))
	_pending_label = "Repaso"
	_go_mode(S.SUBJECTS)

func _start(pairs: Array, label: String) -> void:
	cur_pairs = pairs
	stage_before.clear()
	for pr in pairs:
		stage_before[pr["id"]] = Progress.pair_stage(pr["id"])
	var from_win: bool = state == S.WIN
	state = S.GAME
	board.mode = str(Progress.data["mode"])
	var mode_name: String = "Memoria" if board.mode == "mem" else "Asociación"
	var tname: String = "Repaso" if cur_review else ("Recorrido general" if cur_sid == "" else str(_pack(cur_sid)["name"]))
	var tsub: String = "%d parejas · %s" % [pairs.size(), mode_name] if cur_review else "Nivel %d · %s" % [cur_level, mode_name]
	board.set_title(_title_data(tname, tsub))   # va en la franja de la mesa del tablero
	ui.show_hud()
	# Desde el paso de modo, la cámara baja hasta el tablero; desde la victoria, vuelve a la izquierda
	# (más corto: al repetir nivel el jugador ya conoce el camino)
	board.fly_to_station("game", 0.85 if from_win else 0.95)
	board.start(pairs, 0.4 if from_win else 0.78)

func _on_won() -> void:
	state = S.WIN
	var msg: String
	var btn: String
	if cur_review:
		msg = "Has repasado %d parejas." % cur_pairs.size()
		btn = "Volver a materias"
	else:
		if cur_sid != "" and cur_last:
			var steps: Array = Levels.steps_for(_pack(cur_sid))
			(Progress.data["subj"] as Dictionary)[cur_sid] = steps.size() + 1
			Progress.save()
		msg = "Has emparejado %d parejas." % cur_pairs.size()
		if cur_last:
			msg = "Has completado todos los niveles de %s. ¡Gran trabajo!" % _pack(cur_sid)["name"] if cur_sid != "" else "Has recorrido todas las colecciones disponibles. ¡Gran trabajo!"
		btn = "Siguiente nivel"
		if cur_last:
			btn = "Volver a materias" if cur_sid != "" else "Volver al menú"
	var title: String = "¡Repaso completado!" if cur_review else "¡Nivel %d completado!" % cur_level
	# La victoria es una estación del mundo: una mesa a la derecha del tablero
	ui.hide_all()
	board.build_win({"title": title, "msg": msg, "button": btn, "doms": _doms(), "total": cur_pairs.size()})
	board.fly_to_station("win", 0.9)

## Cuántas parejas entran en la victoria sin volverse ilegibles: seis, en tres filas de
## dos parejas (12 fichas). Con más, la mesa se estira y pierde el encuadre, así que el
## resto se resume en la ficha "+N".
const WIN_DOMS := 6

## Estado de dominio de las parejas de la sesión, para las fichas de la victoria.
## Con muchas parejas se muestran primero las que subieron de dominio y el resto se
## resume en una ficha "+N".
func _doms() -> Array:
	var all: Array = []
	for pr in cur_pairs:
		var st: int = Progress.pair_stage(pr["id"])
		all.append({"a": pr["a"], "b": pr["b"], "stage": st, "up": st > int(stage_before.get(pr["id"], 0))})
	if all.size() <= WIN_DOMS:
		return all
	var shown: Array = []
	var rest: Array = []
	for d in all:
		if bool(d["up"]) and shown.size() < WIN_DOMS:
			shown.append(d)
		else:
			rest.append(d)
	for d in rest:
		if shown.size() < WIN_DOMS:
			shown.append(d)
	shown.append({"more": all.size() - WIN_DOMS})
	return shown

func _on_next() -> void:
	if cur_review:
		_go_subjects()
		return
	if cur_last:
		# El recorrido general entra desde materias con `cur_sid == ""`: manda el origen,
		# no el id de la sesión (si no, volvería al menú principal).
		if _mode_from == S.SUBJECTS:
			_go_subjects()
		else:
			_go_menu()
		return
	if cur_sid == "":
		Progress.data["level"] = cur_level + 1
	else:
		(Progress.data["subj"] as Dictionary)[cur_sid] = cur_level + 1
	Progress.save()
	# Siguiente nivel: se conserva el modo elegido, sin volver al paso de modo.
	if not _prepare(cur_sid):
		if cur_sid == "":
			_go_menu()
		else:
			_go_subjects()
		return
	_start(_pending_pairs, _pending_label)

func _on_back() -> void:
	match state:
		S.MODE:
			if _mode_from == S.MENU:
				_go_menu()
			else:
				_go_subjects()
		S.GAME, S.WIN:
			if _mode_from == S.SUBJECTS:
				_go_subjects()
			else:
				_go_menu()
		S.SUBJECTS:
			if _group_open != "":
				_close_group()
			else:
				_go_menu()
		S.HELP:
			_go_menu()
		S.ALBUM:
			if not ui.close_fact():
				_go_menu()
