extends SceneTree
## Flujo completo (menús, niveles, guardado): godot --headless --path . --script res://tests/test_flow.gd

var fails: int = 0

func check(ok: bool, msg: String) -> void:
	print(("  OK   " if ok else "  FALLA ") + msg)
	if not ok:
		fails += 1

func _solve(main: Node, wait: float) -> void:
	var groups: Dictionary = {}
	for t in main.board.tiles:
		if not groups.has(t.pair):
			groups[t.pair] = []
		groups[t.pair].append(t)
	for id in groups:
		main.board._tap(groups[id][0])
		await create_timer(0.05).timeout
		main.board._tap(groups[id][1])
		await create_timer(wait).timeout

func _init() -> void:
	_run()

func _run() -> void:
	Progress.path = "user://test_progress.json"
	if FileAccess.file_exists(Progress.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Progress.path))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	check(main.state == 0 and main.ui.menu.visible, "arranca en el menú")
	print("Recorrido general (memoria)")
	main._play("")
	await process_frame
	check(main.board.tiles.size() == 6 and main.board.mode == "mem" and main.ui.hud_bar.visible, "nivel 1: 3 parejas")
	await _solve(main, 0.8)
	await create_timer(2.8).timeout
	check(main.state == 3 and main.ui.win.visible, "nivel completado muestra la pantalla de victoria")
	main._on_next()
	await process_frame
	check(Progress.level() == 2 and main.board.tiles.size() == 8, "avanza al nivel 2 (4 parejas)")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Progress.path))
	check(int(saved["level"]) == 2 and (saved["mp"] as Dictionary).size() >= 3 and (saved["sr"] as Dictionary).size() >= 3, "progreso, dominio y repaso guardados en JSON")
	print("Materias (asociación)")
	main._go_subjects()
	check(main.state == 1 and main.ui.subjects.visible and main.ui.grid.get_child_count() == 11, "pantalla de materias con 11 tarjetas")
	Progress.data["mode"] = "assoc"
	main._play("qui")
	await process_frame
	check(main.board.tiles.size() == 6 and main.board.mode == "assoc" and main.cur_sid == "qui", "materia Química, nivel 1 (3 parejas)")
	await _solve(main, 0.05)
	await create_timer(2.8).timeout
	check(main.state == 3, "victoria en asociación")
	main._on_next()
	await process_frame
	check(Progress.subj_level("qui") == 2 and main.board.tiles.size() == 8, "Química avanza a su nivel 2 (4 parejas)")
	var steps: Array = Levels.steps_for(main._pack("qui"))
	check(steps == [3, 4, 5, 6, 8], "niveles de Química: %s" % str(steps))
	(Progress.data["subj"] as Dictionary)["qui"] = steps.size()
	main._play("qui")
	await process_frame
	check(main.board.tiles.size() == 16 and main.cur_last, "último nivel de la materia (8 parejas)")
	await _solve(main, 0.05)
	await create_timer(3.5).timeout
	check(main.state == 3, "victoria del último nivel")
	main._on_next()
	check(main.state == 1 and Progress.subj_level("qui") == steps.size() + 1, "materia completada vuelve a materias")
	main._go_subjects()
	check(main.ui.grid.get_child_count() == 11, "materias se redibuja")
	main._on_back()
	check(main.state == 0, "Atrás vuelve al menú")
	print("Resultado: %s" % ("TODO OK" if fails == 0 else "%d fallos" % fails))
	quit(0 if fails == 0 else 1)
