class_name Pick3D
extends RefCounted
## Toques sobre piezas planas del mundo: se lanza un rayo desde la cámara y se
## corta con el plano de la mesa. No hacen falta cuerpos de colisión.

## Punto del plano y = 0 bajo el píxel `pos`.
static func ground(cam: Camera3D, pos: Vector2) -> Vector3:
	var o: Vector3 = cam.project_ray_origin(pos)
	var d: Vector3 = cam.project_ray_normal(pos)
	if absf(d.y) < 0.0001:
		return Vector3(INF, 0.0, INF)
	return o + d * (-o.y / d.y)

## Loseta bajo `pos` (la más cercana al rayo si se solapan), o null.
static func plaque(items: Array, cam: Camera3D, pos: Vector2) -> Plaque:
	var g: Vector3 = ground(cam, pos)
	var best: Plaque = null
	var best_d: float = INF
	for it in items:
		var t: Plaque = it
		var dx: float = absf(g.x - t.global_position.x)
		var dz: float = absf(g.z - t.global_position.z)
		if dx <= t.size.x * 0.5 and dz <= t.size.y * 0.5:
			if dx + dz < best_d:
				best_d = dx + dz
				best = t
	return best