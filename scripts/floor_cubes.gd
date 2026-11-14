class_name FloorCubes
extends Node3D
## Suelo de cubos de colores: un solo MultiMesh (una llamada de dibujo).
## Los cubos junto al tablero quedan bajos y suaves; los lejanos crecen y dan profundidad.

const STEP := 1.0
const SIDE := 0.9
# Debe cubrir las tres estaciones (Board: menú en x = -20, materias en -10, tablero en 0)
# con ~12 de margen a cada lado, que es lo que ve una pantalla apaisada 16:9.
const X_MIN := -32        # primera columna (izquierda del menú)
const X_MAX := 12         # última columna (derecha del tablero)
const Z_FAR := 18         # filas hacia el fondo (−Z)
const Z_NEAR := 16        # filas hacia la cámara (+Z): la lista de materias mide ±10 en Z
const TOP_MIN := -0.43    # cima más baja: justo sobre el suelo base
const BASE_Y := -0.60     # base de todos los cubos
const MAX_RISE := 1.1     # altura máxima de los cubos lejanos (más bajos = el fondo se aleja)
# Perspectiva atmosférica: todos los cubos se mezclan con el color de la niebla del tablero
# (Board.FOG_COLOR), así el fondo no compite con los colores de las fichas. 0 = sin mezcla.
const FADE_COLOR := Color("b9d2ee")
const FADE := 0.35
const PALETTE: Array[Color] = [
	Color("ffc629"), Color("42cd84"), Color("4a8ff5"), Color("ff7a6b"),
	Color("a98bff"), Color("ff9ac8"), Color("49c7d6"), Color("ffa63d"),
]

var mmi: MultiMeshInstance3D
var _cells: Array = []   # {x, z, col: Color, n: float}
var _clears: Array = [Rect2(-2.0, -3.0, 4.0, 6.0)]  # huecos en XZ (uno por mesa)

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261112
	for j in range(-Z_FAR, Z_NEAR + 1):
		for i in range(X_MIN, X_MAX + 1):
			var c: Color = PALETTE[rng.randi() % PALETTE.size()]
			c = c.lerp(Color.WHITE, 0.12).lightened(rng.randf_range(-0.04, 0.06))
			_cells.append({"x": float(i) * STEP, "z": float(j) * STEP, "col": c, "n": rng.randf()})
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = TileMesh.slab(SIDE * 0.5, SIDE * 0.5, 0.12, 1.0, 0.05, 2, 3)
	mm.instance_count = _cells.size()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.55
	mat.metallic = 0.0
	mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var box_pos := Vector3(X_MIN - 1, -2, -Z_FAR - 1)
	var box_size := Vector3(X_MAX - X_MIN + 2, 8, Z_FAR + Z_NEAR + 2)
	mmi.custom_aabb = AABB(box_pos, box_size)
	add_child(mmi)
	_rebuild()

## Zona libre alrededor de una mesa (semiancho y semialto, ya con el marco).
func set_clear_rect(hw: float, hh: float) -> void:
	set_clears([Rect2(-hw, -hh, hw * 2.0, hh * 2.0)])

## Huecos de todas las mesas del mundo (el tablero, las materias y el menú).
func set_clears(rects: Array) -> void:
	_clears = rects
	if mmi != null:
		_rebuild()

## Distancia de un cubo al hueco más cercano.
func _clear_dist(x: float, z: float) -> float:
	var best: float = INF
	for r in _clears:
		var rect: Rect2 = (r as Rect2).grow(0.7)  # margen extra: que ningún cubo asome en el borde
		var dx: float = maxf(maxf(rect.position.x - x, 0.0), x - rect.end.x)
		var dz: float = maxf(maxf(rect.position.y - z, 0.0), z - rect.end.y)
		best = minf(best, Vector2(dx, dz).length())
	return 0.0 if best == INF else best

func _rebuild() -> void:
	var mm: MultiMesh = mmi.multimesh
	for k in _cells.size():
		var cell: Dictionary = _cells[k]
		var x: float = cell["x"]
		var z: float = cell["z"]
		var d: float = _clear_dist(x, z)
		var n: float = cell["n"]
		var rise: float = smoothstep(0.2, 7.0, d) * (0.10 + MAX_RISE * n * n)
		var top: float = TOP_MIN + rise
		var h: float = top - BASE_Y
		var t := Transform3D(Basis.from_scale(Vector3(1.0, h, 1.0)), Vector3(x, BASE_Y + h * 0.5, z))
		mm.set_instance_transform(k, t)
		# Más cerca de una mesa: más pálido, para que mande el color de las fichas
		var base: Color = (cell["col"] as Color).lerp(FADE_COLOR, FADE)
		var near: float = 0.25 * (1.0 - smoothstep(0.0, 3.0, d))
		var col: Color = base.lerp(Color("eef4fd"), near)
		mm.set_instance_color(k, col)
