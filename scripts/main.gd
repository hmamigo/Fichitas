extends Node
## Orquestador: menús, niveles y guardado. El tablero y la interfaz solo emiten señales.

enum S { MENU, SUBJECTS, GAME, WIN }
const COMING := ["Historia", "Más materias"]

var board: Board
var ui: GameUI
var packs: Array = []
var state: int = S.MENU
var cur_sid: String = ""
var cur_level: int = 1
var cur_last: bool = false

func _ready() -> void:
	Progress.load_data()
	packs = Packs.load_all()
	board = Board.new()
	add_child(board)
	ui = GameUI.new()
	add_child(ui)
	board.blockers = [ui.hud_bar]
	board.won.connect(_on_won)
	board.pair_done.connect(func(id: String, clean: bool) -> void: Progress.record(id, clean))
	ui.play_general.connect(func() -> void: _play(""))
	ui.play_subject.connect(_play)
	ui.open_subjects.connect(_go_subjects)
	ui.back_pressed.connect(_on_back)
	ui.next_pressed.connect(_on_next)
	ui.mode_changed.connect(func(m: String) -> void:
		Progress.data["mode"] = m
		Progress.save())
	_go_menu()

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
	ui.show_menu(Progress.level(), str(Progress.data["mode"]))

func _go_subjects() -> void:
	state = S.SUBJECTS
	board.stop()
	var cards: Array = []
	cards.append({"id": "", "name": "Recorrido general", "sub": "Nivel %d de %d" % [mini(Progress.level(), Levels.max_level()), Levels.max_level()], "sub2": "", "color": Color("9cc8ff")})
	for p in packs:
		var steps: Array = Levels.steps_for(p)
		var v: int = Progress.subj_level(p["id"])
		var dom: int = 0
		for pr in p["pairs"]:
			if Progress.pair_stage(pr["id"]) == 2:
				dom += 1
		var locked: bool = not Levels.is_open(p)
		cards.append({
			"id": p["id"], "name": p["name"],
			"sub": "De pago" if locked else ("Completada" if v > steps.size() else "Nivel %d de %d" % [v, steps.size()]),
			"sub2": "" if locked else "Dominadas %d/%d" % [dom, (p["pairs"] as Array).size()],
			"color": UiTheme.pack_color(p["id"]), "locked": locked,
			"info": "«%s» es una materia de pago. La compra aún no está disponible." % p["name"]})
	for n in COMING:
		var exists: bool = false
		for p in packs:
			if p["name"] == n:
				exists = true
		if not exists:
			cards.append({"id": "coming:" + n, "name": n, "sub": "Próximamente", "sub2": "", "color": Color("c9cfdb"), "locked": true,
				"info": "«%s» llegará pronto. Algunas materias nuevas serán de pago." % n})
	ui.show_subjects(cards)

func _play(sid: String) -> void:
	cur_sid = sid
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
	state = S.GAME
	board.mode = str(Progress.data["mode"])
	ui.show_hud("%s · %s" % [label, "Memoria" if board.mode == "mem" else "Asociación"])
	board.start(pairs)

func _on_won() -> void:
	state = S.WIN
	if cur_sid != "" and cur_last:
		var steps: Array = Levels.steps_for(_pack(cur_sid))
		(Progress.data["subj"] as Dictionary)[cur_sid] = steps.size() + 1
		Progress.save()
	var msg: String = "Has emparejado %d parejas." % int(board.tiles.size() / 2.0)
	if cur_last:
		msg = "Has completado todos los niveles de %s. ¡Gran trabajo!" % _pack(cur_sid)["name"] if cur_sid != "" else "Has recorrido todas las colecciones disponibles. ¡Gran trabajo!"
	var btn: String = "Siguiente nivel"
	if cur_last:
		btn = "Volver a materias" if cur_sid != "" else "Volver al menú"
	ui.show_win("¡Nivel %d completado!" % cur_level, msg, btn)

func _on_next() -> void:
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
			if cur_sid != "":
				_go_subjects()
			else:
				_go_menu()
		S.SUBJECTS:
			_go_menu()
