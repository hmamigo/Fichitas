class_name PackImport
extends RefCounted
## Paquetes externos: se importan desde un .zip (pack.json + imágenes) a user://packs/<id>/.
## El zip no es de confianza: se valida todo y solo se guardan imágenes decodificadas y
## recodificadas como PNG con nombres propios; jamás se escribe una ruta que venga del zip.

const MAX_ZIP := 50 * 1024 * 1024   # tamaño máximo del .zip
const MAX_ENTRIES := 600            # archivos máximos dentro del .zip
const MAX_IMG_BYTES := 6 * 1024 * 1024
const MAX_IN_SIDE := 4096           # lado máximo aceptado de una imagen
const OUT_SIDE := 1024              # lado máximo con el que se guarda (memoria de vídeo)
const MIN_SIDE := 32
const MIN_PAIRS := 3
const MAX_PAIRS := 60
const MAX_NAME := 40
const MAX_FACT := 300
const NO_UNLOCK := 99               # sin `unlock`, el paquete no entra en el recorrido general
const ID_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789_-"
const EXTS := ["png", "jpg", "jpeg", "webp"]

static var dir: String = "user://packs"   # las pruebas lo cambian por una carpeta propia

## Lee el archivo elegido (ruta normal o content:// en Android) e importa el paquete.
## `reserved`: ids que no se pueden usar (los paquetes oficiales).
static func import_file(path: String, reserved: Array) -> Dictionary:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	return import_bytes(bytes, reserved)

## Devuelve {ok: true, id, name, pairs} o {ok: false, error}.
static func import_bytes(bytes: PackedByteArray, reserved: Array) -> Dictionary:
	if bytes.is_empty():
		return _fail("No se pudo leer el archivo.")
	if bytes.size() > MAX_ZIP:
		return _fail("El archivo es demasiado grande (máximo 50 MB).")
	DirAccess.make_dir_recursive_absolute(dir)
	var tmp_zip: String = dir + "/.import.zip"
	var w := FileAccess.open(tmp_zip, FileAccess.WRITE)
	if w == null:
		return _fail("No se pudo preparar la importación.")
	w.store_buffer(bytes)
	w.close()
	var res: Dictionary = _import_zip(tmp_zip, reserved)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_zip))
	return res

## Ids de los paquetes importados.
static func installed() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			out.append(d)
	out.sort()
	return out

static func remove(id: String) -> bool:
	if not _valid_id(id) or not DirAccess.dir_exists_absolute(dir + "/" + id):
		return false
	_rm_rf(dir + "/" + id)
	return true

## Borra todos los paquetes importados (y restos de importaciones a medias).
static func purge() -> void:
	_rm_rf(dir)

# ---------- Interno ----------

static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg}

static func _valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > 32:
		return false
	for c in id:
		if not ID_CHARS.contains(c):
			return false
	return true

static func _import_zip(zip_path: String, reserved: Array) -> Dictionary:
	var zr := ZIPReader.new()
	if zr.open(zip_path) != OK:
		return _fail("No es un archivo .zip válido.")
	var res: Dictionary = _import_open(zr, reserved)
	zr.close()
	return res

static func _import_open(zr: ZIPReader, reserved: Array) -> Dictionary:
	var names: PackedStringArray = zr.get_files()
	if names.size() > MAX_ENTRIES:
		return _fail("El .zip tiene demasiados archivos.")
	var pj: String = _find_pack_json(names)
	if pj == "":
		return _fail("No se encontró pack.json dentro del .zip.")
	var prefix: String = pj.trim_suffix("pack.json")
	var json := JSON.new()
	if json.parse(zr.read_file(pj).get_string_from_utf8()) != OK or not (json.data is Dictionary):
		return _fail("pack.json no es un JSON válido.")
	var meta: Dictionary = _validate(json.data as Dictionary, reserved)
	if meta.has("error"):
		return _fail(str(meta["error"]))
	# Cada imagen del .zip se decodifica, se reduce y se guarda como PNG propio.
	var id: String = meta["id"]
	var tmp_dir: String = dir + "/.tmp-" + id
	_rm_rf(tmp_dir)
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	var saved: Dictionary = {}   # nombre dentro del zip -> archivo guardado
	var out_pairs: Array = []
	for pr in meta["pairs"]:
		var files: Array = []
		for side in ["a", "b"]:
			var entry: String = prefix + str(pr[side])
			if not names.has(entry):
				_rm_rf(tmp_dir)
				return _fail("Falta la imagen «%s» en el .zip." % str(pr[side]))
			if not saved.has(entry):
				var fname: String = "f%03d.png" % saved.size()
				var err: String = _save_image(zr, entry, tmp_dir + "/" + fname)
				if err != "":
					_rm_rf(tmp_dir)
					return _fail("«%s»: %s" % [str(pr[side]), err])
				saved[entry] = fname
			files.append(saved[entry])
		out_pairs.append({"id": pr["id"], "a": files[0], "b": files[1], "fact": pr["fact"]})
	var pack := {"format": 1, "id": id, "name": meta["name"], "unlock": meta["unlock"],
		"category": meta["category"], "pairs": out_pairs}
	var jf := FileAccess.open(tmp_dir + "/pack.json", FileAccess.WRITE)
	if jf == null:
		_rm_rf(tmp_dir)
		return _fail("No se pudo guardar el paquete.")
	jf.store_string(JSON.stringify(pack, " "))
	jf.close()
	# Si ya existía un paquete con ese id (actualización), se sustituye entero.
	_rm_rf(dir + "/" + id)
	var from_abs: String = ProjectSettings.globalize_path(tmp_dir)
	var to_abs: String = ProjectSettings.globalize_path(dir + "/" + id)
	if DirAccess.rename_absolute(from_abs, to_abs) != OK:
		_rm_rf(tmp_dir)
		return _fail("No se pudo guardar el paquete.")
	return {"ok": true, "id": id, "name": meta["name"], "pairs": out_pairs.size()}

## pack.json en la raíz del zip, o dentro de una única carpeta de primer nivel.
static func _find_pack_json(names: PackedStringArray) -> String:
	if names.has("pack.json"):
		return "pack.json"
	for n in names:
		if n.get_file() == "pack.json" and n.count("/") == 1:
			return n
	return ""

## Valida y normaliza pack.json. Devuelve {id, name, unlock, pairs:[{id, a, b, fact}]} o {error}.
static func _validate(j: Dictionary, reserved: Array) -> Dictionary:
	if j.has("format") and int(j["format"]) != 1:
		return {"error": "Formato de paquete no compatible (format debe ser 1)."}
	var id: String = str(j.get("id", "")).strip_edges().to_lower()
	if not _valid_id(id):
		return {"error": "El id debe usar solo minúsculas, números, - y _ (máximo 32)."}
	if reserved.has(id):
		return {"error": "El id «%s» ya lo usa una materia oficial." % id}
	var name: String = str(j.get("name", id)).strip_edges()
	if name.is_empty():
		name = id
	name = name.substr(0, MAX_NAME)
	var unlock: int = clampi(int(j.get("unlock", NO_UNLOCK)), 1, NO_UNLOCK)
	var raw = j.get("pairs", null)
	if not (raw is Array):
		return {"error": "pack.json no tiene la lista de parejas (pairs)."}
	var n: int = (raw as Array).size()
	if n < MIN_PAIRS or n > MAX_PAIRS:
		var msg: String = "El paquete debe tener entre %d y %d parejas (tiene %d)."
		return {"error": msg % [MIN_PAIRS, MAX_PAIRS, n]}
	var pairs: Array = []
	var used: Array = []
	for k in n:
		var p = (raw as Array)[k]
		if not (p is Dictionary):
			return {"error": "La pareja %d no es válida." % (k + 1)}
		var a: String = _rel_path(str((p as Dictionary).get("a", "")))
		var b: String = _rel_path(str((p as Dictionary).get("b", "")))
		if a == "" or b == "":
			var msg2: String = "La pareja %d necesita dos imágenes (.png, .jpg, .webp) con ruta relativa."
			return {"error": msg2 % (k + 1)}
		var pid: String = str((p as Dictionary).get("id", k)).strip_edges().to_lower()
		if not _valid_id(pid):
			pid = str(k)
		if used.has(pid):
			return {"error": "El id de pareja «%s» está repetido." % pid}
		used.append(pid)
		var fact: String = str((p as Dictionary).get("fact", "")).strip_edges().substr(0, MAX_FACT)
		pairs.append({"id": pid, "a": a, "b": b, "fact": fact})
	return {"id": id, "name": name, "unlock": unlock, "pairs": pairs,
		"category": Packs.valid_category(str(j.get("category", "")))}

## Ruta relativa segura dentro del zip, o "" si no vale (absoluta, con "..", con ":", etc.).
static func _rel_path(p: String) -> String:
	var s: String = p.strip_edges().replace("\\", "/")
	while s.begins_with("./"):
		s = s.substr(2)
	if s.is_empty() or s.begins_with("/") or s.contains(":") or s.contains("//"):
		return ""
	for seg in s.split("/"):
		if seg == ".." or seg == "." or seg.is_empty():
			return ""
	if not EXTS.has(s.get_extension().to_lower()):
		return ""
	return s

## Decodifica una imagen del zip, la reduce si hace falta y la guarda como PNG.
## Devuelve "" o el motivo del error.
static func _save_image(zr: ZIPReader, entry: String, out_path: String) -> String:
	var bytes: PackedByteArray = zr.read_file(entry)
	if bytes.is_empty():
		return "no se pudo leer."
	if bytes.size() > MAX_IMG_BYTES:
		return "pesa demasiado (máximo 6 MB por imagen)."
	var img := Image.new()
	var err: int = FAILED
	match entry.get_extension().to_lower():
		"png":
			err = img.load_png_from_buffer(bytes)
		"jpg", "jpeg":
			err = img.load_jpg_from_buffer(bytes)
		"webp":
			err = img.load_webp_from_buffer(bytes)
	if err != OK or img.is_empty():
		return "no es una imagen válida."
	if img.get_width() > MAX_IN_SIDE or img.get_height() > MAX_IN_SIDE:
		return "es demasiado grande (máximo %d px de lado)." % MAX_IN_SIDE
	if img.get_width() < MIN_SIDE or img.get_height() < MIN_SIDE:
		return "es demasiado pequeña (mínimo %d px de lado)." % MIN_SIDE
	img.convert(Image.FORMAT_RGBA8)
	var big: int = maxi(img.get_width(), img.get_height())
	if big > OUT_SIDE:
		var f: float = float(OUT_SIDE) / float(big)
		var nw: int = maxi(1, roundi(img.get_width() * f))
		var nh: int = maxi(1, roundi(img.get_height() * f))
		img.resize(nw, nh, Image.INTERPOLATE_LANCZOS)
	if img.save_png(out_path) != OK:
		return "no se pudo guardar."
	return ""

static func _rm_rf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + "/" + f))
	for d in DirAccess.get_directories_at(path):
		_rm_rf(path + "/" + d)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
