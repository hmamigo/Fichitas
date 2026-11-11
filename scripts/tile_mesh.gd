class_name TileMesh
extends RefCounted
## Mallas procedurales: losa redondeada con bisel (cuerpo metálico de la ficha) y caras planas.

## Bucle de rectángulo redondeado en el plano XZ. Devuelve [puntos(Vector2 x,z), direcciones exteriores].
static func loop(hx: float, hz: float, r: float, seg: int) -> Array:
	var pts := PackedVector2Array()
	var dirs := PackedVector2Array()
	r = clampf(r, 0.0005, minf(hx, hz))
	var centers: Array = [Vector2(hx - r, hz - r), Vector2(-hx + r, hz - r), Vector2(-hx + r, -hz + r), Vector2(hx - r, -hz + r)]
	for c in 4:
		for i in seg + 1:
			var a: float = (float(c) + float(i) / float(seg)) * PI * 0.5
			var d := Vector2(cos(a), sin(a))
			pts.append((centers[c] as Vector2) + d * r)
			dirs.append(d)
	return [pts, dirs]

## Añade un triángulo cuya cara frontal (sentido horario en Godot) coincide con `want`.
static func _tri(st: SurfaceTool, v: Array, n: Array, uv: Array, want: Vector3) -> void:
	var idx: Array = [0, 1, 2]
	if Plane(v[0], v[1], v[2]).normal.dot(want) < 0.0:
		idx = [0, 2, 1]
	for i in idx:
		st.set_normal(n[i])
		st.set_uv(uv[i])
		st.add_vertex(v[i])

## Losa de semiancho hx/hz, esquinas de radio r, grosor `thick` y bisel `bevel`.
static func slab(hx: float, hz: float, r: float, thick: float, bevel: float, nb: int = 4, seg: int = 6) -> ArrayMesh:
	var hy: float = thick * 0.5
	var prof: Array = []  # [inset, y, ángulo]
	for i in range(nb, -1, -1):
		var a: float = float(i) / float(nb) * PI * 0.5
		prof.append([bevel * (1.0 - cos(a)), -(hy - bevel) - bevel * sin(a), -a])
	for i in nb + 1:
		var a: float = float(i) / float(nb) * PI * 0.5
		prof.append([bevel * (1.0 - cos(a)), (hy - bevel) + bevel * sin(a), a])
	var rv: Array = []
	var rn: Array = []
	for p in prof:
		var inset: float = p[0]
		var y: float = p[1]
		var ang: float = p[2]
		var lp: Array = loop(hx - inset, hz - inset, r - inset, seg)
		var pts: PackedVector2Array = lp[0]
		var dirs: PackedVector2Array = lp[1]
		var vs: Array = []
		var ns: Array = []
		for k in pts.size():
			vs.append(Vector3(pts[k].x, y, pts[k].y))
			ns.append(Vector3(dirs[k].x * cos(ang), sin(ang), dirs[k].y * cos(ang)).normalized())
		rv.append(vs)
		rn.append(ns)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_pts: int = (rv[0] as Array).size()
	var z2 := Vector2.ZERO
	for j in rv.size() - 1:
		for k in n_pts:
			var k2: int = (k + 1) % n_pts
			var a: Vector3 = rv[j][k]
			var b: Vector3 = rv[j][k2]
			var c: Vector3 = rv[j + 1][k2]
			var d: Vector3 = rv[j + 1][k]
			var na: Vector3 = rn[j][k]
			var nb2: Vector3 = rn[j][k2]
			var nc: Vector3 = rn[j + 1][k2]
			var nd: Vector3 = rn[j + 1][k]
			var want: Vector3 = (na + nb2 + nc + nd).normalized()
			_tri(st, [a, b, c], [na, nb2, nc], [z2, z2, z2], want)
			_tri(st, [a, c, d], [na, nc, nd], [z2, z2, z2], want)
	# Tapas (UV en unidades de mundo, útil para texturas repetidas en el tablero)
	for cap in 2:
		var ring_row: int = rv.size() - 1 if cap == 0 else 0
		var up: Vector3 = Vector3.UP if cap == 0 else Vector3.DOWN
		var yc: float = hy if cap == 0 else -hy
		var center := Vector3(0.0, yc, 0.0)
		for k in n_pts:
			var k2: int = (k + 1) % n_pts
			var pa: Vector3 = rv[ring_row][k]
			var pb: Vector3 = rv[ring_row][k2]
			_tri(st, [center, pa, pb], [up, up, up], [Vector2.ZERO, Vector2(pa.x, pa.z), Vector2(pb.x, pb.z)], up)
	return st.commit()

## Cara plana de la imagen (rectángulo redondeado con UV 0..1) a altura y. `up` indica hacia dónde mira.
static func face(half: float, y: float, up: bool, radius: float = 0.09, seg: int = 6) -> ArrayMesh:
	var lp: Array = loop(half, half, radius, seg)
	var pts: PackedVector2Array = lp[0]
	var nrm: Vector3 = Vector3.UP if up else Vector3.DOWN
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0.0, y, 0.0)
	var size: float = half * 2.0
	for k in pts.size():
		var k2: int = (k + 1) % pts.size()
		var va := Vector3(pts[k].x, y, pts[k].y)
		var vb := Vector3(pts[k2].x, y, pts[k2].y)
		var ua: float = pts[k].x / size + 0.5
		var ub: float = pts[k2].x / size + 0.5
		if not up:
			ua = 1.0 - ua
			ub = 1.0 - ub
		_tri(st, [center, va, vb], [nrm, nrm, nrm], [Vector2(0.5, 0.5), Vector2(ua, pts[k].y / size + 0.5), Vector2(ub, pts[k2].y / size + 0.5)], nrm)
	return st.commit()

## Anillo plano en el plano XZ, para el destello al emparejar.
static func ring(inner: float, outer: float, y: float, seg: int = 48) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up := Vector3.UP
	for i in seg:
		var a0: float = TAU * float(i) / float(seg)
		var a1: float = TAU * float(i + 1) / float(seg)
		var p0 := Vector2(cos(a0), sin(a0))
		var p1 := Vector2(cos(a1), sin(a1))
		var v0 := Vector3(p0.x * inner, y, p0.y * inner)
		var v1 := Vector3(p1.x * inner, y, p1.y * inner)
		var v2 := Vector3(p1.x * outer, y, p1.y * outer)
		var v3 := Vector3(p0.x * outer, y, p0.y * outer)
		_tri(st, [v0, v1, v2], [up, up, up], [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE], up)
		_tri(st, [v0, v2, v3], [up, up, up], [Vector2.ZERO, Vector2.ONE, Vector2.DOWN], up)
	return st.commit()
