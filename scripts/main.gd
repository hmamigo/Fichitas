extends Node
## Orquestador: menús, niveles y guardado. El tablero y la interfaz solo emiten señales.

enum S { MENU, SUBJECTS, GAME, WIN }
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
	board.menu_station.play_general.connect(func() -> void: _play(""))
	board.menu_station.open_subjects.connect(_go_subjects)
	board.menu_station.mode_changed.connect(_on_mode)
	board.subject_station.chosen.connect(_on_subject)
	board.subject_station.info.connect(ui.toast)
	ui.back_pressed.connect(_on_back)
	ui.next_pressed.connect(_on_next)
	ui.sound_toggled.connect(_on_sound)
	ui.vib_toggled.connect(_on_vib)
	_go_menu()

func _on_mode(m: String) -> void:
	Progress.data["mode"] = m
	Progress.save()
	board.mode = m
	_on_sfx("flip")

func _on_subject(id: String) -> void:
	if id == ":review":
		_play_review()
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
	var mode: String = str(Progress.data["mode"])
	board.mode = mode
	board.build_menu(mode, Progress.level())
	board.fly_to_station("menu", 0.9 if board.station != "menu" else 0.0)
	ui.show_menu({
		"sound": bool(Progress.data["sound"]),
		"vib": bool(Progress.data["vib"]),
		"vib_visible": OS.has_feature("mobile"),
	})

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
	cards.append({"id": "", "name": "Recorrido general", "icon": "compass", "sub": "Nivel %d de %d" % [mini(Progress.level(), Levels.max_level()), Levels.max_level()], "sub2": "", "frac": float(mini(Progress.level(), Levels.max_level()) - 1) / float(Levels.max_level()), "sub3": due_txt, "color": Color("9cc8ff")})
	if due.size() >= 3:  # el repaso necesita al menos tres parejas
		cards.append({"id": ":review", "name": "Repaso", "icon": "stars", "sub": "%d parejas esperando" % due.size(),
			"sub2": "De todas las materias", "color": Color("ffce6b")})
	for p in packs:
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
			"sub3": ("%d por repasar" % pdue) if pdue > 0 else "",
			"frac": 1.0 if v > steps.size() else float(v - 1) / float(maxi(steps.size(), 1)),
			"color": UiTheme.pack_color(p["id"]), "locked": locked,
			"info": "«%s» es una materia de pago. La compra aún no está disponible." % p["name"]})
	for n in COMING:
		var exists: bool = false
		for p in packs:
			if p["name"] == n:
				exists = true
		if not exists:
			cards.append({"id": "coming:" + n, "name": n, "icon": "book" if n == "Historia" else "stars", "sub": "Próximamente", "sub2": "", "color": Color("c9cfdb"), "locked": true,
				"info": "«%s» llegará pronto. Algunas materias nuevas serán de pago." % n})
	board.build_subjects(cards)
	board.fly_to_station("subjects", 1.0)
	ui.show_subjects()

func _play(sid: String) -> void:
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
			return
		var steps: Array = Levels.steps_for(p)
		last_level = steps.size()
		var v: int = Progress.subj_level(sid)
		cur_level = 1 if v > steps.size() else v
		pairs = Levels.pick_subject(p, cur_level)
		label = "%s · Nivel %d" % [p["name"], cur_level]
	if pairs.size() < 3:
		return
	cur_last = cur_level >= last_level
	_start(pairs, label)

## Repaso: hasta 10 parejas pendientes de todas las materias abiertas, en una sola sesión.
func _play_review() -> void:
	var due: Array = Levels.due_pairs(packs)
	if due.size() < 3:
		return
	cur_review = true
	cur_sid = ""
	cur_level = 0
	cur_last = true
	_start(due.slice(0, mini(10, due.size())), "Repaso")

func _start(pairs: Array, label: String) -> void:
	cur_pairs = pairs
	stage_before.clear()
	for pr in pairs:
		stage_before[pr["id"]] = Progress.pair_stage(pr["id"])
	var next_level: bool = state == S.WIN
	state = S.GAME
	board.mode = str(Progress.data["mode"])
	ui.show_hud("%s · %s" % [label, "Memoria" if board.mode == "mem" else "Asociación"])
	# Desde las materias, la cámara baja hasta el tablero; entre niveles, un acercamiento corto
	if next_level:
		if board.station == "game":
			board.zoom = 0.9  # el vuelo parte de un poco más lejos
		board.fly_to_station("game", 0.55)
	else:
		board.fly_to_station("game", 1.3)
	board.start(pairs, 0.33 if next_level else 0.78)

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
	ui.show_win(title, msg, btn, _doms())

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
	_play(cur_sid)

func _on_back() -> void:
	match state:
		S.GAME, S.WIN:
			if cur_review or cur_sid != "":
				_go_subjects()
			else:
				_go_menu()
		S.SUBJECTS:
			_go_menu()
