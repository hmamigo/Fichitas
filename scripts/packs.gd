class_name Packs
extends RefCounted
## Carga los paquetes de contenido (mismo formato JSON que la versión web):
## los oficiales desde res://packs y los externos desde user://packs (ver PackImport).

const OFFICIAL_DIR := "res://packs/"

## Oficiales primero y luego los externos; un externo con id oficial se ignora.
static func load_all() -> Array:
	var out: Array = _load_official()
	var taken: Array = official_ids()
	for p in _load_external():
		if not taken.has(p["id"]):
			out.append(p)
			taken.append(p["id"])
	return out

static func official_ids() -> Array:
	var idx = _read_json(OFFICIAL_DIR + "index.json")
	if idx == null:
		return []
	return (idx as Dictionary).get("packs", [])

static func _load_official() -> Array:
	var out: Array = []
	for id in official_ids():
		var pack = _load_pack(OFFICIAL_DIR + "%s/" % id, false)
		if pack != null:
			out.append(pack)
	return out

static func _load_external() -> Array:
	var out: Array = []
	for id in PackImport.installed():
		var pack = _load_pack(PackImport.dir + "/%s/" % id, true)
		if pack != null:
			out.append(pack)
	return out

static func _load_pack(base: String, external: bool):
	var j = _read_json(base + "pack.json")
	if not (j is Dictionary) or not (j as Dictionary).has("id"):
		return null
	var pairs: Array = []
	var k: int = 0
	for p in (j as Dictionary).get("pairs", []):
		var ta: Texture2D = _texture(base + str(p["a"]), external)
		var tb: Texture2D = _texture(base + str(p["b"]), external)
		if ta == null or tb == null:
			continue
		var pid: String = "%s:%s" % [j["id"], p.get("id", k)]
		pairs.append({"id": pid, "a": ta, "b": tb, "fact": p.get("fact", "")})
		k += 1
	return {"id": j["id"], "name": j.get("name", j["id"]), "unlock": int(j.get("unlock", 1)),
		"premium": bool(j.get("premium", false)) and not external,
		"external": external, "pairs": pairs}

## Las imágenes oficiales están importadas por el editor; las externas se leen del disco.
static func _texture(path: String, external: bool) -> Texture2D:
	if not external:
		return load(path) as Texture2D
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
