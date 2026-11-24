class_name Packs
extends RefCounted
## Carga los paquetes de contenido (mismo formato JSON que la versión web):
## los oficiales desde res://packs y los externos desde user://packs (ver PackImport).

const OFFICIAL_DIR := "res://packs/"
## Categorías de materias, en el orden en que se muestran. Para renombrar una categoría basta
## cambiar su `name`; el `id` es el que va en el `pack.json` de cada materia.
const CATEGORIES := [
	{"id": "peques", "name": "Peques", "icon": "cat_peques", "sub": "Sin leer: solo imágenes",
		"color": "ffb3d6", "ink": "9c2b68", "frame": "e2579b"},
	{"id": "exploradores", "name": "Exploradores", "icon": "cat_exploradores", "sub": "Lo básico de cada tema",
		"color": "9fe0b0", "ink": "1c6b3d", "frame": "33a866"},
	{"id": "nerds", "name": "Nerds", "icon": "cat_nerds", "sub": "Para ir más a fondo",
		"color": "c9b8ff", "ink": "4f35a8", "frame": "7656d8"},
]
const GROUPS_FILE := "res://packs/groups.json"
const DEFAULT_CATEGORY := "exploradores"   # sin categoría (o desconocida), p. ej. un paquete propio

## `id` si es una categoría conocida; si no, la categoría por omisión.
static func valid_category(id: String) -> String:
	for c in CATEGORIES:
		if c["id"] == id:
			return id
	return DEFAULT_CATEGORY

## Materias que agrupan temas (`packs/groups.json`): una materia (Música) contiene varios paquetes
## (Instrumentos, Notas) que se juegan cada uno como una materia normal. Cada paquete dice a cuál
## pertenece con `"group": "<id>"`; sin `group`, o con uno desconocido, se ve suelto como siempre.
static func load_groups() -> Array:
	var out: Array = []
	var j = _read_json(GROUPS_FILE)
	if not (j is Dictionary):
		return out
	for g in (j as Dictionary).get("groups", []):
		if g is Dictionary and (g as Dictionary).has("id") and (g as Dictionary).has("name"):
			var icon: String = str(g.get("icon", "paquete"))
			out.append({"id": str(g["id"]), "name": str(g["name"]), "icon": icon if UiTheme.has_icon(icon) else "book",   # un icono que no existe cae al libro, como los paquetes propios
				"category": valid_category(str(g.get("category", ""))), "color": str(g.get("color", ""))})
	return out

static func group_by_id(groups: Array, id: String) -> Dictionary:
	for g in groups:
		if (g as Dictionary)["id"] == id:
			return g
	return {}

## `id` si es una materia conocida; si no, "" (el paquete se muestra suelto).
static func valid_group(id: String, groups: Array) -> String:
	return id if not group_by_id(groups, id).is_empty() else ""

## Deja en cada paquete su materia (o "") y le da la categoría de la materia, para que los temas
## de una materia queden juntos en la lista.
static func apply_groups(packs: Array, groups: Array) -> void:
	for p in packs:
		var gid: String = valid_group(str(p.get("group", "")), groups)
		p["group"] = gid
		if gid != "":
			p["category"] = group_by_id(groups, gid)["category"]

## Entradas de la lista de materias, en el orden de `packs`: un paquete suelto ({"pack"}) o una
## materia con todos sus temas ({"group", "packs"}), ubicada donde aparece su primer tema.
static func top_level(packs: Array, groups: Array) -> Array:
	var out: Array = []
	var seen: Array = []
	for p in packs:
		var gid: String = str(p.get("group", ""))
		if gid == "":
			out.append({"pack": p})
		elif not seen.has(gid):
			seen.append(gid)
			var kids: Array = []
			for q in packs:
				if str(q.get("group", "")) == gid:
					kids.append(q)
			out.append({"group": group_by_id(groups, gid), "packs": kids})
	return out

## Oficiales primero y luego los externos; un externo con id oficial se ignora.
## El resultado va agrupado por categoría (Peques, Exploradores, Nerds) y, dentro de cada una,
## en el orden de `index.json`.
static func load_all() -> Array:
	var out: Array = _load_official()
	var taken: Array = official_ids()
	for p in _load_external():
		if not taken.has(p["id"]):
			out.append(p)
			taken.append(p["id"])
	apply_groups(out, load_groups())
	var grouped: Array = []
	for c in CATEGORIES:
		for p in out:
			if p["category"] == c["id"]:
				grouped.append(p)
	return grouped

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
		"category": valid_category(str(j.get("category", ""))), "group": str(j.get("group", "")),
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
