extends SceneTree
## Suelo de cubos: godot --headless --path . --script res://tests/test_floor.gd
## (en headless Godot no guarda las transformaciones del MultiMesh: se prueban los datos propios del
## suelo, `_cells` y `_heights`; el aspecto se revisa con capturas)

const TABLE_BOTTOM := -0.325   # parte baja del marco de una mesa (TileLook.table)

var fails: int = 0

func check(ok: bool, msg: String) -> void:
	print(("  OK   " if ok else "  FALLA ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	_run()

## Distancia de un cubo a la mesa, medida como en el suelo.
func _dist(fc: FloorCubes, c: Dictionary) -> float:
	var s: float = c["s"]
	return minf(maxf(fc._clear_dist(float(c["x"]), float(c["z"])) - maxf(s - 1.0, 0.0) * FloorCubes.SIDE * 0.5, 0.0), FloorCubes.RISE_END)

func _run() -> void:
	var fc := FloorCubes.new()
	root.add_child(fc)
	await process_frame
	fc.set_clears([Rect2(-3.0, -4.0, 6.0, 8.0)])

	print("Presupuesto")
	var n: int = fc.instance_count()
	check(n >= 3000 and n <= 6500, "%d cubos (cajas de 12 triángulos; antes ~9 000 con 96 triángulos)" % n)
	check(fc.mmi.multimesh.mesh is BoxMesh, "cajas simples")
	var sizes: Dictionary = {}
	for c in fc._cells:
		sizes[float((c as Dictionary)["s"])] = true
	check(sizes.size() == 2 and sizes.has(1.0) and sizes.has(2.0), "solo cubos medianos y grandes (sin chicos)")

	print("Profundidad")
	var near_min: float = INF
	var near_max: float = -INF
	var near_n: int = 0
	var far_max: float = 0.0
	var near_top_max: float = -INF
	var all_ok: bool = true
	for k in fc._cells.size():
		var c2: Dictionary = fc._cells[k]
		var h: float = fc._heights[k]
		all_ok = all_ok and h >= FloorCubes.TOP_MIN - FloorCubes.BASE_Y - 0.0001
		var d: float = _dist(fc, c2)
		if d < FloorCubes.RISE_START:
			near_n += 1
			near_min = minf(near_min, h)
			near_max = maxf(near_max, h)
			near_top_max = maxf(near_top_max, FloorCubes.BASE_Y + h)
		if d >= FloorCubes.RISE_END:
			far_max = maxf(far_max, h)
	check(all_ok, "todos tienen al menos el grosor mínimo")
	check(near_n > 50, "hay cubos pegados a la mesa (%d)" % near_n)
	check(near_max - near_min >= 0.5, "pegados a la mesa ya hay relieve: alturas de %.2f a %.2f" % [near_min, near_max])
	check(near_top_max < TABLE_BOTTOM - 0.25, "ninguno toca la mesa: la cima más alta (%.2f) queda al menos 0,25 bajo ella (%.2f)" % [near_top_max, TABLE_BOTTOM])
	check(far_max >= 2.5, "lejos de la mesa hay cubos mucho más profundos (hasta %.2f)" % far_max)
	var distinct: Dictionary = {}
	for k in fc._cells.size():
		if _dist(fc, fc._cells[k]) < FloorCubes.RISE_START:
			distinct[snappedf(fc._heights[k], 0.1)] = true
	check(distinct.size() >= 6, "pegados a la mesa hay variedad de alturas (%d niveles)" % distinct.size())

	print("Distancia a las mesas")
	check(FloorCubes.TOP_MIN <= -1.0, "el suelo queda al menos 1 unidad bajo la mesa (cima más baja %.2f)" % FloorCubes.TOP_MIN)
	check(FloorCubes.GROUND_Y < FloorCubes.TOP_MIN and FloorCubes.BASE_Y < FloorCubes.GROUND_Y, "base < plano del suelo < cima más baja")

	print("Tablero")
	var b := Board.new()
	root.add_child(b)
	await process_frame
	var plane_ok: bool = false
	for c3 in b.get_children():
		if c3 is MeshInstance3D and (c3 as MeshInstance3D).mesh is PlaneMesh and absf((c3 as MeshInstance3D).position.y - FloorCubes.GROUND_Y) < 0.01:
			plane_ok = true
	check(plane_ok, "el plano lejano está a la altura del suelo (GROUND_Y)")

	print("Resultado: " + ("TODO OK" if fails == 0 else "%d FALLAS" % fails))
	quit(1 if fails > 0 else 0)
