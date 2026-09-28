extends SceneTree
## Behavioral contract for runtime-generated, progressively more tangled puzzles.

const Puzzle = preload("res://scripts/puzzle.gd")
const Solver = preload("res://scripts/hint_solver.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

## Equal colors sitting directly on each other at the start.
func pairs(state: Array) -> int:
	var result: int = 0
	for pocket: Array in state:
		for i: int in range(1, pocket.size()):
			if pocket[i] == pocket[i - 1]:
				result += 1
	return result

func _initialize() -> void:
	# A script error would otherwise leave the headless run hanging.
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("Generator checks timed out")
		quit(1))
	check(ResourceLoader.exists("res://scripts/level_generator.gd"), "A runtime generator supplies levels beyond the fixed catalog")
	if failures:
		_finish()
		return
	var generator: RefCounted = load("res://scripts/level_generator.gd").new()
	for index: int in [0, 1, 2, 3, 4, 5, 6, 8, 16, 100]:
		var level: Dictionary = generator.generate(index)
		var expected_pockets: int = mini(12, 6 + (index / 2) * 2)
		if index == 0:
			check(not _can_finish_in_two(level["pockets"]), "The opening requires more than two obvious matches")
		check(level["pockets"].size() == expected_pockets, "Level %d grows the playable grid with its color count" % (index + 1))
		check(level["layout"]["wells"].size() == expected_pockets, "Visible holes match the playable grid at level %d" % (index + 1))
		check(level["pockets"].filter(func(pocket: Array) -> bool: return pocket.is_empty()).size() >= 2, "Every grid keeps at least two sorting buffers")
	if failures:
		_finish()
		return
	_check_opening_progression(generator)
	if failures:
		_finish()
		return
	check(generator.has_method("measure_difficulty"), "Difficulty is measured from a board under the current movement rules")
	if not generator.has_method("measure_difficulty"):
		_finish()
		return
	var open: Dictionary = generator.measure_difficulty([[0], [1], [2]], [])
	check(open["legal_moves"] == 6 and open["cross_color_moves"] == 6, "Every different-colored destination with room contributes to mobility")
	var compact: Array = [[0, 0, 1], [0, 1, 1], [0, 1]]
	var route: Array = [[0, 1], [0, 2], [1, 0], [2, 1], [2, 0], [1, 2]]
	var crowded: Dictionary = generator.measure_difficulty(compact, route)
	var roomy: Array = compact.duplicate(true)
	roomy.append([])
	check(generator.measure_difficulty(roomy, route)["score"] < crowded["score"], "Extra buffer space lowers estimated difficulty for the same sorting task")
	check(generator.measure_difficulty([[0, 0, 0, 0], []], [])["score"] == 0, "A solved board has no remaining difficulty")
	check(generator.difficulty(40)["target_score"] > generator.difficulty(20)["target_score"], "Later levels target more measured difficulty after the board reaches full size")
	var previous_pairs: int = 1000
	var previous_groups: int = 0
	var slowest: int = 0
	for index: int in 80:
		var started: int = Time.get_ticks_msec()
		var generated: Dictionary = generator.generate(index, 14921)
		slowest = maxi(slowest, Time.get_ticks_msec() - started)
		var profile: Dictionary = generated["difficulty"]
		var measured: Dictionary = generator.measure_difficulty(generated["pockets"], generated["solution"])
		check(profile["score"] == measured["score"] and profile["name"] == measured["name"], "Displayed difficulty describes the actual generated board %d" % index)
		check(profile["colors"] == mini(6, 2 + index / 2), "One new color is introduced every two levels (%d)" % (index + 1))
		check(profile["pairs"] <= previous_pairs, "Allowed equal neighbors never increase at level %d" % (index + 1))
		previous_pairs = profile["pairs"]
		check(profile["groups"] >= previous_groups, "Boards never get emptier as levels advance (%d)" % (index + 1))
		previous_groups = profile["groups"]
		_verify(generated, index)
		check(generated == generator.generate(index, 14921), "Level and campaign seed reproduce the same puzzle %d" % index)
	check(slowest < 1500, "Dealing and certifying a level is quick enough for level loads (%d ms)" % slowest)
	var first: Dictionary = generator.generate(0, 14921)
	check(first["difficulty"]["pairs"] >= 2 and pairs(first["pockets"]) >= 2, "Early levels are eased by a few equal neighbors")
	check(generator.generate(12, 14921)["difficulty"]["pairs"] == 0, "Later levels have no equal neighbors at all")
	check(first["difficulty"]["groups"] == 2, "The first level has only two groups to assemble")
	check(generator.generate(8, 14921)["difficulty"]["groups"] == 6, "Level 9 introduces the sixth color before adding crowding")
	check(generator.generate(16, 14921)["difficulty"]["groups"] == 10, "The board reaches full occupancy at level 17")
	check(_effort(generator, [0, 1, 2]) * 2 < _effort(generator, [30, 31, 32]), "Early levels are measurably easier with unrestricted color moves")
	check(_effort(generator, [24, 25, 26]) < _effort(generator, [50, 51, 52]), "Measured difficulty continues growing after blob counts and equal neighbors stop changing")
	var variations: Dictionary = {}
	for seed_value: int in [1, 2, 3, 17, 999, 54321]:
		for index: int in [0, 8, 16, 24, 32, 39, 100, 9999]:
			var generated: Dictionary = generator.generate(index, seed_value)
			_verify(generated, index)
			if index == 39:
				variations[Puzzle.state_key(generated["pockets"])] = true
	check(variations.size() == 6, "Different campaign seeds produce different expert boards")
	var changed: Dictionary = generator.generate(0, 14921)
	changed["pockets"][0].clear()
	check(generator.generate(0, 14921) == first, "Mutating a returned board cannot corrupt future generation")
	_finish()

func _verify(generated: Dictionary, index: int) -> void:
	var state: Array = generated["pockets"].duplicate(true)
	check(Puzzle.valid_layout(state), "Generated board has valid pockets at %d" % index)
	var inventory: Array[int] = Puzzle.inventory(state)
	check(inventory.all(func(count: int) -> bool: return count % Puzzle.CAPACITY == 0), "Present colors come in complete groups at %d" % index)
	check(inventory.filter(func(count: int) -> bool: return count > 0).size() == generated["difficulty"]["colors"], "Actual color count matches the difficulty profile at %d" % index)
	check(inventory.reduce(func(total: int, count: int) -> int: return total + count, 0) == generated["difficulty"]["groups"] * Puzzle.CAPACITY, "Blob count matches the level's group count at %d" % index)
	check(not Puzzle.solved(state), "Generated level starts unsolved at %d" % index)
	check(pairs(state) == generated["difficulty"]["pairs"], "Equal neighbors match the level's allowance at %d" % index)
	for pocket: Array in state:
		check(not Puzzle.is_complete(pocket), "No pocket starts already finished at %d" % index)
		var counts: Dictionary = {}
		for color: int in pocket:
			counts[color] = int(counts.get(color, 0)) + 1
		check(counts.values().all(func(count: int) -> bool: return count <= 2), "Blobs are spread out: at most two of a color per pocket at %d" % index)
	for move: Array in generated["solution"]:
		check(Puzzle.apply_to(state, int(move[0]), int(move[1])) > 0, "Certificate uses legal game moves at %d" % index)
	check(Puzzle.solved(state), "Every generated board has a verified route to completion at %d" % index)
	var solver: BlobbleHintSolver = Solver.new()
	solver.register_level(generated["pockets"], generated["solution"])
	var hint: Vector2i = solver.get_hint(generated["pockets"])
	check(Puzzle.transfer_size(generated["pockets"], hint.x, hint.y) > 0, "Generated certificate supports the hint system")

## Keep the opening readable, but remove the two-move win and advance sooner.
func _check_opening_progression(generator: RefCounted) -> void:
	for seed_value: int in [14921, 1, 17, 999, 54321]:
		for index: int in 2:
			var level: Dictionary = generator.generate(index, seed_value)
			var inventory: Array[int] = Puzzle.inventory(level["pockets"])
			check(inventory.filter(func(count: int) -> bool: return count > 0).size() == 2, "The first two levels introduce sorting with two colors")
			check(level["pockets"].filter(func(pocket: Array) -> bool: return not pocket.is_empty()).size() == 4, "The opening keeps attention on four occupied pockets")
			check(not _can_finish_in_two(level["pockets"]), "Early puzzles need more than two moves across campaign seeds")
			check(level["solution"].size() <= 8, "The opening remains approachable with a solution of at most eight moves")
			check(pairs(level["pockets"]) == (2 if index == 0 else 0), "Pre-matched pairs are removed after the first level")
	var previous: float = -1.0
	for band: Array in [[0, 1], [2, 3], [4, 5], [6, 7], [8, 9], [12, 13], [16, 17]]:
		var effort: float = _effort(generator, band)
		check(effort > previous, "Solving effort increases across each introduction and crowding stage")
		previous = effort

## Exhaustively check shallow wins, rather than trusting certificate length.
func _can_finish_in_two(state: Array, remaining: int = 2) -> bool:
	if Puzzle.solved(state):
		return true
	if remaining == 0:
		return false
	for source: int in state.size():
		for target: int in state.size():
			if Puzzle.transfer_size(state, source, target) == 0:
				continue
			var next: Array = state.duplicate(true)
			Puzzle.apply_to(next, source, target)
			if _can_finish_in_two(next, remaining - 1):
				return true
	return false

## Average board difficulty under the current movement rules across a few campaigns.
func _effort(generator: RefCounted, levels: Array) -> float:
	var total: int = 0
	var runs: int = 0
	for index: int in levels:
		for seed_value: int in [1, 2, 3, 4]:
			total += int(generator.generate(index, seed_value)["difficulty"]["score"])
			runs += 1
	return total / float(runs)

func _finish() -> void:
	print("Generator checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
