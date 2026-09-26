extends SceneTree
## Checks that level difficulty follows the design in README.md "Levels":
##   1. the parameter table (colors, bottle size, rules, candidates) at every boundary
##   2. tier names at every boundary
##   3. every generated level obeys its tier's rules
##   4. difficulty really ramps: each tier needs longer solutions and at least as much
##      solver search as the tier before it
##   5. "pick the hardest candidate" beats a plain random layout once it has choices
## Everything is seeded, so results are deterministic.
## Run: godot --headless --path . -s res://tests/test_difficulty.gd -- [last_level]

const TIERS := ["Easy", "Medium", "Hard", "Expert", "Master"]
## Random layouts per level for the step-5 baseline.
const BASELINE_SAMPLES := 6
## Below this many candidates (and on small boards, where the solver never has to
## backtrack) there is little to choose from, so selection isn't checked there.
const SELECTION_MIN_CANDIDATES := 6

var failures: Array[String] = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var last := int(args[0]) if args.size() > 0 else 120
	_check_params()
	_check_tier_names()
	_check_determinism()
	var stats := _check_levels(1, last)
	_check_ramp(stats)
	_check_candidate_selection(stats)
	print("")
	for f in failures:
		print("FAIL: " + f)
	print("%s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)


# ---------------------------------------------------------------- 1. table

func _check_params() -> void:
	# [level, colors, capacity, no_adjacent, candidates]
	var table := [
		[1, 3, 4, false, 1],
		[4, 3, 4, false, 1],
		[5, 4, 4, false, 2],     # +1 color every 4 levels
		[6, 4, 4, true, 2],      # no equal colors stacked from level 6
		[9, 5, 4, true, 2],
		[44, 13, 4, true, 8],
		[45, 14, 4, true, 8],    # all 14 colors reached
		[46, 14, 4, true, 8],
		[80, 14, 4, true, 8],
		[81, 10, 5, true, 6],    # taller bottles
		[88, 10, 5, true, 6],
		[89, 11, 5, true, 6],
		[105, 13, 5, true, 6],
		[500, 13, 5, true, 6],   # capped
	]
	for row: Array in table:
		var p := LevelGenerator.params_for(row[0])
		var got := [row[0], p.colors, p.capacity, p.no_adjacent, p.candidates]
		_expect(got == row, "params_for(%d): expected %s, got %s" % [row[0], row, got])
		_expect(p.empties == 2, "params_for(%d): expected 2 empty bottles" % row[0])
	# Out-of-range levels behave like level 1.
	_expect(LevelGenerator.params_for(0) == LevelGenerator.params_for(1), "params_for(0) != level 1")
	_expect(LevelGenerator.params_for(-3) == LevelGenerator.params_for(1), "params_for(-3) != level 1")
	# Parameters never get easier from one level to the next (bottle size may
	# trade some colors for taller bottles, but only when capacity goes up).
	for level in range(1, 300):
		var a := LevelGenerator.params_for(level)
		var b := LevelGenerator.params_for(level + 1)
		_expect(b.capacity >= a.capacity, "capacity drops at level %d" % (level + 1))
		_expect(b.no_adjacent or not a.no_adjacent, "no-adjacent rule turns off at level %d" % (level + 1))
		if b.capacity == a.capacity:
			_expect(b.colors >= a.colors, "colors drop at level %d" % (level + 1))
			_expect(b.candidates >= a.candidates, "candidates drop at level %d" % (level + 1))


# ---------------------------------------------------------------- 2. tier names

func _check_tier_names() -> void:
	var expected := {1: "Easy", 8: "Easy", 9: "Medium", 20: "Medium", 21: "Hard", 40: "Hard",
		41: "Expert", 80: "Expert", 81: "Master", 1000: "Master"}
	for level: int in expected:
		var got := LevelGenerator.difficulty_name(level)
		_expect(got == expected[level], "difficulty_name(%d): expected %s, got %s" % [
			level, expected[level], got])


func _check_determinism() -> void:
	for level in [1, 37, 90]:
		var a := LevelGenerator.generate(level)
		var b := LevelGenerator.generate(level)
		_expect(a.state == b.state, "level %d is not deterministic" % level)


# ---------------------------------------------------------------- 3. level rules

## Generates every level, checks its rules and returns per-tier stats:
## {tier: {nodes, moves, baseline, picked, picked_baseline}}; "picked" only counts
## levels whose generator chooses from SELECTION_MIN_CANDIDATES or more.
func _check_levels(first: int, last: int) -> Dictionary:
	var stats := {}
	for t: String in TIERS:
		stats[t] = {nodes = [], moves = [], baseline = [], picked = [], picked_baseline = []}
	for level in range(first, last + 1):
		var p := LevelGenerator.params_for(level)
		var d := LevelGenerator.generate(level)
		var state: Array = d.state
		var cap: int = d.capacity
		var where := "level %d" % level
		_expect(cap == p.capacity, "%s: capacity %d, expected %d" % [where, cap, p.capacity])
		_expect(state.size() == p.colors + p.empties, "%s: %d bottles, expected %d" % [
			where, state.size(), p.colors + p.empties])
		var counts := {}
		var empties := 0
		for b: String in state:
			if b.is_empty():
				empties += 1
				continue
			_expect(b.length() == cap, "%s: bottle '%s' not full" % [where, b])
			# A bottle that starts (nearly) finished makes the level too easy.
			_expect(WaterSolver.top_run(b) < cap - 1, "%s: bottle '%s' starts nearly finished" % [where, b])
			if p.no_adjacent:
				_expect(not LevelGenerator._has_adjacent_pair(b),
					"%s: bottle '%s' stacks equal colors (not allowed from level 6)" % [where, b])
			for i in b.length():
				counts[b[i]] = counts.get(b[i], 0) + 1
		_expect(empties == p.empties, "%s: %d empty bottles, expected %d" % [where, empties, p.empties])
		_expect(counts.size() == p.colors, "%s: %d colors, expected %d" % [where, counts.size(), p.colors])
		for c: String in counts:
			_expect(counts[c] == cap, "%s: color %s has %d units" % [where, c, counts[c]])
		_expect(not d.solution.is_empty() and _solves(state, d.solution, cap), "%s: solution invalid" % where)

		var s: Dictionary = stats[LevelGenerator.difficulty_name(level)]
		s.nodes.append(d.nodes)
		s.moves.append(d.solution.size())
		var base := _baseline_nodes(level, p)
		s.baseline.append(base)
		if p.candidates >= SELECTION_MIN_CANDIDATES:
			s.picked.append(d.nodes)
			s.picked_baseline.append(base)
	return stats


func _solves(state: Array, solution: Array, cap: int) -> bool:
	for m: Array in solution:
		var amt := WaterSolver.pour_amount(state, m[0], m[1], cap)
		if amt == 0 or amt != m[2]:
			return false
		state = WaterSolver.apply_move(state, m[0], m[1], amt)
	return WaterSolver.is_solved(state, cap)


## Median solver effort of plain random layouts with the same parameters
## (what the level would be without the hardest-candidate selection).
func _baseline_nodes(level: int, p: Dictionary) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("baseline-%d" % level)
	var nodes := []
	for k in BASELINE_SAMPLES:
		var st := LevelGenerator._random_state(rng, p.colors, p.empties, p.capacity, p.no_adjacent)
		var res := WaterSolver.solve(st, p.capacity, LevelGenerator.NODE_BUDGET)
		if res.solved:
			nodes.append(res.nodes)
	return _median(nodes)


# ---------------------------------------------------------------- 4. ramp

func _check_ramp(stats: Dictionary) -> void:
	print("tier     levels  median moves  median search  baseline search")
	var prev := ""
	for t: String in TIERS:
		var s: Dictionary = stats[t]
		if s.moves.is_empty():
			continue
		print("%-7s  %6d  %12d  %13d  %15d" % [t, s.moves.size(), _median(s.moves), _median(s.nodes),
			_median(s.baseline)])
		if prev != "":
			var a: Dictionary = stats[prev]
			_expect(_median(s.moves) > _median(a.moves), "%s levels need no more moves than %s (median %d vs %d)" % [
				t, prev, _median(s.moves), _median(a.moves)])
			_expect(_median(s.nodes) >= _median(a.nodes), "%s levels need less solver search than %s (median %d vs %d)" % [
				t, prev, _median(s.nodes), _median(a.nodes)])
		prev = t


# ---------------------------------------------------------------- 5. selection

func _check_candidate_selection(stats: Dictionary) -> void:
	for t: String in TIERS:
		var s: Dictionary = stats[t]
		if s.picked.size() < 5:
			continue
		var chosen := _median(s.picked)
		var base := _median(s.picked_baseline)
		_expect(chosen >= base * 1.5, "%s: hardest-candidate selection barely helps (median search %d vs random %d)" % [
			t, chosen, base])


static func _median(a: Array) -> int:
	if a.is_empty():
		return 0
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]
