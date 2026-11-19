class_name FloorCubes
extends Node3D
## Suelo de cubos de colores: un solo MultiMesh (una llamada de dibujo).
## Los cubos junto a las mesas quedan bajos y suaves; los lejanos crecen y dan profundidad.
## Hay tres tamaños (grandes de 2×2, medianos de 1×1 y chicos de ½×½) repartidos por bloques de
## 2×2 sin solaparse, así el fondo tiene ritmo y no es una cuadrícula uniforme.

const STEP := 1.0         # lado de la celda mediana
const SIDE := 0.9         # lado del cubo mediano: la rendija es el 10 % de la celda
const P_LARGE := 0.20     # probabilidad de que un bloque 2×2 sea un solo cubo grande
const P_SMALL := 0.20     # probabilidad de que una celda mediana se divida en 4 cubos chicos
# Zona alrededor de cada mesa donde los cubos se quedan bajos y pálidos, y distancia desde la que
# empiezan a crecer: cuanto mayores, más lejos de las mesas aparecen los cubos altos.
const CLEAR_MARGIN := 1.5
const RISE_START := 0.6
# Cobertura en UNIDADES DEL MUNDO. Debe cubrir lo que ve la cámara en las seis estaciones (Board:
# álbum en x = -35, menú en -25, materias en -15, modo en -9, tablero en 0, victoria en +10) también
# en sus extremos de paneo: la mesa de materias mide ~±20 en Z y la del álbum ~±26, y la vista
# llega unos 6 más allá; en pantalla apaisada o ultra ancha asoma más a los lados. Hay margen de sobra.
const X_MIN := -54        # borde izquierdo (más allá del álbum)
const X_MAX := 30         # borde derecho (más allá de la estación de victoria)
const Z_FAR := 38         # hacia el fondo (−Z)
const Z_NEAR := 38        # hacia la cámara (+Z)
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
var _grown: Array = []                # los mismos huecos con el margen ya aplicado
var _last: PackedFloat32Array = PackedFloat32Array()  # distancia con la que se dibujó cada cubo

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261112
	var j0: int = ceili(-float(Z_FAR) / STEP)
	var i0: int = ceili(float(X_MIN) / STEP)
	j0 -= posmod(j0, 2)   # los bloques de 2×2 empiezan en índices pares
	i0 -= posmod(i0, 2)
	for j in range(j0, floori(float(Z_NEAR) / STEP) + 1, 2):
		for i in range(i0, floori(float(X_MAX) / STEP) + 1, 2):
			if rng.randf() < P_LARGE:
				_add_cube(rng, float(i) + 0.5, float(j) + 0.5, 2.0)    # un cubo grande ocupa el bloque
				continue
			for dj in 2:
				for di in 2:
					if rng.randf() < P_SMALL:
						for sj in 2:
							for si in 2:   # cuatro chicos dentro de la celda
								_add_cube(rng, float(i + di) - 0.25 + 0.5 * float(si), float(j + dj) - 0.25 + 0.5 * float(sj), 0.5)
					else:
						_add_cube(rng, float(i + di), float(j + dj), 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = TileMesh.slab(SIDE * 0.5, SIDE * 0.5, 0.12, 1.0, 0.05, 1, 2)   # 96 triángulos: hay miles
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
	_last.resize(_cells.size())
	_last.fill(-1.0)
	_grow_clears()
	_rebuild()

## Un cubo de escala horizontal `s` (0,5 chico, 1 mediano, 2 grande) centrado en (x, z).
func _add_cube(rng: RandomNumberGenerator, x: float, z: float, s: float) -> void:
	var c: Color = PALETTE[rng.randi() % PALETTE.size()]
	c = c.lerp(Color.WHITE, 0.12).lightened(rng.randf_range(-0.04, 0.06))
	_cells.append({"x": x * STEP, "z": z * STEP, "s": s, "col": c, "n": rng.randf()})

## Zona libre alrededor de una mesa (semiancho y semialto, ya con el marco).
func set_clear_rect(hw: float, hh: float) -> void:
	set_clears([Rect2(-hw, -hh, hw * 2.0, hh * 2.0)])

## Huecos de todas las mesas del mundo (el tablero, las materias y el menú).
func set_clears(rects: Array) -> void:
	if mmi != null and rects == _clears:
		return
	_clears = rects
	_grow_clears()
	if mmi != null:
		_rebuild()

func _grow_clears() -> void:
	_grown.clear()
	for r in _clears:
		_grown.append((r as Rect2).grow(CLEAR_MARGIN))  # margen: los cubos altos empiezan lejos de la mesa

## Distancia de un cubo al hueco más cercano.
func _clear_dist(x: float, z: float) -> float:
	var best: float = INF
	for r in _grown:
		var rect: Rect2 = r
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
		# A partir de 7 de distancia ya no cambia ni la altura ni el color: se recorta,
		# y los cubos que no cambian respecto al último dibujo se saltan.
		var s: float = cell["s"]
		# Un cubo grande se mide desde su borde, no desde su centro; y crece más que uno chico
		var d: float = minf(maxf(_clear_dist(x, z) - maxf(s - 1.0, 0.0) * SIDE * 0.5, 0.0), 7.0)
		if absf(d - _last[k]) < 0.0001:
			continue
		_last[k] = d
		var n: float = cell["n"]
		var hmul: float = 0.8 if s < 0.9 else (1.35 if s > 1.5 else 1.0)
		var rise: float = smoothstep(RISE_START, 7.0, d) * (0.10 + MAX_RISE * n * n) * hmul
		var top: float = TOP_MIN + rise
		var h: float = top - BASE_Y
		var t := Transform3D(Basis.from_scale(Vector3(s, h, s)), Vector3(x, BASE_Y + h * 0.5, z))
		mm.set_instance_transform(k, t)
		# Más cerca de una mesa: más pálido, para que mande el color de las fichas
		var base: Color = (cell["col"] as Color).lerp(FADE_COLOR, FADE)
		var near: float = 0.25 * (1.0 - smoothstep(0.0, 3.0, d))
		var col: Color = base.lerp(Color("eef4fd"), near)
		mm.set_instance_color(k, col)
