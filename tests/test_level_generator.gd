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
	var previous_pairs: int = 1000
	var slowest: int = 0
	for index: int in 80:
		var started: int = Time.get_ticks_msec()
		var generated: Dictionary = generator.generate(index, 14921)
		slowest = maxi(slowest, Time.get_ticks_msec() - started)
		var profile: Dictionary = generated["difficulty"]
		check(profile["colors"] == 6, "Every color is in play from the first level (%d)" % (index + 1))
		check(profile["pairs"] <= previous_pairs, "Allowed equal neighbors never increase at level %d" % (index + 1))
		previous_pairs = profile["pairs"]
		_verify(generated, index)
		check(generated == generator.generate(index, 14921), "Level and campaign seed reproduce the same puzzle %d" % index)
	check(slowest < 1500, "Dealing and certifying a level is quick enough for level loads (%d ms)" % slowest)
	var first: Dictionary = generator.generate(0, 14921)
	check(first["difficulty"]["pairs"] >= 2 and pairs(first["pockets"]) >= 2, "Early levels are eased by a few equal neighbors")
	check(generator.generate(12, 14921)["difficulty"]["pairs"] == 0, "Later levels have no equal neighbors at all")
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
	check(Puzzle.valid_layout(state), "Generated board has twelve valid pockets at %d" % index)
	check(Puzzle.inventory(state) == [4, 8, 8, 8, 8, 4], "Generated board preserves balanced color counts at %d" % index)
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

func _finish() -> void:
	print("Generator checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
