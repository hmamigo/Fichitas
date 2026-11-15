extends SceneTree
## Paquetes externos: godot --headless --path . --script res://tests/test_packs.gd

var fails: int = 0

func check(ok: bool, msg: String) -> void:
	print(("  OK   " if ok else "  FALLA ") + msg)
	if not ok:
		fails += 1

func _png(c: Color, w: int = 64, h: int = 64) -> PackedByteArray:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return img.save_png_to_buffer()

## Arma un .zip en disco con {nombre: PackedByteArray} y devuelve sus bytes.
func _zip(files: Dictionary) -> PackedByteArray:
	var path: String = "user://test_pack_src.zip"
	var zp := ZIPPacker.new()
	zp.open(path)
	for n in files:
		zp.start_file(n)
		zp.write_file(files[n])
		zp.close_file()
	zp.close()
	var b: PackedByteArray = FileAccess.get_file_as_bytes(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return b

func _pack_zip(id: String, pairs: int, extra: Dictionary = {}, prefix: String = "") -> PackedByteArray:
	var files: Dictionary = {}
	var plist: Array = []
	for i in pairs:
		files["%simg/%da.png" % [prefix, i]] = _png(Color.from_hsv(float(i) / 10.0, 0.5, 1.0))
		files["%simg/%db.png" % [prefix, i]] = _png(Color.from_hsv(float(i) / 10.0, 0.5, 0.8))
		plist.append({"a": "img/%da.png" % i, "b": "img/%db.png" % i, "fact": "Dato %d" % i})
	var meta: Dictionary = {"format": 1, "id": id, "name": "Prueba " + id, "pairs": plist}
	meta.merge(extra, true)
	files[prefix + "pack.json"] = JSON.stringify(meta).to_utf8_buffer()
	return _zip(files)

func _init() -> void:
	PackImport.dir = "user://test_packs"
	PackImport.purge()
	var official: Array = Packs.official_ids()

	print("Importar un paquete válido")
	var r: Dictionary = PackImport.import_bytes(_pack_zip("historia", 4), official)
	check(bool(r["ok"]) and r["id"] == "historia" and int(r["pairs"]) == 4, "se importa un .zip válido (%s)" % str(r.get("error", "")))
	var all: Array = Packs.load_all()
	var found: Dictionary = {}
	for p in all:
		if p["id"] == "historia":
			found = p
	check(not found.is_empty() and bool(found["external"]) and (found["pairs"] as Array).size() == 4, "el paquete aparece en load_all con sus parejas")
	check(not found.is_empty() and int(found["unlock"]) == PackImport.NO_UNLOCK, "sin unlock no entra al recorrido general")
	check(not found.is_empty() and found["pairs"][0]["fact"] == "Dato 0" and found["pairs"][0]["a"] != null, "conserva el dato curioso y las imágenes")
	check(not found.is_empty() and not bool(found["premium"]), "un paquete externo nunca es de pago")
	check(all.size() >= official.size() + 1 and all[0]["id"] == official[0], "los oficiales siguen primero")

	print("Variantes válidas")
	r = PackImport.import_bytes(_pack_zip("otro", 3, {"unlock": 5}, "mi-paquete/"), official)
	check(bool(r["ok"]), "acepta pack.json dentro de una carpeta (%s)" % str(r.get("error", "")))
	var unlock5: bool = false
	for p in Packs.load_all():
		if p["id"] == "otro":
			unlock5 = int(p["unlock"]) == 5
	check(unlock5, "respeta unlock")
	r = PackImport.import_bytes(_pack_zip("historia", 5), official)
	check(bool(r["ok"]) and int(r["pairs"]) == 5, "reimportar el mismo id lo reemplaza")
	var n_hist: int = 0
	for p in Packs.load_all():
		if p["id"] == "historia":
			n_hist = (p["pairs"] as Array).size()
	check(n_hist == 5, "la versión nueva sustituye a la anterior")

	print("Rechazos")
	check(not bool(PackImport.import_bytes(_pack_zip("mat", 4), official)["ok"]), "no se puede usar el id de una materia oficial")
	check(not bool(PackImport.import_bytes(_pack_zip("corto", 2), official)["ok"]), "menos de 3 parejas")
	check(not bool(PackImport.import_bytes(_pack_zip("Mal Id!", 3), official)["ok"]), "id con caracteres no permitidos")
	check(not bool(PackImport.import_bytes("esto no es un zip".to_utf8_buffer(), official)["ok"]), "bytes que no son un .zip")
	check(not bool(PackImport.import_bytes(PackedByteArray(), official)["ok"]), "archivo vacío")
	check(not bool(PackImport.import_bytes(_zip({"x.txt": "hola".to_utf8_buffer()}), official)["ok"]), "zip sin pack.json")
	var evil: Dictionary = {"format": 1, "id": "malo", "pairs": [
		{"a": "../../fuera.png", "b": "b.png"}, {"a": "a.png", "b": "b.png"}, {"a": "a.png", "b": "b.png"}]}
	check(not bool(PackImport.import_bytes(_zip({"pack.json": JSON.stringify(evil).to_utf8_buffer(), "a.png": _png(Color.RED), "b.png": _png(Color.BLUE)}), official)["ok"]), "ruta con .. rechazada")
	var missing: Dictionary = {"id": "falta", "pairs": [{"a": "a.png", "b": "b.png"}, {"a": "a.png", "b": "b.png"}, {"a": "a.png", "b": "no.png"}]}
	check(not bool(PackImport.import_bytes(_zip({"pack.json": JSON.stringify(missing).to_utf8_buffer(), "a.png": _png(Color.RED), "b.png": _png(Color.BLUE)}), official)["ok"]), "imagen que falta en el zip")
	var junk: Dictionary = {"id": "basura", "pairs": [{"a": "a.png", "b": "b.png"}, {"a": "a.png", "b": "b.png"}, {"a": "a.png", "b": "b.png"}]}
	check(not bool(PackImport.import_bytes(_zip({"pack.json": JSON.stringify(junk).to_utf8_buffer(), "a.png": "no soy un png".to_utf8_buffer(), "b.png": _png(Color.BLUE)}), official)["ok"]), "imagen corrupta")
	var tiny: Dictionary = {"id": "pequeno", "pairs": [{"a": "a.png", "b": "b.png"}, {"a": "a.png", "b": "b.png"}, {"a": "a.png", "b": "b.png"}]}
	check(not bool(PackImport.import_bytes(_zip({"pack.json": JSON.stringify(tiny).to_utf8_buffer(), "a.png": _png(Color.RED, 8, 8), "b.png": _png(Color.BLUE)}), official)["ok"]), "imagen demasiado pequeña")
	var leftovers: int = 0
	for d in DirAccess.get_directories_at(PackImport.dir):
		if d.begins_with("."):
			leftovers += 1
	check(leftovers == 0, "los rechazos no dejan carpetas temporales")
	var ids: Array = PackImport.installed()
	check(ids.has("historia") and ids.has("otro") and not ids.has("malo") and not ids.has("mat"), "solo quedan instalados los paquetes válidos")

	print("Imágenes grandes")
	var big: Dictionary = {"id": "grande", "pairs": [{"a": "a.png", "b": "b.png"}, {"a": "a.png", "b": "b.png"}, {"a": "a.png", "b": "b.png"}]}
	r = PackImport.import_bytes(_zip({"pack.json": JSON.stringify(big).to_utf8_buffer(), "a.png": _png(Color.GREEN, 2000, 1500), "b.png": _png(Color.BLUE)}), official)
	check(bool(r["ok"]), "acepta una imagen de 2000 px (%s)" % str(r.get("error", "")))
	var tex_w: int = 0
	for p in Packs.load_all():
		if p["id"] == "grande":
			tex_w = (p["pairs"][0]["a"] as Texture2D).get_width()
	check(tex_w == PackImport.OUT_SIDE, "se reduce a %d px de lado" % PackImport.OUT_SIDE)

	print("Quitar")
	check(PackImport.remove("historia") and not PackImport.installed().has("historia"), "quitar un paquete lo borra")
	check(not PackImport.remove("../x") and not PackImport.remove("nunca"), "quitar ids inválidos o inexistentes no hace nada")
	PackImport.purge()
	check(PackImport.installed().is_empty(), "purge deja la carpeta vacía")

	print("Resultado: %s" % ("TODO OK" if fails == 0 else "%d fallos" % fails))
	quit(0 if fails == 0 else 1)
