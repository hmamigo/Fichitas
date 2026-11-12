extends SceneTree
## Tablero: godot --headless --path . --script res://tests/test_game.gd

var fails: int = 0

func check(ok: bool, msg: String) -> void:
	print(("  OK   " if ok else "  FALLA ") + msg)
	if not ok:
		fails += 1

func _pairs(n: int) -> Array:
	var all: Array = []
	for p in Packs.load_all():
		all.append_array(p["pairs"])
	all.shuffle()
	return all.slice(0, n)

func _of(b: Board, id: String) -> Array:
	var out: Array = []
	for t in b.tiles:
		if t.pair == id:
			out.append(t)
	return out

func _init() -> void:
	_run()

func _run() -> void:
	var b := Board.new()
	root.add_child(b)
	await process_frame
	var done: Array = []
	var won: Array = []
	b.pair_done.connect(func(id: String, clean: bool) -> void: done.append([id, clean]))
	b.won.connect(func() -> void: won.append(1))
	print("Modo memoria")
	b.mode = "mem"
	b.start(_pairs(6))
	for i in 3:
		await process_frame
	check(b.tiles.size() == 12 and b.cols * b.rows >= 12, "12 fichas en %dx%d" % [b.cols, b.rows])
	var all_down: bool = true
	for t in b.tiles:
		if t.up:
			all_down = false
	check(all_down, "todas boca abajo")
	var ids: Array = []
	for t in b.tiles:
		if not ids.has(t.pair):
			ids.append(t.pair)
	var P: Array = _of(b, ids[0])
	var Q: Array = _of(b, ids[1])
	b._tap(P[0])
	await create_timer(0.1).timeout
	b._tap(Q[0])
	await create_timer(0.8).timeout
	check(P[0].up and Q[0].up and b.lock, "pareja errónea visible y bloquea")
	await create_timer(1.0).timeout
	check(not P[0].up and not Q[0].up and not b.lock, "pareja errónea se voltea")
	b._tap(P[1])
	await create_timer(0.1).timeout
	b._tap(Q[1])
	await create_timer(1.9).timeout
	b._tap(P[0])
	await create_timer(0.1).timeout
	b._tap(P[1])
	await create_timer(0.8).timeout
	check(P[0].matched and P[1].matched, "pareja correcta queda resuelta")
	check(P[0].body_mat.albedo_color != Color("e9b949") and Q[0].body_mat.albedo_color == Color("e9b949"), "resuelta se ve distinta de la pendiente")
	check(is_equal_approx(P[0].node.position.y, Board.MATCH_Y) and is_equal_approx(Q[0].node.position.y, Board.REST_Y) and Board.MATCH_Y < Board.REST_Y, "resueltas más cerca del suelo que las pendientes")
	check(P[0].face_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and P[0].face_mat.albedo_color.a < 1.0 and Q[0].face_mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "resueltas un poco translúcidas y pendientes opacas")
	check(done.size() == 1 and done[0][0] == ids[0] and done[0][1] == false, "pareja con error previo no cuenta como limpia")
	b._tap(Q[0])
	await create_timer(0.1).timeout
	b._tap(Q[1])
	await create_timer(0.8).timeout
	check(done.size() == 2 and done[1][1] == true, "pareja sin error cuenta como limpia")
	print("Cámara")
	var x0: float = b.cam_x
	b._pan(Vector2(100, 0))
	check(not is_equal_approx(b.cam_x, x0), "paneo")
	b._zoom_by(2.0)
	check(is_equal_approx(b.zoom, 2.0), "zoom x2")
	print("Modo asociación")
	done.clear()
	b.mode = "assoc"
	b.start(_pairs(6))
	for i in 5:
		await process_frame
	var all_up: bool = true
	for t in b.tiles:
		if not t.up:
			all_up = false
	check(all_up, "todas visibles")
	ids.clear()
	for t in b.tiles:
		if not ids.has(t.pair):
			ids.append(t.pair)
	var A: Array = _of(b, ids[0])
	var B: Array = _of(b, ids[1])
	b._tap(A[0])
	check(b.sel == A[0], "tocar selecciona")
	b._tap(B[0])
	await create_timer(0.3).timeout
	check(not A[0].matched and not B[0].matched and b.sel == null, "pareja errónea no se resuelve")
	b._tap(A[0])
	b._tap(A[1])
	check(A[0].matched and A[1].matched and done.size() == 1 and done[0][1] == false, "pareja correcta (con error previo) se resuelve")
	b._begin_drag(B[0])
	b._drop(B[0], b.cam.unproject_position(B[1].home))
	check(B[0].matched and B[1].matched and done.size() == 2 and done[1][1] == true, "arrastrar una ficha sobre su pareja")
	var C: Array = _of(b, ids[2])
	var D: Array = _of(b, ids[3])
	b._begin_drag(C[0])
	b._drop(C[0], b.cam.unproject_position(D[0].home))
	check(not C[0].matched and not D[0].matched, "arrastrar sobre otra ficha no resuelve")
	b._tap(C[0])
	b._tap(C[1])
	for k in [3, 4, 5]:
		var pr: Array = _of(b, ids[k])
		b._tap(pr[0])
		b._tap(pr[1])
	for t in b.tiles:
		if not t.matched:
			b._tap(t)
	for i in 3:
		await process_frame
	var all_m: bool = true
	for t in b.tiles:
		if not t.matched:
			all_m = false
	check(all_m, "todas resueltas")
	await create_timer(3.0).timeout
	check(won.size() == 1, "emite 'won' una vez")
	b.start(_pairs(24))
	await process_frame
	check(b.tiles.size() == 48, "nivel de 24 parejas = 48 fichas")
	print("Chispas")
	b.start(_pairs(3))
	for i in 3:
		await process_frame
	var ids2: Array = []
	for t in b.tiles:
		if not ids2.has(t.pair):
			ids2.append(t.pair)
	var S: Array = _of(b, ids2[0])
	b._resolve_ok(S[0], S[1])
	var sparks: Array = []
	for t in S:
		for c in t.node.get_children():
			if c is CPUParticles3D:
				sparks.append(c)
	check(sparks.size() == 2 and (sparks[0] as CPUParticles3D).emitting, "cada ficha emparejada suelta chispas (%d)" % sparks.size())
	check((sparks[0] as CPUParticles3D).amount == Board.SPARK_AMOUNT and (sparks[0] as CPUParticles3D).mesh != null and (sparks[0] as CPUParticles3D).color_ramp != null, "las chispas llevan malla y color")
	await create_timer(1.2).timeout
	var left: int = 0
	for t in S:
		for c in t.node.get_children():
			if c is CPUParticles3D:
				left += 1
	check(left == 0, "las chispas se limpian solas")
	print("Resultado: %s" % ("TODO OK" if fails == 0 else "%d fallos" % fails))
	quit(0 if fails == 0 else 1)
