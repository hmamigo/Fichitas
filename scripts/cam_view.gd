class_name CamView
extends RefCounted
## Geometría de la vista de la cámara: cuánto mundo cabe en pantalla a una
## distancia dada y, al revés, a qué distancia hay que ponerla para que algo quepa.
## Si todavía no hay viewport o cámara (pruebas sin pantalla) usa valores de celular vertical.

const DEFAULT_ASPECT := 0.5625   # 9:16
const DEFAULT_FOV := 35.0

## (relación de aspecto, tan(fov/2)) del viewport y la cámara activa.
static func _lens(vp: Viewport) -> Vector2:
	var ar: float = DEFAULT_ASPECT
	var fov: float = DEFAULT_FOV
	if vp != null:
		var r: Vector2 = vp.get_visible_rect().size
		ar = r.x / maxf(r.y, 1.0)
		var cam: Camera3D = vp.get_camera_3d()
		if cam != null:
			fov = cam.fov
	return Vector2(ar, tan(deg_to_rad(fov * 0.5)))

## Ancho y alto del mundo que se ven sobre el plano de mira a la distancia `dist`.
static func visible_size(vp: Viewport, dist: float) -> Vector2:
	var lens: Vector2 = _lens(vp)
	var h: float = 2.0 * dist * lens.y
	return Vector2(h * lens.x, h)

## Distancia mínima a la que `size` (ancho, alto en unidades del mundo) cabe entera.
static func distance_for(vp: Viewport, size: Vector2) -> float:
	var lens: Vector2 = _lens(vp)
	return maxf(size.x / (2.0 * lens.y * lens.x), size.y / (2.0 * lens.y))
