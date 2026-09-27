extends SceneTree
## Browser-test helper: solve the actual saved state without touching player files.
const Solver = preload("res://scripts/hint_solver.gd")
const Puzzle = preload("res://scripts/puzzle.gd")

func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1:
		quit(1)
		return
	var state: Variant = JSON.parse_string(arguments[0])
	if not state is Array or not Puzzle.valid_layout(state):
		quit(1)
		return
	var route: Array[Vector2i] = Solver.new().solve(state, 40000)
	var result: Array = []
	for move: Vector2i in route:
		result.append([move.x, move.y])
	print("WEB_ROUTE:", JSON.stringify(result))
	quit()
