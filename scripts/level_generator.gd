class_name LevelGenerator
extends RefCounted
## Deterministic procedural levels: the same level number always produces the
## same puzzle. Every level is verified solvable by WaterSolver before use.
##
## Difficulty ramps through:
##   * more colors (3 -> 14)
##   * taller 5-unit bottles from level 81
##   * no two equal colors stacked together (from level 6)
##   * picking the hardest of several solvable candidates, measured by how much
##     searching the solver needed (more candidates on later levels)

const CAPACITY := 4
const MAX_COLORS := 14
const EMPTY_BOTTLES := 2
const NODE_BUDGET := 25000


static func params_for(level: int) -> Dictionary:
	level = maxi(level, 1)
	if level > 80:
		return {
			colors = clampi(10 + (level - 81) / 8, 10, 13),
			empties = EMPTY_BOTTLES,
			capacity = 5,
			no_adjacent = true,
			candidates = 6,
		}
	return {
		colors = clampi(3 + (level - 1) / 4, 3, MAX_COLORS),
		empties = EMPTY_BOTTLES,
		capacity = CAPACITY,
		no_adjacent = level >= 6,
		candidates = clampi(1 + level / 5, 1, 8),
	}


static func difficulty_name(level: int) -> String:
	if level <= 8:
		return "Easy"
	if level <= 20:
		return "Medium"
	if level <= 40:
		return "Hard"
	if level <= 80:
		return "Expert"
	return "Master"


## Returns {state: Array[String], capacity: int, colors: int, solution: Array, nodes: int}.
static func generate(level: int) -> Dictionary:
	var p := params_for(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("filler-time-level-%d" % level)

	var best: Dictionary = {}
	var found := 0
	var attempts := 0
	while found < p.candidates and attempts < 300:
		attempts += 1
		var st := _random_state(rng, p.colors, p.empties, p.capacity, p.no_adjacent and attempts < 200)
		var res := WaterSolver.solve(st, p.capacity, NODE_BUDGET)
		if not res.solved:
			continue
		found += 1
		# Search effort is the main difficulty signal; solution length breaks ties.
		var score: int = res.nodes * 4 + res.moves.size()
		if best.is_empty() or score > best.score:
			best = {state = st, solution = res.moves, nodes = res.nodes, score = score}

	if best.is_empty():
		# Practically unreachable; fall back to a trivially solvable layout.
		var st := []
		for c in p.colors:
			st.append(char(65 + c).repeat(p.capacity))
		for e in p.empties:
			st.append("")
		best = {state = st, solution = [], nodes = 0}

	return {
		state = best.state,
		capacity = p.capacity,
		colors = p.colors,
		solution = best.solution,
		nodes = best.nodes,
	}


static func _random_state(rng: RandomNumberGenerator, colors: int, empties: int,
		capacity: int, no_adjacent: bool) -> Array:
	var pool := PackedInt32Array()
	for c in colors:
		for k in capacity:
			pool.append(c)

	var state := []
	for tries in 60:
		# Fisher-Yates with our seeded rng.
		for i in range(pool.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := pool[i]
			pool[i] = pool[j]
			pool[j] = t
		state.clear()
		var ok := true
		for b in colors:
			var s := ""
			for k in capacity:
				s += char(65 + pool[b * capacity + k])
			if WaterSolver.top_run(s) >= capacity - 1:
				ok = false # already (nearly) finished bottle -> too easy
			if no_adjacent and _has_adjacent_pair(s):
				ok = false
			state.append(s)
		if ok:
			break
	for e in empties:
		state.append("")
	return state


static func _has_adjacent_pair(s: String) -> bool:
	for i in range(1, s.length()):
		if s.unicode_at(i) == s.unicode_at(i - 1):
			return true
	return false
