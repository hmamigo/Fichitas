class_name FloorCubes
extends Node3D
## Suelo de edificios de colores: un solo MultiMesh (una llamada de dibujo).
## Junto a las mesas los edificios son bajos y pálidos (una plaza); lejos se levantan por pisos y,
## en los distritos altos, rematan con un escalón. Hay tres tamaños (grandes de 2×2, medianos de
## 1×1 y chicos de ½×½) repartidos por bloques de 2×2 sin solaparse, así el fondo tiene ritmo y no
## es una cuadrícula uniforme. Las fachadas y azoteas las dibuja `assets/shaders/buildings.gdshader`.
## Modo ligero (`set_light`): sin edificios chicos ni remates, con más grandes y cajas simples en
## lugar de cubos biselados; sirve para móviles antiguos.

const STEP := 1.0         # lado de la celda mediana
const SIDE := 0.9         # lado del cubo mediano: la rendija es el 10 % de la celda
const P_LARGE := 0.20     # probabilidad de que un bloque 2×2 sea un solo cubo grande
const P_SMALL := 0.12     # probabilidad de que una celda mediana se divida en 4 cubos chicos
const P_LARGE_LIGHT := 0.30   # en modo ligero hay más grandes (y ningún chico): menos instancias
# Zona alrededor de cada mesa donde los edificios se quedan bajos y pálidos, y distancia desde la
# que empiezan a crecer: cuanto mayores, más lejos de las mesas aparecen los edificios altos.
const CLEAR_MARGIN := 2.0
const RISE_START := 0.8
const RISE_END := 7.0     # a partir de esta distancia ya no cambia ni la altura ni el color
# Distancia vertical entre las mesas y el suelo: el suelo de edificios queda SINK por debajo de
# donde estaba, así las mesas se ven flotando sobre la ciudad.
const SINK := 1.3
const GROUND_Y := -0.455 - SINK   # plano del suelo (Board dibuja ahí el plano lejano)
const BASE_Y := -0.60 - SINK      # base de todos los edificios
const TOP_MIN := -0.43 - SINK     # cima más baja: justo sobre el plano del suelo
const FLOOR_H := 0.28     # alto de un piso: las alturas son siempre un número entero de pisos
const MAX_RISE := 2.8     # altura máxima (sobre el piso mínimo) de un edificio mediano lejano
# Distritos: un ruido suave reparte barrios bajos y barrios de torres. La altura de cada edificio
# es u^p con u al azar en 0-1: p grande (3,2) da casi todo bajo, p chico (1,2) da muchas torres.
const DISTRICT_FREQ := 0.06
const POW_LOW := 3.2
const POW_HIGH := 1.2
const TOWER_MIN_N := 0.45 # desde esta altura relativa (0-1) un edificio no chico puede llevar remate
const TOWER_MIN_FLOORS := 4   # y solo se ve si tiene al menos estos pisos; si no, se esconde
# Cobertura en UNIDADES DEL MUNDO. Debe cubrir lo que ve la cámara en las seis estaciones (Board:
# álbum en x = -35, menú en -25, materias en -15, modo en -9, tablero en 0, victoria en +10) también
# en sus extremos de paneo: la mesa de materias mide ~±20 en Z y la del álbum ~±26, y la vista
# llega unos 6 más allá; en pantalla apaisada o ultra ancha asoma más a los lados. Hay margen de sobra.
const X_MIN := -54        # borde izquierdo (más allá del álbum)
const X_MAX := 30         # borde derecho (más allá de la estación de victoria)
const Z_FAR := 38         # hacia el fondo (−Z)
const Z_NEAR := 38        # hacia la cámara (+Z)
# Perspectiva atmosférica: todos los edificios se mezclan con el color de la niebla del tablero
# (Board.FOG_COLOR), así el fondo no compite con los colores de las fichas. 0 = sin mezcla.
const FADE_COLOR := Color("b9d2ee")
const FADE := 0.55
const SEED := 20261112
const PALETTE: Array[Color] = [
	Color("ffc629"), Color("42cd84"), Color("4a8ff5"), Color("ff7a6b"),
	Color("a98bff"), Color("ff9ac8"), Color("49c7d6"), Color("ffa63d"),
]
const SHADER := "res://assets/shaders/buildings.gdshader"

## Modo ligero: póngase antes de añadir el nodo, o cámbiese después con `set_light()`.
var light: bool = false
var mmi: MultiMeshInstance3D
var _cells: Array = []    # {x, z, s, col: Color, n: float, tw: int}  tw = índice del remate o -1
var _towers: Array = []   # {w: ancho relativo, f: pisos del remate}; instancia = _cells.size() + índice
var _clears: Array = [Rect2(-2.0, -3.0, 4.0, 6.0)]  # huecos en XZ (uno por mesa)
var _grown: Array = []                # los mismos huecos con el margen ya aplicado
var _last: PackedFloat32Array = PackedFloat32Array()  # distancia con la que se dibujó cada cubo
var _floors: PackedInt32Array = PackedInt32Array()    # pisos con los que se dibujó cada cubo (0 = aún no)

func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _make_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_grow_clears()
	_setup()

## Cambia entre el suelo completo y el ligero (se regenera entero).
func set_light(on: bool) -> void:
	if on == light:
		return
	light = on
	if mmi != null:
		_setup()

## Cuántas instancias se dibujan (edificios y remates).
func instance_count() -> int:
	return _cells.size() + _towers.size()

## Material de los edificios: fachadas y azoteas por shader. Si el shader no cargara, color liso.
func _make_material() -> Material:
	var sh := load(SHADER) as Shader
	if sh != null:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("base_y", BASE_Y)
		m.set_shader_parameter("floor_h", FLOOR_H)
		m.set_shader_parameter("half_ext", SIDE * 0.5)
		return m
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.55
	mat.metallic = 0.0
	return mat

## Genera los edificios y deja el MultiMesh listo (se llama al empezar y al cambiar de modo).
func _setup() -> void:
	_generate()
	var mm: MultiMesh = mmi.multimesh
	if light:
		var box := BoxMesh.new()   # 12 triángulos: lo más barato para móviles antiguos
		box.size = Vector3(SIDE, 1.0, SIDE)
		mm.mesh = box
	else:
		mm.mesh = TileMesh.slab(SIDE * 0.5, SIDE * 0.5, 0.12, 1.0, 0.05, 1, 2)   # 96 triángulos: hay miles
	mm.instance_count = _cells.size() + _towers.size()
	var box_pos := Vector3(X_MIN - 1, BASE_Y - 4.0, -Z_FAR - 1)
	var box_size := Vector3(X_MAX - X_MIN + 2, 14, Z_FAR + Z_NEAR + 2)
	mmi.custom_aabb = AABB(box_pos, box_size)
	_last.resize(_cells.size())
	_last.fill(-1.0)
	_floors.resize(_cells.size())
	_floors.fill(0)
	_rebuild()

func _generate() -> void:
	_cells.clear()
	_towers.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var noise := FastNoiseLite.new()
	noise.seed = SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = DISTRICT_FREQ
	var p_large: float = P_LARGE_LIGHT if light else P_LARGE
	var p_small: float = 0.0 if light else P_SMALL
	var j0: int = ceili(-float(Z_FAR) / STEP)
	var i0: int = ceili(float(X_MIN) / STEP)
	j0 -= posmod(j0, 2)   # los bloques de 2×2 empiezan en índices pares
	i0 -= posmod(i0, 2)
	for j in range(j0, floori(float(Z_NEAR) / STEP) + 1, 2):
		for i in range(i0, floori(float(X_MAX) / STEP) + 1, 2):
			if rng.randf() < p_large:
				_add_cube(rng, noise, float(i) + 0.5, float(j) + 0.5, 2.0)    # un cubo grande ocupa el bloque
				continue
			for dj in 2:
				for di in 2:
					if p_small > 0.0 and rng.randf() < p_small:
						for sj in 2:
							for si in 2:   # cuatro chicos dentro de la celda
								_add_cube(rng, noise, float(i + di) - 0.25 + 0.5 * float(si), float(j + dj) - 0.25 + 0.5 * float(sj), 0.5)
					else:
						_add_cube(rng, noise, float(i + di), float(j + dj), 1.0)

## Un edificio de escala horizontal `s` (0,5 chico, 1 mediano, 2 grande) centrado en (x, z).
func _add_cube(rng: RandomNumberGenerator, noise: FastNoiseLite, x: float, z: float, s: float) -> void:
	var c: Color = PALETTE[rng.randi() % PALETTE.size()]
	c = c.lerp(Color.WHITE, 0.12).lightened(rng.randf_range(-0.04, 0.06))
	var district: float = clampf(0.5 + 0.5 * noise.get_noise_2d(x * STEP, z * STEP), 0.0, 1.0)
	var n: float = pow(rng.randf(), lerpf(POW_LOW, POW_HIGH, district))
	var tw: int = -1
	if not light and s > 0.9 and n >= TOWER_MIN_N:
		tw = _towers.size()
		_towers.append({"w": rng.randf_range(0.5, 0.72), "f": 1 + rng.randi() % 3})
	_cells.append({"x": x * STEP, "z": z * STEP, "s": s, "col": c, "n": n, "tw": tw})

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
		_grown.append((r as Rect2).grow(CLEAR_MARGIN))  # margen: los edificios altos empiezan lejos de la mesa

## Distancia de un cubo al hueco más cercano.
func _clear_dist(x: float, z: float) -> float:
	var best: float = INF
	for r in _grown:
		var rect: Rect2 = r
		var dx: float = maxf(maxf(rect.position.x - x, 0.0), x - rect.end.x)
		var dz: float = maxf(maxf(rect.position.y - z, 0.0), z - rect.end.y)
		best = minf(best, Vector2(dx, dz).length())
	return 0.0 if best == INF else best

## Altura (en pisos) y distancia con la que se dibuja un cubo; `h` no es continua: va de piso en piso.
func _floors_for(s: float, n: float, d: float) -> int:
	var hmul: float = 0.8 if s < 0.9 else (1.35 if s > 1.5 else 1.0)
	var rise: float = smoothstep(RISE_START, RISE_END, d) * (0.10 + MAX_RISE * n) * hmul
	return maxi(1, roundi((TOP_MIN - BASE_Y + rise) / FLOOR_H))

func _rebuild() -> void:
	var mm: MultiMesh = mmi.multimesh
	var n_cells: int = _cells.size()
	for k in n_cells:
		var cell: Dictionary = _cells[k]
		var x: float = cell["x"]
		var z: float = cell["z"]
		# A partir de RISE_END de distancia ya no cambia ni la altura ni el color: se recorta,
		# y los cubos que no cambian respecto al último dibujo se saltan.
		var s: float = cell["s"]
		# Un cubo grande se mide desde su borde, no desde su centro; y crece más que uno chico
		var d: float = minf(maxf(_clear_dist(x, z) - maxf(s - 1.0, 0.0) * SIDE * 0.5, 0.0), RISE_END)
		if absf(d - _last[k]) < 0.0001:
			continue
		_last[k] = d
		var floors: int = _floors_for(s, cell["n"], d)
		_floors[k] = floors
		var h: float = float(floors) * FLOOR_H
		var t := Transform3D(Basis.from_scale(Vector3(s, h, s)), Vector3(x, BASE_Y + h * 0.5, z))
		mm.set_instance_transform(k, t)
		# Más cerca de una mesa: más pálido, para que mande el color de las fichas
		var base: Color = (cell["col"] as Color).lerp(FADE_COLOR, FADE)
		var near: float = 0.38 * (1.0 - smoothstep(0.0, 3.0, d))
		var col: Color = base.lerp(Color("eef4fd"), near)
		mm.set_instance_color(k, col)
		var tw: int = cell["tw"]
		if tw < 0:
			continue
		# Remate escalonado: solo en las torres; en las bajas se esconde bajo el suelo
		var idx: int = n_cells + tw
		var top: Dictionary = _towers[tw]
		if floors >= TOWER_MIN_FLOORS:
			var h2: float = float(top["f"]) * FLOOR_H
			var w: float = s * float(top["w"])
			mm.set_instance_transform(idx, Transform3D(Basis.from_scale(Vector3(w, h2, w)), Vector3(x, BASE_Y + h + h2 * 0.5, z)))
			mm.set_instance_color(idx, col.lightened(0.05))
		else:
			mm.set_instance_transform(idx, Transform3D(Basis.from_scale(Vector3(0.01, 0.01, 0.01)), Vector3(x, BASE_Y - 3.0, z)))
			mm.set_instance_color(idx, col)
