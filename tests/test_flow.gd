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
	var menu_tilt: float = float(main.board._pose()["tilt"])
	main.board.station = "subjects"
	var subjects_tilt: float = float(main.board._pose()["tilt"])
	main.board.station = "game"
	var game_tilt: float = float(main.board._pose()["tilt"])
	main.board.station = "menu"
	check(is_equal_approx(menu_tilt, subjects_tilt) and is_equal_approx(menu_tilt, game_tilt), "las tres estaciones mantienen el mismo ángulo de cámara")
	main.board.fly_to_station("menu", 0.0)
	await process_frame
	var mtiles: Array = main.board.menu_station.tiles
	var menu_stack_ok: bool = true
	for i in mtiles.size():
		var tile: Plaque = mtiles[i]
		menu_stack_ok = menu_stack_ok and tile.size.x > tile.size.y and is_zero_approx(tile.position.x)
		if i > 0:
			menu_stack_ok = menu_stack_ok and tile.position.z > (mtiles[i - 1] as Plaque).position.z
	check(menu_stack_ok, "las acciones del menú son rectangulares y forman una sola columna vertical")
	var mx: float = main.board.menu_station.position.x
	var sx: float = main.board.subject_station.position.x
	var same_z: bool = is_zero_approx(main.board.menu_station.position.z) and is_zero_approx(main.board.subject_station.position.z)
	check(mx < sx and sx < 0.0 and same_z, "las estaciones están en fila en X: menú, materias y tablero")
	var vps: Vector2 = main.get_viewport().get_visible_rect().size
	var floor_ok: bool = true
	for corner in [Vector2.ZERO, Vector2(vps.x, 0.0), Vector2(0.0, vps.y), vps]:
		var g: Vector3 = main.board._ground_point(corner)
		floor_ok = floor_ok and g.x >= FloorCubes.X_MIN and g.x <= FloorCubes.X_MAX and g.z >= -FloorCubes.Z_FAR and g.z <= FloorCubes.Z_NEAR
	check(floor_ok, "las cuatro esquinas de la vista del menú caen sobre el suelo de cubos")
	var mspot: Vector2 = main.board.cam.unproject_position((mtiles[1] as Plaque).global_position)
	main.board.menu_station.tap(mspot, main.board.cam)
	check(str(Progress.data["mode"]) == "assoc", "toque en la loseta de Asociación cambia el modo")
	Progress.data["mode"] = "mem"
	main.board.mode = "mem"
	main.board.menu_station.set_mode("mem")
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
	check(main.state == 1 and main.ui.subjects.visible and main.board.subject_station.tiles.size() == 11, "pantalla de materias con 11 losetas")
	check(main.board.menu_station.visible and main.board.subject_station.visible, "las mesas de origen y destino se ven durante el vuelo")
	await create_timer(1.1).timeout
	check(not main.board.menu_station.visible and main.board.subject_station.visible, "al llegar solo queda visible la mesa activa")
	var stiles: Array = main.board.subject_station.tiles
	var subject_stack_ok: bool = true
	for i in stiles.size():
		var tile: Plaque = stiles[i]
		subject_stack_ok = subject_stack_ok and tile.size.x > tile.size.y and is_zero_approx(tile.position.x)
		if i > 0:
			subject_stack_ok = subject_stack_ok and tile.position.z > (stiles[i - 1] as Plaque).position.z
	check(subject_stack_ok, "recorrido, repaso y materias son rectangulares y forman una sola columna")
	var mat_tile: Plaque = null
	for t in stiles:
		if (t as Plaque).key == "mat":
			mat_tile = t
			break
	check(mat_tile != null and mat_tile.info.is_empty(), "la materia gratuita no muestra aviso de pago")
	if mat_tile != null:
		var mat_spot: Vector2 = main.board.cam.unproject_position(mat_tile.global_position)
		main.board.subject_station.tap(mat_spot, main.board.cam)
	check(main.state == 2 and main.cur_sid == "mat" and not main.board.tiles.is_empty(), "tocar una materia gratuita inicia su nivel")
	main._go_subjects()
	await create_timer(1.1).timeout
	stiles = main.board.subject_station.tiles
	var spot: Vector2 = main.board.cam.unproject_position((stiles[0] as Plaque).global_position)
	check(Pick3D.plaque(stiles, main.board.cam, spot) == stiles[0], "toque proyectado sobre una loseta de materia")
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
	check(main.board.subject_station.tiles.size() == 11, "materias se redibuja")
	main._on_back()
	check(main.state == 0, "Atrás vuelve al menú")
	print("Resultado: %s" % ("TODO OK" if fails == 0 else "%d fallos" % fails))
	quit(0 if fails == 0 else 1)
