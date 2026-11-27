extends SceneTree
## Flujo completo (menús, paso de modo, niveles, guardado): godot --headless --path . --script res://tests/test_flow.gd

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

## Loseta del paso de modo con la clave pedida ("mem" o "assoc").
func _mode_tile(main: Node, key: String) -> Plaque:
	for t in main.board.mode_station.tiles:
		if (t as Plaque).key == key:
			return t
	return null

## Toca una loseta de la mesa de modo, como haría el jugador.
func _choose_mode(main: Node, key: String) -> void:
	var t: Plaque = _mode_tile(main, key)
	main.board.mode_station.tap(main.board.cam.unproject_position(t.global_position), main.board.cam)

func _init() -> void:
	_run()

func _run() -> void:
	Progress.path = "user://test_progress.json"
	PackImport.dir = "user://test_packs_empty"  # sin paquetes externos del usuario
	if FileAccess.file_exists(Progress.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Progress.path))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	check(main.state == main.S.MENU and main.ui.menu.visible, "arranca en el menú")
	var menu_tilt: float = float(main.board._pose()["tilt"])
	main.board.station = "subjects"
	var subjects_tilt: float = float(main.board._pose()["tilt"])
	main.board.station = "mode"
	var mode_tilt: float = float(main.board._pose()["tilt"])
	main.board.station = "game"
	var game_tilt: float = float(main.board._pose()["tilt"])
	main.board.station = "menu"
	check(is_equal_approx(menu_tilt, subjects_tilt) and is_equal_approx(menu_tilt, mode_tilt) and is_equal_approx(menu_tilt, game_tilt), "todas las estaciones mantienen el mismo ángulo de cámara")
	main.board.fly_to_station("menu", 0.0)
	await process_frame
	var band: float = main.ui.menu_band_center()
	check(band > 0.5 and band < 0.75, "la franja del menú queda entre la cabecera y los ajustes")
	main.board.center_menu(band)
	main.board._update_cam()
	var ftop: float = INF
	var fbottom: float = -INF
	for p in main.board.menu_station.frame_corners():
		var sy: float = main.board.cam.unproject_position(p).y
		ftop = minf(ftop, sy)
		fbottom = maxf(fbottom, sy)
	var fcenter: float = (ftop + fbottom) * 0.5 / main.get_viewport().get_visible_rect().size.y
	check(absf(fcenter - band) < 0.01, "la mesa del menú queda centrada en la franja 2D")
	var mtiles: Array = main.board.menu_station.tiles
	var menu_stack_ok: bool = true
	for i in mtiles.size():
		var tile: Plaque = mtiles[i]
		menu_stack_ok = menu_stack_ok and tile.size.x > tile.size.y and is_zero_approx(tile.position.x)
		if i > 0:
			menu_stack_ok = menu_stack_ok and tile.position.z > (mtiles[i - 1] as Plaque).position.z
	check(menu_stack_ok, "las acciones del menú son rectangulares y forman una sola columna vertical")
	var menu_keys: Array = mtiles.map(func(t: Plaque) -> String: return t.key)
	check(menu_keys == ["subjects", "general", "help", "album"], "el menú ofrece materias, recorrido general, cómo jugar y álbum (%s)" % str(menu_keys))
	var mx: float = main.board.menu_station.position.x
	var sx: float = main.board.subject_station.position.x
	var dx: float = main.board.mode_station.position.x
	var same_z: bool = is_zero_approx(main.board.menu_station.position.z) and is_zero_approx(main.board.subject_station.position.z) and is_zero_approx(main.board.mode_station.position.z)
	var ax: float = main.board.album_station.position.x
	var hx: float = main.board.help_station.position.x
	check(hx < ax and ax < mx and mx < sx and sx < dx and dx < 0.0 and same_z and is_zero_approx(main.board.album_station.position.z) and is_zero_approx(main.board.help_station.position.z), "las estaciones están en fila en X: ayuda, álbum, menú, materias, modo y tablero")
	var vps: Vector2 = main.get_viewport().get_visible_rect().size
	var floor_ok: bool = true
	for corner in [Vector2.ZERO, Vector2(vps.x, 0.0), Vector2(0.0, vps.y), vps]:
		var g: Vector3 = main.board._ground_point(corner)
		floor_ok = floor_ok and g.x >= FloorCubes.X_MIN and g.x <= FloorCubes.X_MAX and g.z >= -main.board.floor_cubes.z_far and g.z <= main.board.floor_cubes.z_near
	check(floor_ok, "las cuatro esquinas de la vista del menú caen sobre el suelo de cubos")
	# El menú ya no cambia el modo: el recorrido general pasa por el paso de modo.
	var general_tile: Plaque = mtiles[1]
	var gspot: Vector2 = main.board.cam.unproject_position(general_tile.global_position)
	main.board.menu_station.tap(gspot, main.board.cam)
	await process_frame
	check(main.state == main.S.MODE and main.board.station == "mode" and main.ui.mode_screen.visible, "el recorrido general abre el paso ¿Cómo quieres jugar?")
	check(main.board.mode_station.tiles.size() == 2, "el paso de modo muestra las dos losetas")
	check(str(Progress.data["mode"]) == "mem", "tocar un destino del menú no cambia el modo")
	main._on_back()
	await process_frame
	check(main.state == main.S.MENU and main.board.station == "menu", "Atrás desde el modo vuelve al menú")
	# La ayuda es una estación más: se abre desde el menú y "Atrás" vuelve.
	var help_tile: Plaque = mtiles[2]
	var hspot: Vector2 = main.board.cam.unproject_position(help_tile.global_position)
	main.board.menu_station.tap(hspot, main.board.cam)
	await process_frame
	check(main.state == main.S.HELP and main.board.station == "help" and main.ui.hud_bar.visible, "la loseta Cómo jugar abre la estación de ayuda")
	check(main.board.help_station.labels.size() == 8, "la ayuda muestra la cabecera, los cinco pasos y los dos pies de demo")
	check(main.board.help_station.demos.size() == 8, "la ayuda tiene dos demos de 4 fichas de ejemplo")
	await create_timer(1.2).timeout
	var hvps: Vector2 = main.get_viewport().get_visible_rect().size
	var hfloor_ok: bool = true
	for hcorner in [Vector2.ZERO, Vector2(hvps.x, 0.0), Vector2(0.0, hvps.y), hvps]:
		var hg: Vector3 = main.board._ground_point(hcorner)
		hfloor_ok = hfloor_ok and hg.x >= FloorCubes.X_MIN and hg.x <= FloorCubes.X_MAX and hg.z >= -main.board.floor_cubes.z_far and hg.z <= main.board.floor_cubes.z_near
	check(hfloor_ok, "las cuatro esquinas de la vista de la ayuda caen sobre el suelo de cubos")
	main._on_back()
	await process_frame
	check(main.state == main.S.MENU and main.board.station == "menu", "Atrás desde la ayuda vuelve al menú")
	print("Recorrido general (memoria)")
	main._play("")
	await process_frame
	check(main.state == main.S.MODE and main.board.tiles.is_empty(), "preparar la partida no reparte fichas todavía")
	_choose_mode(main, "mem")
	await process_frame
	check(main.board.tiles.size() == 6 and main.board.mode == "mem" and main.ui.hud_bar.visible, "nivel 1: 3 parejas")
	check(str(main.board.game_title.get("sub", "")).ends_with("Memoria"), "el título de la mesa del tablero muestra el modo elegido")
	await _solve(main, 0.8)
	check(main.board.progress_matched == 3, "la franja del tablero cuenta las parejas emparejadas")
	check(str(main.board._title_now().get("sub", "")).ends_with("3 de 3"), "el subtítulo muestra 3 de 3 parejas")
	await create_timer(2.8).timeout
	check(main.state == main.S.WIN and main.board.station == "win" and main.board.win_station.tiles.size() == 1 and main.board.win_station.labels.size() == 1 and main.board.win_station.pairs.size() == 6, "nivel completado lleva la cámara a la estación de victoria (cabecera plana, las 3 parejas con sus dos fichas y solo el botón es loseta)")
	check(main.board.win_station.title == "¡Nivel 1 completado!" and main.board.win_station.dom_count == 3, "la victoria muestra el título y las 3 parejas")
	await create_timer(1.3).timeout
	check(main.board.win_station.visible and not main.board.menu_station.visible, "al llegar solo se ve la mesa de victoria")
	var wvps: Vector2 = main.get_viewport().get_visible_rect().size
	var wfloor_ok: bool = true
	for wcorner in [Vector2.ZERO, Vector2(wvps.x, 0.0), Vector2(0.0, wvps.y), wvps]:
		var wg: Vector3 = main.board._ground_point(wcorner)
		wfloor_ok = wfloor_ok and wg.x >= FloorCubes.X_MIN and wg.x <= FloorCubes.X_MAX and wg.z >= -main.board.floor_cubes.z_far and wg.z <= main.board.floor_cubes.z_near
	check(wfloor_ok, "las cuatro esquinas de la vista de la victoria caen sobre el suelo de cubos")
	# Las listas largas (materias y álbum) también deben tener suelo en sus dos extremos de paneo
	main._go_subjects()
	await create_timer(1.3).timeout
	for zsign in [-1.0, 1.0]:
		main.board.cam_z = zsign * main.board.subject_station.pan_bounds(main.board.subject_station.fit_distance()).y
		await create_timer(0.5).timeout
		check(_view_on_floor(main), "materias: la vista cae sobre el suelo en el extremo %s" % ("superior" if zsign < 0.0 else "inferior"))
	main._go_album()
	await create_timer(1.5).timeout
	for zsign2 in [-1.0, 1.0]:
		main.board.cam_z = zsign2 * main.board.album_station.pan_bounds(main.board.album_station.fit_distance()).y
		await create_timer(0.5).timeout
		check(_view_on_floor(main), "álbum: la vista cae sobre el suelo en el extremo %s" % ("superior" if zsign2 < 0.0 else "inferior"))
	# El toque se hace con la cámara en la mesa de victoria: desde el álbum el botón
	# queda muy fuera de cuadro, el rayo sale casi paralelo al plano y no lo alcanza.
	main.board.fly_to_station("win", 0.0)
	await create_timer(0.1).timeout
	var wbtn: Plaque = main.board.win_station.tiles[0]
	var wspot: Vector2 = main.board.cam.unproject_position(wbtn.global_position)
	main.board.win_station.tap(wspot, main.board.cam)
	await process_frame
	check(Progress.level() == 2 and main.state == main.S.GAME, "tocar la loseta dorada sigue al nivel 2 sin volver a preguntar el modo")
	await process_frame
	check(Progress.level() == 2 and main.board.tiles.size() == 8 and main.board.mode == "mem", "avanza al nivel 2 (4 parejas) conservando Memoria")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Progress.path))
	check(int(saved["level"]) == 2 and (saved["mp"] as Dictionary).size() >= 3 and (saved["sr"] as Dictionary).size() >= 3, "progreso, dominio y repaso guardados en JSON")
	print("Materias (asociación)")
	main._go_subjects()
	check(main.state == main.S.SUBJECTS and main.ui.subjects.visible and main.board.subject_station.tiles.size() == 18, "pantalla de materias con 18 losetas (los rótulos de grupo son planos y no cuentan)")
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
	main._open_group("matematicas")   # Aritmética (mat) es un tema de la materia Matemáticas
	await create_timer(1.3).timeout   # vuelo a la mesa de temas (0,9 s)
	var mat_tile: Plaque = null
	for t in main.board.theme_station.tiles:
		if (t as Plaque).key == "mat":
			mat_tile = t
			break
	check(mat_tile != null and mat_tile.info.is_empty(), "la materia gratuita no muestra aviso de pago")
	if mat_tile != null:
		var mat_spot: Vector2 = main.board.cam.unproject_position(mat_tile.global_position)
		main.board.theme_station.tap(mat_spot, main.board.cam)
	check(main.state == main.S.MODE and main.cur_sid == "mat" and main.board.tiles.is_empty(), "tocar una materia gratuita abre el paso de modo")
	main._on_back()
	await process_frame
	check(main.state == main.S.SUBJECTS and main.board.station == "themes", "Atrás desde el modo vuelve a la mesa de temas de la materia")
	main._on_back()   # cierra la materia Matemáticas y deja la lista general
	await create_timer(1.3).timeout
	check(main.board.station == "subjects", "Atrás en los temas vuelve a la mesa de materias")
	# Regresión: el recorrido general entrado desde materias tiene `cur_sid == ""`,
	# pero debe volver a materias, no al menú principal.
	main._on_subject("")
	await process_frame
	check(main.state == main.S.MODE and main._mode_from == main.S.SUBJECTS,
		"el recorrido general desde materias recuerda su origen")
	main._on_back()
	await process_frame
	check(main.state == main.S.SUBJECTS and main.board.station == "subjects",
		"Atrás desde el modo vuelve a materias en el recorrido general")
	main.board.cam_z = 0.0
	await process_frame
	main._play("mat")
	await process_frame
	check(main.state == main.S.MODE, "la materia espera la elección del modo")
	var gen0: int = main.board.gen
	_choose_mode(main, "assoc")
	_choose_mode(main, "mem")   # un rebote no debe cambiar el modo ni reiniciar
	await process_frame
	check(main.state == main.S.GAME and main.cur_sid == "mat" and not main.board.tiles.is_empty() and main.board.mode == "assoc", "elegir Asociación inicia el nivel de la materia")
	check(main.board.gen == gen0 + 1, "un doble toque en el paso de modo no reinicia la partida")
	main._go_subjects()
	await create_timer(1.1).timeout
	check(is_zero_approx(main.board.cam_z), "al volver de la partida las materias quedan donde estaban")
	stiles = main.board.subject_station.tiles
	# El desplazamiento recordado puede dejar la primera loseta fuera de vista: volver arriba
	main.board.cam_z = main.board.subject_station.initial_z(main.board.subject_station.fit_distance())
	await process_frame
	var spot: Vector2 = main.board.cam.unproject_position((stiles[0] as Plaque).global_position)
	check(Pick3D.plaque(stiles, main.board.cam, spot) == stiles[0], "toque proyectado sobre una loseta de materia")
	Progress.data["mode"] = "assoc"
	main._play("qui")
	await process_frame
	check(main.state == main.S.MODE and main.cur_sid == "qui", "Química también pasa por el paso de modo")
	_choose_mode(main, "assoc")
	await process_frame
	check(main.board.tiles.size() == 6 and main.board.mode == "assoc" and main.cur_sid == "qui", "materia Química, nivel 1 (3 parejas)")
	await _solve(main, 0.05)
	await create_timer(2.8).timeout
	check(main.state == main.S.WIN, "victoria en asociación")
	main._on_next()
	await process_frame
	check(Progress.subj_level("qui") == 2 and main.board.tiles.size() == 8, "Química avanza a su nivel 2 (4 parejas)")
	var steps: Array = Levels.steps_for(main._pack("qui"))
	check(steps == [3, 4, 5, 6, 8], "niveles de Química: %s" % str(steps))
	(Progress.data["subj"] as Dictionary)["qui"] = steps.size()
	main._play("qui")
	await process_frame
	check(main.state == main.S.MODE, "el último nivel también pide el modo al empezar")
	_choose_mode(main, "assoc")
	await process_frame
	check(main.board.tiles.size() == 8 and main.board.progress_total == 8 and main.cur_last, "último nivel de la materia (8 parejas en 2 rondas de 4)")
	await _solve(main, 0.05)
	await create_timer(2.5).timeout
	check(main.board.tiles.size() == 8 and main.state == main.S.GAME and main.board.matched_pairs() == 4, "la segunda ronda empieza con 4 parejas ya hechas")
	await _solve(main, 0.05)
	await create_timer(3.5).timeout
	check(main.state == main.S.WIN, "victoria del último nivel")
	main._on_next()
	check(main.state == main.S.SUBJECTS and Progress.subj_level("qui") == steps.size() + 1, "materia completada vuelve a materias")
	main._go_subjects()
	check(main.board.subject_station.tiles.size() == 18, "materias se redibuja")
	main._on_back()
	check(main.state == main.S.MENU, "Atrás vuelve al menú")
	var p0: Dictionary = main.packs[0]
	var p0_pairs: Array = p0["pairs"]
	(Progress.data["mp"] as Dictionary)[str(p0_pairs[0]["id"])] = 3
	main._go_album()
	var total_pairs: int = 0
	for pk in main.packs:
		if Levels.is_open(pk):
			total_pairs += (pk["pairs"] as Array).size()
	var album_tiles: Array = main.board.album_station.tiles
	var up_tiles: Array = album_tiles.filter(func(t: AlbumTile) -> bool: return t.mastered)
	check(main.state == main.S.ALBUM and main.board.station == "album", "el álbum se abre como estación")
	check(album_tiles.size() == total_pairs * 2, "el álbum tiene las dos fichas de cada pareja de las materias abiertas")
	check(up_tiles.size() >= 2 and up_tiles.size() < album_tiles.size(), "solo las parejas dominadas están boca arriba")
	var vb: Vector2 = main.board.album_station.pan_bounds(main.board.album_station.fit_distance())
	check(vb.y > 0.0, "el álbum es más alto que la pantalla: se recorre con la cámara en vertical")
	main._on_album_open((up_tiles[0] as AlbumTile).pair)
	check(main.ui.fact.visible, "una pareja dominada abre su dato curioso")
	main._on_back()
	check(main.state == main.S.ALBUM and not main.ui.fact.visible, "Atrás cierra primero el dato curioso")
	main._on_back()
	check(main.state == main.S.MENU and main.board.station == "menu", "Atrás desde el álbum vuelve al menú")
	print("Resultado: %s" % ("TODO OK" if fails == 0 else "%d fallos" % fails))
	quit(0 if fails == 0 else 1)

## ¿Las cuatro esquinas de la vista (y el centro del borde superior) caen sobre el suelo de cubos?
func _view_on_floor(main: Node) -> bool:
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	var ok: bool = true
	for corner in [Vector2.ZERO, Vector2(vp.x, 0.0), Vector2(0.0, vp.y), vp, Vector2(vp.x * 0.5, 0.0)]:
		var g: Vector3 = main.board._ground_point(corner)
		ok = ok and g.x >= FloorCubes.X_MIN and g.x <= FloorCubes.X_MAX and g.z >= -main.board.floor_cubes.z_far and g.z <= main.board.floor_cubes.z_near
	return ok
