class_name Levels
extends RefCounted
## Niveles: recorrido general (mezcla de materias) y niveles propios de cada materia.
## La selección de parejas mezcla el repaso espaciado: primero lo que toca repasar.

const PAIRS: Array[int] = [3, 4, 5, 6, 6, 8, 8, 10, 10, 12, 12, 14, 14, 16, 16, 18, 18, 20, 20, 24]
const DUE_SHARE := 0.6   # máximo de parejas pendientes por nivel

static func max_level() -> int:
	return PAIRS.size()

static func is_open(pack: Dictionary) -> bool:
	return not bool(pack.get("premium", false)) or (Progress.data["owned"] as Array).has(pack["id"])

## Tamaños de nivel de una materia: los de PAIRS que caben en el paquete, sin repetir.
static func steps_for(pack: Dictionary) -> Array:
	var out: Array = []
	for n in PAIRS:
		if n <= (pack["pairs"] as Array).size() and not out.has(n):
			out.append(n)
	return out

## Arma una sesión de `want` parejas sacadas de `pool`. Hasta el 60 % pueden ser
## pendientes de repaso (las más atrasadas primero); luego entran las nuevas y, si
## falta, el resto. `forced` son parejas que deben estar sí o sí (p. ej. la del
## paquete más reciente en el recorrido general).
static func choose(pool: Array, want: int, forced: Array = []) -> Array:
	var picked: Array = forced.duplicate()
	var budget: int = int(floor(float(want) * DUE_SHARE))
	for pr in picked:
		if Progress.is_due(pr["id"]):
			budget -= 1
	var due: Array = []
	var fresh: Array = []
	var rest: Array = []
	for pr in pool:
		if picked.has(pr):
			continue
		if Progress.is_due(pr["id"]):
			due.append(pr)
		elif Progress.is_new(pr["id"]):
			fresh.append(pr)
		else:
			rest.append(pr)
	due.sort_custom(func(a, b) -> bool: return Progress.due_date(a["id"]) < Progress.due_date(b["id"]))
	var take: int = mini(maxi(budget, 0), due.size())
	for i in take:
		picked.append(due[i])
	fresh.shuffle()
	rest.shuffle()
	var fill: Array = fresh + rest + due.slice(take)
	var i2: int = 0
	while picked.size() < want and i2 < fill.size():
		picked.append(fill[i2])
		i2 += 1
	picked.shuffle()
	return picked

## Recorrido general: paquetes desbloqueados hasta el nivel n; siempre incluye una pareja del más reciente.
static func pick_general(packs: Array, n: int) -> Array:
	var top: int = 0
	var act: Array = []
	for p in packs:
		if int(p["unlock"]) <= n and is_open(p):
			act.append(p)
			top = maxi(top, int(p["unlock"]))
	var pool: Array = []
	var fresh: Array = []
	for p in act:
		for pr in p["pairs"]:
			pool.append(pr)
			if int(p["unlock"]) == top:
				fresh.append(pr)
	if pool.is_empty():
		return []
	var first = fresh.pick_random()
	var want: int = mini(PAIRS[clampi(n, 1, PAIRS.size()) - 1], pool.size())
	return choose(pool, want, [first])

static func pick_subject(pack: Dictionary, n: int) -> Array:
	var steps: Array = steps_for(pack)
	var want: int = int(steps[clampi(n, 1, steps.size()) - 1])
	return choose(pack["pairs"], want)

## Parejas pendientes de repaso de todas las materias abiertas, las más atrasadas primero.
static func due_pairs(packs: Array, limit: int = 0) -> Array:
	var out: Array = []
	for p in packs:
		if not is_open(p):
			continue
		for pr in p["pairs"]:
			if Progress.is_due(pr["id"]):
				out.append(pr)
	out.sort_custom(func(a, b) -> bool: return Progress.due_date(a["id"]) < Progress.due_date(b["id"]))
	return out.slice(0, limit) if limit > 0 else out

## Cuántas parejas del paquete toca repasar.
static func due_count(pack: Dictionary) -> int:
	var n: int = 0
	for pr in pack["pairs"]:
		if Progress.is_due(pr["id"]):
			n += 1
	return n
