class_name FloorCubes
extends Node3D
## Suelo de cubos de colores: un solo MultiMesh (una llamada de dibujo).
## Los cubos junto al tablero quedan bajos y suaves; los lejanos crecen y dan profundidad.

const STEP := 1.0
const SIDE := 0.9
const X_HALF := 13        # cubos a cada lado en X
const Z_FAR := 24         # filas hacia el fondo (−Z)
const Z_NEAR := 9         # filas hacia la cámara (+Z)
const TOP_MIN := -0.43    # cima más baja: justo sobre el suelo base
const BASE_Y := -0.60     # base de todos los cubos
const MAX_RISE := 1.5
const PALETTE: Array[Color] = [
	Color("ffc629"), Color("42cd84"), Color("4a8ff5"), Color("ff7a6b"),
	Color("a98bff"), Color("ff9ac8"), Color("49c7d6"), Color("ffa63d"),
]

var mmi: MultiMeshInstance3D
var _cells: Array = []   # {x, z, col: Color, n: float}
var _clear_hw: float = 2.0
var _clear_hh: float = 3.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261112
	for j in range(-Z_FAR, Z_NEAR + 1):
		for i in range(-X_HALF, X_HALF + 1):
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
	mmi.custom_aabb = AABB(Vector3(-20, -2, -40), Vector3(40, 8, 60))
	add_child(mmi)
	_rebuild()

## Zona libre alrededor del tablero (semiancho y semialto, ya con el marco).
func set_clear_rect(hw: float, hh: float) -> void:
	_clear_hw = hw
	_clear_hh = hh
	if mmi != null:
		_rebuild()

func _rebuild() -> void:
	var mm: MultiMesh = mmi.multimesh
	for k in _cells.size():
		var cell: Dictionary = _cells[k]
		var x: float = cell["x"]
		var z: float = cell["z"]
		var dx: float = maxf(absf(x) - _clear_hw - 0.7, 0.0)
		var dz: float = maxf(absf(z) - _clear_hh - 0.7, 0.0)
		var d: float = Vector2(dx, dz).length()
		var n: float = cell["n"]
		var rise: float = smoothstep(0.2, 7.0, d) * (0.10 + MAX_RISE * n * n)
		var top: float = TOP_MIN + rise
		var h: float = top - BASE_Y
		var t := Transform3D(Basis.from_scale(Vector3(1.0, h, 1.0)), Vector3(x, BASE_Y + h * 0.5, z))
		mm.set_instance_transform(k, t)
		# Más cerca del tablero: más pálido, para que mande el color de las fichas
		var col: Color = (cell["col"] as Color).lerp(Color("eef4fd"), 0.25 * (1.0 - smoothstep(0.0, 3.0, d)))
		mm.set_instance_color(k, col)
