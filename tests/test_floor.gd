extends SceneTree
## Suelo de edificios: godot --headless --path . --script res://tests/test_floor.gd

var fails: int = 0

func check(ok: bool, msg: String) -> void:
	print(("  OK   " if ok else "  FALLA ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	_run()

## Cuántos edificios hay de cada tamaño (0,5 chico, 1 mediano, 2 grande).
func _count_size(fc: FloorCubes, small: bool) -> int:
	var n: int = 0
	for c in fc._cells:
		if (float((c as Dictionary)["s"]) < 0.9) == small:
			n += 1
	return n

func _run() -> void:
	var table: Array = [Rect2(-3.0, -4.0, 6.0, 8.0)]
	var full := FloorCubes.new()
	full.light = false
	root.add_child(full)
	var lite := FloorCubes.new()
	lite.light = true
	root.add_child(lite)
	await process_frame
	full.set_clears(table)
	lite.set_clears(table)

	print("Presupuesto")
	var nf: int = full.instance_count()
	var nl: int = lite.instance_count()
	check(nf <= 10500, "suelo completo: %d instancias (máximo 10 500; antes ~9 000)" % nf)
	check(nl < int(float(nf) * 0.65), "ligero: %d instancias, bastante menos que el completo (%d)" % [nl, nf])
	check(lite.instance_count() == lite._cells.size(), "ligero: sin remates")
	check(full._towers.size() > 100, "completo: hay remates (%d)" % full._towers.size())

	print("Modo ligero")
	check(_count_size(lite, true) == 0, "ligero: ningún edificio chico")
	var small_full: int = _count_size(full, true)
	check(small_full > 100, "completo: sí hay edificios chicos (%d)" % small_full)
	check(lite.mmi.multimesh.mesh is BoxMesh, "ligero: cajas simples (12 triángulos)")
	check(not (full.mmi.multimesh.mesh is BoxMesh), "completo: cubos biselados")

	print("Edificios")
	var all_drawn: bool = true
	var max_floors: int = 0
	for k in full._cells.size():
		all_drawn = all_drawn and full._floors[k] >= 1
		max_floors = maxi(max_floors, full._floors[k])
	check(all_drawn, "todos tienen al menos un piso")
	check(max_floors >= 8, "hay torres de al menos 8 pisos (máximo %d)" % max_floors)
	check(float(max_floors) * FloorCubes.FLOOR_H + FloorCubes.BASE_Y < 4.0, "ninguna torre pasa de 4 unidades sobre la mesa")
	var plaza_ok: bool = true
	var plaza_n: int = 0
	for k in full._cells.size():
		var c: Dictionary = full._cells[k]
		if absf(float(c["x"])) < 2.0 and absf(float(c["z"])) < 3.0:
			plaza_n += 1
			plaza_ok = plaza_ok and full._floors[k] == 1
	check(plaza_n > 0 and plaza_ok, "bajo la mesa todo queda de un solo piso (%d edificios)" % plaza_n)
	var shown: int = 0
	var towers_total: int = 0
	var rule_ok: bool = true
	for k in full._cells.size():
		var tw: int = int((full._cells[k] as Dictionary)["tw"])
		if tw < 0:
			continue
		towers_total += 1
		var visible: bool = full._floors[k] >= FloorCubes.TOWER_MIN_FLOORS
		shown += 1 if visible else 0
		rule_ok = rule_ok and float((full._cells[k] as Dictionary)["s"]) > 0.9
	check(towers_total == full._towers.size() and rule_ok, "los remates son de edificios no chicos (%d)" % towers_total)
	check(shown > 50, "remates visibles sobre las torres altas (%d de %d)" % [shown, towers_total])
	check(shown < towers_total, "los remates de edificios bajos se esconden (%d)" % (towers_total - shown))

	print("Distancia a las mesas")
	check(FloorCubes.TOP_MIN <= -1.0, "el suelo queda al menos 1 unidad bajo la mesa (cima más baja %.2f)" % FloorCubes.TOP_MIN)
	check(FloorCubes.GROUND_Y < FloorCubes.TOP_MIN and FloorCubes.BASE_Y < FloorCubes.GROUND_Y, "base < plano del suelo < cima más baja")
	var near_ok: bool = true
	var seen_tall: bool = false
	for k in full._cells.size():
		var c2: Dictionary = full._cells[k]
		var s2: float = c2["s"]
		var d: float = maxf(full._clear_dist(float(c2["x"]), float(c2["z"])) - maxf(s2 - 1.0, 0.0) * FloorCubes.SIDE * 0.5, 0.0)
		if d < FloorCubes.RISE_START:
			near_ok = near_ok and full._floors[k] == 1
		if d >= FloorCubes.RISE_END and full._floors[k] >= 5:
			seen_tall = true
	check(near_ok, "a menos de RISE_START de la mesa todo es bajo")
	check(seen_tall, "lejos de la mesa hay edificios altos")

	print("Cambio de modo")
	full.set_light(true)
	check(full.instance_count() == nl, "set_light(true) deja el mismo suelo que el ligero (%d)" % full.instance_count())
	check(full.mmi.multimesh.mesh is BoxMesh, "set_light(true) cambia la malla")
	full.set_light(false)
	check(full.instance_count() == nf, "set_light(false) vuelve al completo (%d)" % full.instance_count())
	var back_ok: bool = true
	for k in full._cells.size():
		back_ok = back_ok and full._floors[k] >= 1
	check(back_ok, "tras volver, todos los edificios se redibujan con altura")

	print("Elección guardada")
	Progress.data = {"light": true}
	check(Progress.light(), "light = true se respeta")
	Progress.data = {"light": false}
	check(not Progress.light(), "light = false se respeta")
	Progress.data = {"light": null}
	check(Progress.light() == (OS.get_processor_count() <= 4), "sin elección decide el equipo")
	Progress.data = {"light": true}
	var b := Board.new()
	root.add_child(b)
	await process_frame
	check(b.floor_cubes.light, "el tablero arranca con el suelo ligero si está elegido")
	var plane_ok: bool = false
	for c in b.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is PlaneMesh and absf((c as MeshInstance3D).position.y - FloorCubes.GROUND_Y) < 0.01:
			plane_ok = true
	check(plane_ok, "el plano lejano está a la altura del suelo (GROUND_Y)")

	print("Resultado: " + ("TODO OK" if fails == 0 else "%d FALLAS" % fails))
	quit(1 if fails > 0 else 0)
