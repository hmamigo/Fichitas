extends SceneTree
## Materias con temas: godot --headless --path . --script res://tests/test_groups.gd

var fails: int = 0

func check(ok: bool, msg: String) -> void:
	print(("  OK   " if ok else "  FALLA ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	_run()

func _keys(main: Node) -> Array:
	var out: Array = []
	for t in main.board.subject_station.tiles:
		out.append((t as Plaque).key)
	return out

func _run() -> void:
	print("Datos")
	var groups: Array = [
		{"id": "gm", "name": "Mates", "icon": "paquete", "category": "nerds", "color": ""},
		{"id": "gx", "name": "Otra", "icon": "paquete", "category": "exploradores", "color": "ff8800"},
	]
	var packs: Array = [
		{"id": "d", "name": "D", "category": "peques", "group": "zzz"},
		{"id": "a", "name": "A", "category": "exploradores", "group": ""},
		{"id": "b", "name": "B", "category": "nerds", "group": "gm"},
		{"id": "c", "name": "C", "category": "exploradores", "group": "gm"},
		{"id": "e", "name": "E", "category": "nerds"},
	]
	Packs.apply_groups(packs, groups)
	check(packs[0]["group"] == "", "una materia desconocida se ignora: el paquete queda suelto")
	check(packs[2]["group"] == "gm" and packs[3]["group"] == "gm", "los temas guardan su materia")
	check(packs[3]["category"] == "nerds", "un tema toma la categoría de su materia")
	check(Packs.valid_group("gm", groups) == "gm" and Packs.valid_group("nada", groups) == "", "valid_group")
	var top: Array = Packs.top_level(packs, groups)
	check(top.size() == 4, "5 paquetes con 2 de una materia -> 4 entradas (%d)" % top.size())
	check(top[2].has("group") and (top[2]["packs"] as Array).size() == 2 and top[2]["group"]["id"] == "gm", "la materia agrupa a sus dos temas, donde aparece el primero")
	check(top[0].has("pack") and top[1].has("pack") and top[3].has("pack"), "los demás van sueltos, en su orden")
	check(UiTheme.has_icon("book") and not UiTheme.has_icon("nada_de_esto"), "has_icon distingue un icono que existe de uno que no")
	var real: Array = Packs.load_groups()
	check(real is Array, "packs/groups.json se lee (%d materias)" % real.size())
	var loose: bool = true
	for p in Packs.load_all():
		loose = loose and (str(p["group"]) == "" or not Packs.group_by_id(real, str(p["group"])).is_empty())
	check(loose, "todos los paquetes oficiales apuntan a una materia que existe (o a ninguna)")

	print("Navegación")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 6:
		await process_frame
	main._go_subjects()
	await create_timer(1.1).timeout
	var n0: int = main.board.subject_station.tiles.size()
	var keys0: Array = _keys(main)
	check(keys0.has("ing") and keys0.has("geo"), "sin materias, 'ing' y 'geo' son tarjetas sueltas")
	# Se agrupan dos materias oficiales de Exploradores en una materia de prueba
	main.groups.append({"id": "gt", "name": "Prueba", "icon": "paquete", "category": "exploradores", "color": ""})   # además de las oficiales
	for p in main.packs:
		if p["id"] == "ing" or p["id"] == "geo":
			p["group"] = "gt"
	Packs.apply_groups(main.packs, main.groups)
	main._go_subjects()
	await create_timer(0.3).timeout
	var keys1: Array = _keys(main)
	check(keys1.size() == n0 - 1 and keys1.has("grp:gt") and not keys1.has("ing") and not keys1.has("geo"), "la lista muestra la materia en vez de sus temas (%d -> %d tarjetas)" % [n0, keys1.size()])
	check(main.ui.subjects_back_label.text == "Menú", "en la lista general el botón dice Menú")
	var kids: Array = []
	for p in main.packs:
		if p["group"] == "gt":
			kids.append(p)
	var card: Dictionary = main._group_card(Packs.group_by_id(main.groups, "gt"), kids)
	check(card["id"] == "grp:gt" and card["sub"] == "2 temas" and not bool(card["locked"]) and str(card["sub2"]).begins_with("Dominadas 0 de"), "la tarjeta de la materia suma sus temas: %s · %s" % [card["sub"], card["sub2"]])

	main.board.cam_z = 1.5
	await process_frame
	main._open_group("gt")
	await create_timer(1.2).timeout   # el vuelo a la derecha dura 0,9 s
	check(main.board.station == "themes" and main.board.theme_station.visible and not main.board.subject_station.visible, "la cámara pasa a la mesa de los temas y la de materias se oculta al llegar")
	check(main.board.theme_station.position.x > main.board.subject_station.position.x and main.board.theme_station.position.x < main.board.mode_station.position.x, "los temas quedan a la derecha de las materias y a la izquierda del modo")
	check(main.board.cam.global_position.x > main.board.subject_station.position.x + 3.0, "la cámara se movió hacia la derecha")
	var tiles_in: Array = []
	for tl in main.board.theme_station.tiles:
		tiles_in.append((tl as Plaque).key)
	check(tiles_in.size() == 2 and tiles_in.has("ing") and tiles_in.has("geo"), "la mesa de temas muestra solo sus temas %s" % str(tiles_in))
	check(main.state == main.S.SUBJECTS and main.ui.subjects_back_label.text == "Materias", "el botón de volver dice Materias")
	check(main.board.cam_z < 1.5, "la lista de temas empieza por arriba")
	main.board.cam_z = 0.9   # se desplaza un poco la lista de temas...

	main._play("ing")
	await create_timer(1.3).timeout
	check(main.state == main.S.MODE, "un tema se juega como cualquier materia (paso de modo)")
	main._on_back()
	await create_timer(0.8).timeout
	check(main.state == main.S.SUBJECTS and main._group_open == "gt" and main.board.station == "themes" and main.board.theme_station.tiles.size() == 2, "volver del modo deja la mesa de temas")

	main._on_back()
	await create_timer(1.1).timeout   # el vuelo de regreso a la izquierda
	check(main._group_open == "" and main.board.station == "subjects" and _keys(main).size() == keys1.size(), "Atrás en los temas vuelve a la lista general, a la izquierda")
	check(is_equal_approx(main.board.cam_z, 1.5) and main.ui.subjects_back_label.text == "Menú", "y la lista general queda donde estaba (z=%.2f)" % main.board.cam_z)
	main._on_back()
	await create_timer(1.0).timeout
	check(main.state == main.S.MENU, "Atrás en la lista general vuelve al menú")

	main._go_subjects()
	await create_timer(0.8).timeout
	main._open_group("gt")
	await create_timer(0.3).timeout
	main._go_menu()
	await create_timer(0.8).timeout
	check(main._group_open == "", "salir al menú cierra la materia")
	main._go_subjects()
	await create_timer(0.8).timeout
	check(_keys(main).size() == keys1.size(), "al volver a Materias se ve la lista general")

	print("Resultado: " + ("TODO OK" if fails == 0 else "%d FALLAS" % fails))
	quit(1 if fails > 0 else 0)