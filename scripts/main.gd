extends Node
## Orquestador: menús, niveles y guardado. El tablero y la interfaz solo emiten señales.

enum S { MENU, SUBJECTS, MODE, GAME, WIN, ALBUM }
const COMING := ["Historia", "Más materias"]

var board: Board
var ui: GameUI
var audio: GameAudio
var packs: Array = []
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
	packs = Packs.load_all()
	audio = GameAudio.new()
	add_child(audio)
	audio.enabled = bool(Progress.data["sound"])
	board = Board.new()
	add_child(board)
	ui = GameUI.new()
	add_child(ui)
	board.blockers = [ui.hud_bar]
	board.won.connect(_on_won)
	board.sfx.connect(_on_sfx)
	board.pair_done.connect(func(id: String, clean: bool) -> void: Progress.record(id, clean))
	board.menu_station.play_general.connect(func() -> void: _play("", S.MENU))
	board.menu_station.open_subjects.connect(_go_subjects)
	board.menu_station.open_album.connect(_go_album)
	board.subject_station.chosen.connect(_on_subject)
	board.subject_station.info.connect(ui.toast)
	board.mode_station.chosen.connect(_on_mode_chosen)
	board.album_station.opened.connect(_on_album_open)
	ui.back_pressed.connect(_on_back)
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
	board.stop()
	board.build_menu(Progress.level())
	ui.show_menu({
		"sound": bool(Progress.data["sound"]),
		"vib": bool(Progress.data["vib"]),
		"vib_visible": OS.has_feature("mobile"),
	})
	_center_menu()
	board.fly_to_station("menu", 0.9 if board.station != "menu" else 0.0)
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

## Sonido y vibración: los efectos vienen de `board.sfx`.
func _on_sfx(name: String) -> void:
	audio.play(name)
	if bool(Progress.data["vib"]) and OS.has_feature("mobile"):
		Input.vibrate_handheld(35 if name == "err" else (60 if name == "win" else 12))

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
	board.stop()
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
	for p in packs:
		if p.get("category", Packs.DEFAULT_CATEGORY) != last_cat:   # `packs` viene agrupado por categoría: una cabecera por grupo
			last_cat = p.get("category", Packs.DEFAULT_CATEGORY)
			for c in Packs.CATEGORIES:
				if c["id"] == last_cat:
					cards.append({"id": "hdr:" + last_cat, "header": true, "name": c["name"], "sub": c["sub"],
						"icon": c["icon"], "color": c["color"], "ink": c["ink"], "frame": c["frame"]})
		var steps: Array = Levels.steps_for(p)
		var v: int = Progress.subj_level(p["id"])
		var dom: int = 0
		for pr in p["pairs"]:
			if Progress.pair_stage(pr["id"]) == 2:
				dom += 1
		var locked: bool = not Levels.is_open(p)
		var pdue: int = 0 if locked else Levels.due_count(p)
		cards.append({
			"id": p["id"], "name": p["name"], "icon": UiTheme.pack_icon(p["id"]),
			"sub": "De pago" if locked else ("Completada" if v > steps.size() else "Nivel %d de %d" % [v, steps.size()]),
			"sub2": "" if locked else "Dominadas %d/%d" % [dom, (p["pairs"] as Array).size()],
			"sub3": ("%d por repasar" % pdue) if pdue > 0 else ("Paquete propio" if bool(p.get("external", false)) else ""),
			"frac": 1.0 if v > steps.size() else float(v - 1) / float(maxi(steps.size(), 1)),
			"color": UiTheme.pack_color(p["id"]), "locked": locked,
			"info": "«%s» es una materia de pago. La compra aún no está disponible." % p["name"] if locked else ""})
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
				"info": "«%s» llegará pronto. Algunas materias nuevas serán de pago." % n})
	board.build_subjects(cards)
	board.fly_to_station("subjects", 1.0)
	ui.show_subjects()

## Álbum: mesa 3D con todas las parejas de cada materia; las dominadas, boca arriba.
func _go_album() -> void:
	state = S.ALBUM
	board.stop()
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

## Detalle de la sesión que se muestra en la cabecera del paso de modo.
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
	board.stop()
	ui.show_mode(_pending_detail())
	board.build_mode(str(Progress.data["mode"]))
	board.fly_to_station("mode", 0.9 if board.station != "mode" else 0.0)

func _on_mode_chosen(m: String) -> void:
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
	ui.show_hud("%s · %s" % [label, "Memoria" if board.mode == "mem" else "Asociación"])
	# Desde el paso de modo, la cámara baja hasta el tablero; desde la victoria, vuelve a la izquierda
	board.fly_to_station("game", 1.1 if from_win else 0.95)
	board.start(pairs, 0.6 if from_win else 0.78)

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
		msg = "Has emparejado %d parejas." % int(board.tiles.size() / 2.0)
		if cur_last:
			msg = "Has completado todos los niveles de %s. ¡Gran trabajo!" % _pack(cur_sid)["name"] if cur_sid != "" else "Has recorrido todas las colecciones disponibles. ¡Gran trabajo!"
		btn = "Siguiente nivel"
		if cur_last:
			btn = "Volver a materias" if cur_sid != "" else "Volver al menú"
	var title: String = "¡Repaso completado!" if cur_review else "¡Nivel %d completado!" % cur_level
	# La victoria es una estación del mundo: una mesa a la derecha del tablero
	ui.hide_all()
	board.build_win({"title": title, "msg": msg, "button": btn, "doms": _doms()})
	board.fly_to_station("win", 1.1)

## Estado de dominio de las parejas de la sesión, para las miniaturas de la victoria.
func _doms() -> Array:
	var out: Array = []
	for pr in cur_pairs:
		var st: int = Progress.pair_stage(pr["id"])
		out.append({"tex": pr["a"], "stage": st, "up": st > int(stage_before.get(pr["id"], 0))})
	return out

func _on_next() -> void:
	if cur_review:
		_go_subjects()
		return
	if cur_last:
		if cur_sid != "":
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
			if cur_review or cur_sid != "":
				_go_subjects()
			else:
				_go_menu()
		S.SUBJECTS:
			_go_menu()
		S.ALBUM:
			if not ui.close_fact():
				_go_menu()
