extends SceneTree

const Puzzle = preload("res://scripts/puzzle.gd")
const Solver = preload("res://scripts/hint_solver.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	# No empty pockets and no solution using only matching-color transfers.
	var mixed_start: Array = [[0, 0, 1], [0, 1, 1], [0, 1]]
	var mixed_route: Array[Vector2i] = Solver.new().solve(mixed_start, 4000)
	check(not mixed_route.is_empty(), "Solver can escape a board requiring a cross-color move")
	var mixed_state: Array = mixed_start.duplicate(true)
	var used_cross_color: bool = false
	for move: Vector2i in mixed_route:
		used_cross_color = used_cross_color or (not mixed_state[move.y].is_empty() and mixed_state[move.x].back() != mixed_state[move.y].back())
		check(Puzzle.apply_to(mixed_state, move.x, move.y) > 0, "Cross-color solution uses legal moves")
	check(used_cross_color and Puzzle.solved(mixed_state), "Cross-color solution reaches a sorted board")
	var puzzle: BlobblePuzzle = Puzzle.new()
	for color: int in Puzzle.COLOR_COUNT:
		for destination_color: int in Puzzle.COLOR_COUNT:
			var bottom_color: int = (color + 1) % Puzzle.COLOR_COUNT
			puzzle.setup([[bottom_color, color, color], [destination_color], [], [], [], [], [], [], [], [], [], []])
			check(puzzle.pour(0, 1) == 2, "Every top color can move onto every destination color")
			check(puzzle.pockets[0] == [bottom_color] and puzzle.pockets[1] == [destination_color, color, color], "Only the top group moves and destination colors are preserved")
			check(puzzle.moves == 1 and puzzle.undo() and puzzle.pockets == puzzle.initial, "Undo restores a move onto any color")
	puzzle.setup([[1, 1], [2], [], [1, 1, 1], [], [], [], [], [], [], [], []])
	check(puzzle.pour(2, 1) == 0, "Empty sources cannot move")
	check(puzzle.moves == 0 and puzzle.history.is_empty(), "Invalid moves never mutate history")
	check(puzzle.pour(0, 3) == 1, "Transfer is limited by destination capacity")
	check(puzzle.pockets[0] == [1] and Puzzle.is_complete(puzzle.pockets[3]), "Partial group transfer preserves color")
	check(puzzle.pour(1, 3) == 0, "Full pockets reject every color")
	check(puzzle.undo() and puzzle.pockets == puzzle.initial, "Undo restores the exact board")
	check(puzzle.moves == 0, "Undo restores the move count")
	check(puzzle.pour(0, 2) == 2, "Contiguous group moves to an empty pocket")
	check(puzzle.pour(2, 2) == 0, "Self moves rejected")
	check(Puzzle.transfer_size(puzzle.pockets, -1, 2) == 0, "Invalid index rejected")
	puzzle.restart()
	check(puzzle.pockets == puzzle.initial and puzzle.history.is_empty(), "Restart clears history")
	check(Puzzle.transfer_size([[0, 0, 0, 0], [1, 2, 3]], 0, 1) == 1, "Completed groups can move onto another color up to available capacity")
	check(not Puzzle.valid_layout([[0]]), "Invalid pocket count rejected")
	var bad: Array = puzzle.initial.duplicate(true)
	bad[0] = [7]
	check(not Puzzle.valid_layout(bad), "Invalid color rejected")
	bad[0] = [1.5]
	check(not Puzzle.valid_layout(bad), "Fractional color rejected")
	bad[0] = [0, 0, 0, 0, 0]
	check(not Puzzle.valid_layout(bad), "Overfull pocket rejected")
	var levels: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels.json"))
	check(levels.size() == 30, "Thirty levels included")
	for index: int in levels.size():
		var level: Dictionary = levels[index]
		puzzle.setup(level["pockets"])
		check(Puzzle.valid_layout(puzzle.pockets), "Valid layout %d" % index)
		check(not Puzzle.solved(puzzle.pockets), "Level starts unsolved %d" % index)
		var inventory: Array[int] = Puzzle.inventory(puzzle.pockets)
		check(inventory == [4, 8, 8, 8, 8, 4], "Balanced inventory %d" % index)
		var solver: BlobbleHintSolver = Solver.new()
		solver.register_level(level["pockets"], level["solution"])
		var visited: Dictionary = {}
		while not Puzzle.solved(puzzle.pockets):
			var key: String = Puzzle.state_key(puzzle.pockets)
			if visited.has(key):
				check(false, "Hint certificate must not loop %d" % index)
				break
			visited[key] = true
			var hint: Vector2i = solver.get_hint(puzzle.pockets)
			check(hint.x >= 0 and puzzle.pour(hint.x, hint.y) > 0, "Hint is a legal move %d" % index)
			check(Puzzle.inventory(puzzle.pockets) == inventory, "Every move conserves all blobs")
			if hint.x < 0:
				break
		check(Puzzle.solved(puzzle.pockets) and puzzle.completed_count() == 10, "Level can be won %d" % index)
		while not puzzle.history.is_empty():
			puzzle.undo()
		check(puzzle.pockets == puzzle.initial, "Full undo sequence restores starting layout %d" % index)
	print("Puzzle checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
