extends SceneTree
## Repaso espaciado, sesión de repaso y sonidos: godot --headless --path . --script res://tests/test_review.gd

var fails: int = 0

func check(ok: bool, msg: String) -> void:
	print(("  OK   " if ok else "  FALLA ") + msg)
	if not ok:
		fails += 1

func _pair(id: String) -> Dictionary:
	return {"id": id, "a": null, "b": null}

func _init() -> void:
	_run()

func _run() -> void:
	Progress.path = "user://test_review.json"
	if FileAccess.file_exists(Progress.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Progress.path))
	var now: int = int(Time.get_unix_time_from_system())
	Progress.data = Progress.defaults()
	var sr: Dictionary = Progress.data["sr"]
	sr["a"] = {"b": 1, "d": now - 100}
	sr["b"] = {"b": 1, "d": now - 900}
	sr["c"] = {"b": 2, "d": now + 99999}

	print("Selección con repaso")
	var pool: Array = [_pair("a"), _pair("b"), _pair("c"), _pair("d"), _pair("e")]
	var sel: Array = Levels.choose(pool, 3)
	var ids: Array = sel.map(func(p): return p["id"])
	check(sel.size() == 3, "el nivel tiene 3 parejas (%s)" % str(ids))
	check(ids.has("b"), "entra la pendiente más atrasada")
	check(ids.count("b") == 1 and not ids.has("c"), "no entra lo que no toca repasar")
	check(ids.has("d") or ids.has("e"), "se completa con parejas nuevas")
	var forced: Array = [_pair("c")]
	var sel2: Array = Levels.choose(pool, 3, forced)
	check(sel2.size() == 3 and sel2.map(func(p): return p["id"]).has("c"), "la pareja forzada siempre entra")
	var only_due: Array = Levels.choose([_pair("a"), _pair("b"), _pair("c")], 3)
	check(only_due.size() == 3, "si todo está pendiente, el nivel se llena igual")
	check(Progress.is_due("a") and not Progress.is_due("c") and Progress.is_new("z"), "is_due / is_new")

	print("Calendario")
	Progress.record("b", true)
	check(not Progress.is_due("b"), "acertar saca la pareja del repaso")
	check(int((Progress.data["sr"]["b"] as Dictionary)["b"]) == 2, "la caja sube a 2")
	Progress.record("b", false)
	check(int((Progress.data["sr"]["b"] as Dictionary)["b"]) == 1, "la caja baja a 1")
	check(not Progress.is_due("b"), "bajar a la caja 1 aún espera un día")
	Progress.record("b", false)
	check(int((Progress.data["sr"]["b"] as Dictionary)["b"]) == 0, "la caja baja a 0")
	check(Progress.is_due("b"), "la caja 0 vuelve a estar pendiente de inmediato")

	print("Sesión de repaso")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 4:
		await process_frame
	var packs: Array = main.packs
	var p: Dictionary = main._pack("qui")
	for i in 4:
		Progress.data["sr"][p["pairs"][i]["id"]] = {"b": 1, "d": now - 3600 * (i + 1)}
	check(Levels.due_pairs(packs).size() >= 4, "due_pairs junta las pendientes")
	check(Levels.due_count(p) == 4, "due_count por materia")
	main._go_subjects()
	check(main.board.subject_station.tiles.size() == 12, "la tarjeta Repaso aparece en materias")
	main._play_review()
	await process_frame
	check(main.cur_review and main.state == 2, "entra en la sesión de repaso")
	check(main.board.tiles.size() == 8, "4 parejas pendientes = 8 fichas")
	check(main.ui.lv_label.text.begins_with("Repaso"), "el HUD dice Repaso")
	main._on_won()
	check(main.state == 3 and main.ui.win.visible, "pantalla de repaso completado")
	check(main.ui.win_title.text == "¡Repaso completado!", "título de repaso")
	check(main.ui.dom_grid.get_child_count() == 4, "miniaturas de dominio del repaso")
	main._on_next()
	check(main.state == 1, "el repaso vuelve a materias")

	print("Sonidos")
	var a := GameAudio.new()
	root.add_child(a)
	for n in ["flip", "ok", "err", "win"]:
		var w: AudioStreamWAV = a._make(n)
		check(w != null and w.data.size() > 44, "efecto %s sintetizado (%d bytes)" % [n, 0 if w == null else w.data.size()])
	check(a._make("nada") == null, "un efecto desconocido no rompe")
	a.enabled = false
	a.play("ok")
	check(not a._streams.has("ok"), "con el sonido apagado no se reproduce")
	a.enabled = true
	a.play("ok")
	check(a._streams.has("ok"), "con el sonido encendido se reproduce")

	print("Resultado: %s" % ("TODO OK" if fails == 0 else "%d fallos" % fails))
	quit(0 if fails == 0 else 1)
