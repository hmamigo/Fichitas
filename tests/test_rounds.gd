extends SceneTree
## Rondas, 2 columnas y desplazamiento vertical del tablero:
## godot --headless --path . --script res://tests/test_rounds.gd

var fails: int = 0

func check(ok: bool, msg: String) -> void:
	print(("  OK   " if ok else "  FALLA ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	_run()

func _pairs(n: int) -> Array:
	var out: Array = []
	var tex := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	for i in n:
		out.append({"id": "p%d" % i, "a": tex, "b": tex})
	return out

func _of(b: Board, id: String) -> Array:
	var out: Array = []
	for t in b.tiles:
		if t.pair == id:
			out.append(t)
	return out

## Resuelve todas las parejas de la ronda en curso.
func _solve_round(b: Board) -> void:
	var ids: Array = []
	for t in b.tiles:
		if not ids.has(t.pair):
			ids.append(t.pair)
	for id in ids:
		var pr: Array = _of(b, id)
		b._resolve_ok(pr[0], pr[1])

func _run() -> void:
	print("Reparto en rondas")
	var cases: Dictionary = {3: [3], 5: [5], 6: [6], 7: [4, 3], 8: [4, 4], 10: [5, 5], 12: [6, 6], 14: [5, 5, 4], 16: [6, 5, 5], 18: [6, 6, 6], 20: [5, 5, 5, 5], 24: [6, 6, 6, 6]}
	for n in cases:
		var got: Array = Levels.round_sizes(int(n))
		check(got == cases[n], "%d parejas -> %s" % [n, str(got)])
	var all_ok: bool = true
	for n in range(1, 60):
		var sizes: Array = Levels.round_sizes(n)
		var sum: int = 0
		for x in sizes:
			sum += int(x)
			all_ok = all_ok and int(x) <= Levels.ROUND_PAIRS and int(x) >= 1
		all_ok = all_ok and sum == n
	check(all_ok and Levels.round_sizes(0).is_empty(), "de 1 a 59 parejas: suman bien y ninguna ronda pasa de %d" % Levels.ROUND_PAIRS)

	var b := Board.new()
	root.add_child(b)
	await process_frame
	var won: Array = []
	b.won.connect(func() -> void: won.append(1))

	print("Tablero")
	b.start(_pairs(14))
	await process_frame
	check(b.cols == 2 and b.rows == 5 and b.tiles.size() == 10, "ronda 1 de 14 parejas: 10 fichas en 2 columnas (%dx%d)" % [b.cols, b.rows])
	check(b.progress_total == 14 and b._rounds.size() == 3, "el nivel tiene 14 parejas en 3 rondas")
	check(not b.has_method("_begin_drag") and not b.has_method("_drop"), "ya no se arrastran las fichas")

	print("Desplazamiento")
	b.start(_pairs(12))
	await process_frame
	var bd: Vector2 = b._pan_bounds(b.fit)
	check(bd.x == 0.0, "con el ancho completo no hay desplazamiento horizontal")
	check(bd.y > 0.0 and is_equal_approx(b.cam_z, -bd.y), "6 filas: hay recorrido vertical y empieza por arriba (%.2f)" % b.cam_z)
	b.zoom = 3.0   # el viewport de pruebas es cuadrado: a 2× el ancho todavía cabe entero
	check(b._pan_bounds(b.fit / b.zoom).x > 0.0, "con mucho zoom sí se puede mover a los lados")
	b.zoom = 1.0

	print("Rondas")
	var local := Board.new()
	root.add_child(local)
	await process_frame
	var w2: Array = []
	var pd: Array = []
	local.won.connect(func() -> void: w2.append(1))
	local.pair_done.connect(func(id: String, clean: bool) -> void: pd.append(id))
	local.start(_pairs(14))
	await process_frame
	_solve_round(local)
	check(local.matched_pairs() == 5 and w2.is_empty(), "ronda 1 terminada: 5 parejas, sin victoria todavía")
	await create_timer(2.4).timeout
	check(local._round == 1 and local.tiles.size() == 10 and w2.is_empty(), "pasa a la ronda 2 con fichas nuevas (%d)" % local.tiles.size())
	check(local.matched_pairs() == 5 and local.progress_total == 14, "el contador conserva las 5 parejas hechas (%d de %d)" % [local.matched_pairs(), local.progress_total])
	check(not local.tiles[0].matched, "las fichas de la ronda 2 están sin resolver")
	_solve_round(local)
	await create_timer(2.4).timeout
	check(local._round == 2 and local.tiles.size() == 8 and w2.is_empty(), "ronda 3: 8 fichas")
	check(local.matched_pairs() == 10, "van 10 parejas (%d)" % local.matched_pairs())
	_solve_round(local)
	check(local.matched_pairs() == 14, "al terminar la última, 14 parejas (%d)" % local.matched_pairs())
	await create_timer(2.4).timeout
	check(w2.size() == 1, "'won' se emite una sola vez, al final del nivel")
	var uniq: Dictionary = {}
	for id in pd:
		uniq[id] = true
	check(pd.size() == 14 and uniq.size() == 14, "pair_done avisó de las 14 parejas, una vez cada una")

	print("Resultado: " + ("TODO OK" if fails == 0 else "%d FALLAS" % fails))
	quit(1 if fails > 0 else 0)
