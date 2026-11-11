class_name Levels
extends RefCounted
## Niveles: recorrido general (mezcla de materias) y niveles propios de cada materia.

const PAIRS: Array[int] = [3, 4, 5, 6, 6, 8, 8, 10, 10, 12, 12, 14, 14, 16, 16, 18, 18, 20, 20, 24]

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
	var rest: Array = pool.filter(func(x): return x != first)
	rest.shuffle()
	var want: int = mini(PAIRS[clampi(n, 1, PAIRS.size()) - 1], pool.size())
	return [first] + rest.slice(0, want - 1)

static func pick_subject(pack: Dictionary, n: int) -> Array:
	var all: Array = (pack["pairs"] as Array).duplicate()
	all.shuffle()
	var steps: Array = steps_for(pack)
	return all.slice(0, int(steps[clampi(n, 1, steps.size()) - 1]))
