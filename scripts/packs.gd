class_name Packs
extends RefCounted
## Carga los paquetes de contenido (mismo formato JSON que la versión web).

static func load_all() -> Array:
	var out: Array = []
	var idx = _read_json("res://packs/index.json")
	if idx == null:
		return out
	for id in idx.get("packs", []):
		var base: String = "res://packs/%s/" % id
		var j = _read_json(base + "pack.json")
		if j == null:
			continue
		var pairs: Array = []
		var k: int = 0
		for p in j.get("pairs", []):
			var ta = load(base + str(p["a"]))
			var tb = load(base + str(p["b"]))
			if ta == null or tb == null:
				continue
			pairs.append({"id": "%s:%s" % [j["id"], p.get("id", k)], "a": ta, "b": tb, "fact": p.get("fact", "")})
			k += 1
		out.append({"id": j["id"], "name": j.get("name", j["id"]), "unlock": int(j.get("unlock", 1)), "premium": bool(j.get("premium", false)), "pairs": pairs})
	return out

static func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
