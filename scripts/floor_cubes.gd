class_name FloorCubes
extends Node3D
## Suelo de cubos de colores y distintas profundidades: un solo MultiMesh (una llamada de dibujo).
## Hay dos tamaños (grandes de 2×2 y medianos de 1×1) repartidos por bloques de 2×2 sin solaparse,
## así el fondo tiene ritmo y no es una cuadrícula uniforme. Cada cubo tiene su propia altura:
## pegado a las mesas varían poco y siempre quedan por debajo de ellas; lejos se levantan más.
## Los cubos son cajas simples (12 triángulos): ~5 000 instancias, aptas para móviles antiguos.

const STEP := 1.0         # lado de la celda mediana
const SIDE := 0.9         # lado del cubo mediano: la rendija es el 10 % de la celda
const P_LARGE := 0.30     # probabilidad de que un bloque 2×2 sea un solo cubo grande
# Distancia vertical entre las mesas y el suelo: los cubos apoyan SINK más abajo que las mesas,
# así las mesas se ven flotando sobre el fondo.
const SINK := 4 # 1.9
const GROUND_Y := -0.455 - SINK   # plano del suelo (Board dibuja ahí el plano lejano)
const BASE_Y := -0.60 - SINK      # base de todos los cubos
const TOP_MIN := -0.43 - SINK     # cima más baja: justo sobre el plano del suelo
# Profundidad. La altura de un cubo es TOP_MIN - BASE_Y + (NEAR_RISE + FAR_RISE · lejanía) · n,
# con n = u^DEPTH_POW (u al azar en 0-1: muchos cubos bajos y pocos altos). NEAR_RISE es lo que
# varían los cubos pegados a la mesa: con el tablero casi cenital solo se ve esa franja, así que
# tiene que haber relieve ya ahí, pero la cima más alta (TOP_MIN + NEAR_RISE·1,35) queda bajo la mesa.
const NEAR_RISE := 0.80
const FAR_RISE := 2.2     # lo que se suma, lejos de la mesa, a los cubos más profundos
const DEPTH_POW := 1.6
const RISE_START := 1.2   # distancia a la mesa desde la que empieza a crecer FAR_RISE
const RISE_END := 7.0     # a partir de esta distancia ya no cambia ni la altura ni el color
const CLEAR_MARGIN := 0.4 # margen de las mesas (el hueco real de cada una más este margen)
# Cobertura en UNIDADES DEL MUNDO. Debe cubrir lo que ve la cámara en las seis estaciones (Board:
# álbum en x = -35, menú en -25, materias en -15, modo en -9, tablero en 0, victoria en +10) también
# en sus extremos de paneo: la mesa de materias mide ~±20 en Z y la del álbum ~±26, y la vista
# llega unos 6 más allá; en pantalla apaisada o ultra ancha asoma más a los lados. Hay margen de sobra.
const X_MIN := -54        # borde izquierdo (más allá del álbum)
const X_MAX := 30         # borde derecho (más allá de la estación de victoria)
const Z_FAR := 38         # hacia el fondo (−Z)
const Z_NEAR := 38        # hacia la cámara (+Z)
# Perspectiva atmosférica: todos los cubos se mezclan con el color de la niebla del tablero
# (Board.FOG_COLOR), así el fondo no compite con los colores de las fichas. 0 = sin mezcla.
const FADE_COLOR := Color("b9d2ee")
const FADE := 0.50
const NEAR_PALE := 0.18   # junto a la mesa, un poco más pálidos (mandan los colores de las fichas)
const TALL_LIGHT := 0.22  # cuanto más alto, más claro: así la profundidad también se ve desde arriba
const SEED := 20261112
const PALETTE: Array[Color] = [
	Color("ffc629"), Color("42cd84"), Color("4a8ff5"), Color("ff7a6b"),
	Color("a98bff"), Color("ff9ac8"), Color("49c7d6"), Color("ffa63d"),
]

var mmi: MultiMeshInstance3D
var _cells: Array = []    # {x, z, s, col: Color, n: float}
var _clears: Array = [Rect2(-2.0, -3.0, 4.0, 6.0)]  # huecos en XZ (uno por mesa)
var _grown: Array = []                # los mismos huecos con el margen ya aplicado
var _last: PackedFloat32Array = PackedFloat32Array()  # distancia con la que se dibujó cada cubo
var _heights: PackedFloat32Array = PackedFloat32Array()  # altura con la que se dibujó cada cubo

func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3(SIDE, 1.0, SIDE)
	mm.mesh = box
	_generate()
	mm.instance_count = _cells.size()
	mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.55
	mat.metallic = 0.0
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Cubit de la cobertura entera, para que nunca se recorte por visibilidad
	mmi.custom_aabb = AABB(Vector3(X_MIN - 1, BASE_Y - 1.0, -Z_FAR - 1), Vector3(X_MAX - X_MIN + 2, 10, Z_FAR + Z_NEAR + 2))
	add_child(mmi)
	_last.resize(_cells.size())
	_last.fill(-1.0)
	_heights.resize(_cells.size())
	_heights.fill(0.0)
	_grow_clears()
	_rebuild()

## Cuántos cubos se dibujan.
func instance_count() -> int:
	return _cells.size()

func _generate() -> void:
	_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var j0: int = ceili(-float(Z_FAR) / STEP)
	var i0: int = ceili(float(X_MIN) / STEP)
	j0 -= posmod(j0, 2)   # los bloques de 2×2 empiezan en índices pares
	i0 -= posmod(i0, 2)
	for j in range(j0, floori(float(Z_NEAR) / STEP) + 1, 2):
		for i in range(i0, floori(float(X_MAX) / STEP) + 1, 2):
			if rng.randf() < P_LARGE:
				_add_cube(rng, float(i) + 0.5, float(j) + 0.5, 2.0)    # un cubo grande ocupa el bloque
			else:
				for dj in 2:
					for di in 2:
						_add_cube(rng, float(i + di), float(j + dj), 1.0)

## Un cubo de escala horizontal `s` (1 mediano, 2 grande) centrado en (x, z).
func _add_cube(rng: RandomNumberGenerator, x: float, z: float, s: float) -> void:
	var c: Color = PALETTE[rng.randi() % PALETTE.size()]
	c = c.lerp(Color.WHITE, 0.12).lightened(rng.randf_range(-0.04, 0.06))
	_cells.append({"x": x * STEP, "z": z * STEP, "s": s, "col": c, "n": pow(rng.randf(), DEPTH_POW)})

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
		_grown.append((r as Rect2).grow(CLEAR_MARGIN))

## Distancia de un cubo al hueco más cercano.
func _clear_dist(x: float, z: float) -> float:
	var best: float = INF
	for r in _grown:
		var rect: Rect2 = r
		var dx: float = maxf(maxf(rect.position.x - x, 0.0), x - rect.end.x)
		var dz: float = maxf(maxf(rect.position.y - z, 0.0), z - rect.end.y)
		best = minf(best, Vector2(dx, dz).length())
	return 0.0 if best == INF else best

## Altura del cubo: grueso mínimo + relieve cercano + relieve lejano (crece con la distancia a la mesa).
func _height_for(s: float, n: float, d: float) -> float:
	var hmul: float = 1.35 if s > 1.5 else 1.0   # los grandes son más profundos
	var far: float = smoothstep(RISE_START, RISE_END, d)
	return (TOP_MIN - BASE_Y) + (NEAR_RISE + FAR_RISE * far) * n * hmul

func _rebuild() -> void:
	var mm: MultiMesh = mmi.multimesh
	var span: float = NEAR_RISE + FAR_RISE
	for k in _cells.size():
		var cell: Dictionary = _cells[k]
		var x: float = cell["x"]
		var z: float = cell["z"]
		var s: float = cell["s"]
		# Un cubo grande se mide desde su borde, no desde su centro. A partir de RISE_END ya no cambia
		# nada: se recorta, y los cubos que no cambian respecto al último dibujo se saltan.
		var d: float = minf(maxf(_clear_dist(x, z) - maxf(s - 1.0, 0.0) * SIDE * 0.5, 0.0), RISE_END)
		if absf(d - _last[k]) < 0.0001:
			continue
		_last[k] = d
		var h: float = _height_for(s, cell["n"], d)
		_heights[k] = h
		mm.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(s, h, s)), Vector3(x, BASE_Y + h * 0.5, z)))
		# Más profundo = más claro; más cerca de una mesa = un poco más pálido
		var tall: float = clampf((h - (TOP_MIN - BASE_Y)) / (span * 1.35), 0.0, 1.0)
		var base: Color = (cell["col"] as Color).lerp(FADE_COLOR, FADE)
		var col: Color = base.lerp(Color.WHITE, TALL_LIGHT * tall)
		col = col.lerp(Color("eef4fd"), NEAR_PALE * (1.0 - smoothstep(0.0, 3.0, d)))
		mm.set_instance_color(k, col)
