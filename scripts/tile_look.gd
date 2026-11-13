class_name TileLook
extends RefCounted
## Piezas visuales compartidas por el tablero y las losetas del mundo: el metal
## dorado de la ficha, su dorso con emblema y las mesas con marco barnizado.

const GOLD := Color("e9b949")
const FACE := 0.425   # semiancho de la cara de la ficha del tablero (para el bisel)

static var _back: ImageTexture
static var _bezel: ImageTexture

## Material del cuerpo de la ficha. Sin `bezel` es oro liso (losetas del menú y de
## las materias, que ya llevan su propio borde); con `bezel` oscurece el hueco de la
## cara como en el tablero.
static func gold_material(bezel: Texture2D = null, size: float = 0.98) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = GOLD
	m.metallic = 1.0
	m.metallic_specular = 0.55
	m.roughness = 0.28
	m.clearcoat_enabled = true
	m.clearcoat = 0.25
	m.clearcoat_roughness = 0.18
	if bezel != null:
		m.albedo_texture = bezel
		m.uv1_scale = Vector3(1.0 / size, 1.0 / size, 1.0)
		m.uv1_offset = Vector3(0.5, 0.5, 0.0)
	return m

static func bezel_texture() -> ImageTexture:
	if _bezel == null:
		_bezel = _make_bezel()
	return _bezel

static func back_texture() -> ImageTexture:
	if _back == null:
		_back = _make_back()
	return _back

## Dorso de la ficha: tarjeta azulada con borde fino y un emblema en el centro.
static func _make_back() -> ImageTexture:
	var n := 128
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	var top := Color("e8f0fb")
	var bot := Color("c3d6f2")
	var line := Color("9cbce4")
	var mark := Color("4a8ff5")
	var inner := Color("eef5ff")
	for y in n:
		var t: float = float(y) / float(n - 1)
		for x in n:
			var u := Vector2((float(x) + 0.5) / n * 2.0 - 1.0, (float(y) + 0.5) / n * 2.0 - 1.0)
			var col: Color = top.lerp(bot, t)
			var d: float = UiTheme.sdf(u, Vector2(0.88, 0.88), 0.22)
			col = col.lerp(line, clampf(1.0 - absf(d + 0.02) / 0.04, 0.0, 1.0) * 0.9)
			var m: float = UiTheme.sdf(u, Vector2(0.50, 0.50), 0.18)
			if m < 0.0:
				col = col.lerp(mark, 0.95)
			var mi: float = UiTheme.sdf(u, Vector2(0.28, 0.28), 0.10)
			if mi < 0.0:
				col = col.lerp(inner, 0.97)
			var mo: float = UiTheme.sdf(u, Vector2(0.13, 0.13), 0.055)
			if mo < 0.0:
				col = col.lerp(mark, 0.95)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

## Bisel dorado: oscurece el hueco donde encaja la cara (oclusión falsa).
static func _make_bezel() -> ImageTexture:
	var n := 128
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var p := Vector2((float(x) + 0.5) / n * 2.0 - 1.0, (float(y) + 0.5) / n * 2.0 - 1.0) * 0.49
			var d: float = UiTheme.sdf(p, Vector2(FACE, FACE), 0.09)
			var k: float = 1.0 - 0.42 * exp(-pow(maxf(d, 0.0) / 0.015, 2.0))
			var do: float = UiTheme.sdf(p, Vector2(0.49, 0.49), 0.16)
			k *= lerpf(1.0, 0.86, clampf(1.0 + do / 0.05, 0.0, 1.0))
			img.set_pixel(x, y, Color(k, k, k))
	return ImageTexture.create_from_image(img)

## Losa de una mesa: cuadrícula de puntos y un borde fino.
static func plate_texture(hx: float, hz: float) -> ImageTexture:
	var n := 128
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGB8)
	var base := Color("e9dab8")
	var dot := Color("d8c395")
	var line := Color("a6c7ea")
	for y in n:
		var uy: float = (float(y) + 0.5) / n * 2.0 - 1.0
		for x in n:
			var ux: float = (float(x) + 0.5) / n * 2.0 - 1.0
			var col: Color = base
			var dx: float = absf(fposmod(ux * hx, 0.28) - 0.14)
			var dz: float = absf(fposmod(uy * hz, 0.28) - 0.14)
			col = col.lerp(dot, clampf(1.0 - sqrt(dx * dx + dz * dz) / 0.075, 0.0, 1.0))
			var d: float = UiTheme.sdf(Vector2(ux * hx, uy * hz), Vector2(hx, hz) - Vector2(0.11, 0.11), 0.16)
			col = col.lerp(line, clampf(1.0 - absf(d + 0.012) / 0.02, 0.0, 1.0) * 0.8)
			col = col.darkened(0.10 * clampf(1.0 + d / 0.06, 0.0, 1.0))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

## Mesa completa (marco azul + losa de puntos) de `w` × `h`, centrada en el origen
## del nodo padre. Es la misma que la del tablero: así el mundo se ve de una pieza.
static func table(parent: Node3D, w: float, h: float) -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("2f86d6")
	fm.roughness = 0.30
	fm.metallic = 0.25
	fm.clearcoat_enabled = true
	fm.clearcoat = 0.3
	var frame := MeshInstance3D.new()
	frame.mesh = TileMesh.slab((w + 0.45) * 0.5, (h + 0.45) * 0.5, 0.36, 0.16, 0.05, 5, 8)
	frame.material_override = fm
	frame.position.y = -0.245
	node.add_child(frame)
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = plate_texture(w * 0.5, h * 0.5)
	pm.uv1_scale = Vector3(1.0 / w, 1.0 / h, 1.0)
	pm.uv1_offset = Vector3(0.5, 0.5, 0.0)
	pm.roughness = 0.85
	var plate := MeshInstance3D.new()
	plate.mesh = TileMesh.slab(w * 0.5, h * 0.5, 0.22, 0.09, 0.025, 5, 8)
	plate.material_override = pm
	plate.position.y = -0.15
	node.add_child(plate)
	return node