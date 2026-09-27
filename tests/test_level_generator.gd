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

func boundaries(state: Array) -> int:
	var result: int = 0
	for pocket: Array in state:
		for i: int in range(1, pocket.size()):
			if pocket[i] != pocket[i - 1]:
				result += 1
	return result

func _initialize() -> void:
	check(ResourceLoader.exists("res://scripts/level_generator.gd"), "A runtime generator supplies levels beyond the fixed catalog")
	if failures:
		_finish()
		return
	var generator: RefCounted = load("res://scripts/level_generator.gd").new()
	var previous_target: int = 0
	var previous_colors: int = 0
	for index: int in 80:
		var generated: Dictionary = generator.generate(index, 14921)
		var profile: Dictionary = generated["difficulty"]
		check(profile["boundaries"] >= previous_target, "Tangle requirement never decreases at level %d" % (index + 1))
		check(profile["colors"] >= previous_colors, "Active palette never shrinks at level %d" % (index + 1))
		previous_target = profile["boundaries"]
		previous_colors = profile["colors"]
		_verify(generated, index)
		check(generated == generator.generate(index, 14921), "Level and campaign seed reproduce the same puzzle %d" % index)
	check(previous_colors == 6 and previous_target >= 20, "Progression reaches six-color expert puzzles")
	var first: Dictionary = generator.generate(0, 14921)
	check(first["difficulty"]["colors"] == 2 and boundaries(first["pockets"]) <= 2, "The opening puzzle is a gentle two-color introduction")
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
	check(boundaries(state) == generated["difficulty"]["boundaries"], "Actual board meets the advertised tangle requirement at %d" % index)
	var active_colors: Dictionary = {}
	for pocket: Array in state:
		if not Puzzle.is_complete(pocket):
			for color: int in pocket:
				active_colors[color] = true
	check(active_colors.size() == generated["difficulty"]["colors"], "Every advertised color actually needs sorting at %d" % index)
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
