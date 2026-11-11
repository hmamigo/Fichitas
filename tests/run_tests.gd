extends SceneTree
## Pruebas sin interfaz: godot --headless --path . --script res://tests/run_tests.gd

var fails: int = 0

func check(ok: bool, msg: String) -> void:
	print(("  OK   " if ok else "  FALLA ") + msg)
	if not ok:
		fails += 1

func _tris_ok(m: ArrayMesh) -> bool:
	var arr: Array = m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var bad: int = 0
	for i in range(0, v.size(), 3):
		var pn: Vector3 = Plane(v[i], v[i + 1], v[i + 2]).normal
		var avg: Vector3 = n[i] + n[i + 1] + n[i + 2]
		if is_nan(pn.x) or pn.length() < 0.5:
			continue  # triángulo degenerado
		if pn.dot(avg) <= 0.0:
			bad += 1
	return bad == 0

func _init() -> void:
	print("Malla de ficha")
	var m: ArrayMesh = TileMesh.slab(0.49, 0.49, 0.16, 0.13, 0.03)
	var bb: AABB = m.get_aabb()
	check(absf(bb.size.x - 0.98) < 0.01 and absf(bb.size.z - 0.98) < 0.01, "ancho 0.98 (%s)" % bb.size)
	check(absf(bb.size.y - 0.13) < 0.005, "grosor 0.13")
	check(_tris_ok(m), "caras frontales coinciden con las normales")
	var f: ArrayMesh = TileMesh.face(0.41, 0.0685, true)
	var uv: PackedVector2Array = f.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var ok_uv: bool = true
	for u in uv:
		if u.x < -0.001 or u.x > 1.001 or u.y < -0.001 or u.y > 1.001:
			ok_uv = false
	check(ok_uv and _tris_ok(f), "cara con UV en 0..1 y orientación correcta")
	var fd: ArrayMesh = TileMesh.face(0.41, -0.0685, false)
	check(_tris_ok(fd), "dorso orientado hacia abajo")
	print("Paquetes")
	var packs: Array = Packs.load_all()
	var total: int = 0
	var tex_ok: bool = true
	for p in packs:
		total += (p["pairs"] as Array).size()
		for pr in p["pairs"]:
			if not (pr["a"] is Texture2D) or (pr["a"] as Texture2D).get_width() != 512:
				tex_ok = false
	check(packs.size() == 8, "8 paquetes (%d)" % packs.size())
	check(total == 70, "70 parejas (%d)" % total)
	check(tex_ok, "texturas 512x512 cargadas")
	print("Resultado: %s" % ("TODO OK" if fails == 0 else "%d fallos" % fails))
	quit(0 if fails == 0 else 1)
