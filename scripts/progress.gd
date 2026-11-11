class_name Progress
extends RefCounted
## Progreso guardado como JSON (user://progress.json). Sin puntuación: solo nivel, dominio y calendario de repaso.

const DAYS := [0, 1, 3, 7, 16, 35]
static var path: String = "user://progress.json"
static var data: Dictionary = {}

static func defaults() -> Dictionary:
	return {"v": 1, "level": 1, "mode": "mem", "subj": {}, "mp": {}, "sr": {}, "owned": [],
		"sound": true, "vib": true, "theme": "light"}

static func load_data() -> void:
	data = defaults()
	if FileAccess.file_exists(path):
		var j = JSON.parse_string(FileAccess.get_file_as_string(path))
		if j is Dictionary:
			for k in j:
				data[k] = j[k]

static func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))

static func level() -> int:
	return maxi(1, int(data["level"]))

static func subj_level(id: String) -> int:
	return maxi(1, int((data["subj"] as Dictionary).get(id, 1)))

## 0 nueva · 1 aprendiendo · 2 dominada
static func stage(n: int) -> int:
	return 2 if n >= 3 else (1 if n >= 1 else 0)

static func pair_stage(pair_id: String) -> int:
	return stage(int((data["mp"] as Dictionary).get(pair_id, 0)))

# ---------- Repaso espaciado ----------
# `sr[id]` = {"b": caja 0-5, "d": fecha del próximo repaso (segundos unix)}.

## Pendiente de repaso: ya se practicó y su fecha venció.
static func is_due(pair_id: String, now: int = 0) -> bool:
	var entry = (data["sr"] as Dictionary).get(pair_id, null)
	if entry == null:
		return false
	var when: int = int((entry as Dictionary).get("d", 0))
	return when <= (now if now > 0 else int(Time.get_unix_time_from_system()))

## Pareja que aún no se practicó nunca.
static func is_new(pair_id: String) -> bool:
	return not (data["sr"] as Dictionary).has(pair_id)

## Fecha de repaso (0 si no hay calendario): ordena las más atrasadas primero.
static func due_date(pair_id: String) -> int:
	return int(((data["sr"] as Dictionary).get(pair_id, {}) as Dictionary).get("d", 0))

## Registra el resultado de una pareja: dominio (solo si fue limpia) y caja de repaso (Leitner).
static func record(pair_id: String, clean: bool) -> void:
	var mp: Dictionary = data["mp"]
	var sr: Dictionary = data["sr"]
	if clean:
		mp[pair_id] = int(mp.get(pair_id, 0)) + 1
	var cur: Dictionary = sr.get(pair_id, {"b": 0, "d": 0})
	var b: int = int(cur["b"])
	b = mini(5, b + 1) if clean else maxi(0, b - 1)
	sr[pair_id] = {"b": b, "d": int(Time.get_unix_time_from_system()) + int(DAYS[b]) * 86400}
	save()

static func reset() -> void:
	data["level"] = 1
	data["subj"] = {}
	data["mp"] = {}
	data["sr"] = {}
	save()
