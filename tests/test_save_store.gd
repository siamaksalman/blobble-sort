extends SceneTree
## Persistence tests use a disposable file, never the player's save.

const Puzzle = preload("res://scripts/puzzle.gd")
const Store = preload("res://scripts/save_store.gd")
const TEST_PATH: String = "res://tests/.tmp/save_store.json"
var checks: int = 0
var failures: int = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	var store: BlobbleSaveStore = Store.new()
	check(store.get("path") != null, "Save storage accepts an isolated file path")
	if failures > 0:
		_finish()
		return
	store.set("path", TEST_PATH)
	DirAccess.make_dir_recursive_absolute("res://tests/.tmp")
	var levels: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels.json"))
	var puzzle: BlobblePuzzle = Puzzle.new()
	puzzle.setup(levels[0]["pockets"])
	var move: Array = levels[0]["solution"][0]
	puzzle.pour(int(move[0]), int(move[1]))
	store.sound = false
	store.symbols = true
	store.unlocked = 3
	store.best = {"0": 24}
	store.write_save(puzzle)
	var loaded: BlobbleSaveStore = Store.new()
	loaded.set("path", TEST_PATH)
	loaded.read_save(levels)
	check(loaded.saved_board == puzzle.pockets, "Save round trip preserves the moved board")
	check(loaded.saved_moves == 1, "Save round trip preserves the move count")
	check(loaded.saved_history == puzzle.history, "Save round trip preserves undo history")
	check(not loaded.sound and loaded.symbols, "Save round trip preserves preferences")
	check(loaded.unlocked == 3 and loaded.best.size() == 1 and int(loaded.best.get("0", -1)) == 24, "Save round trip preserves progress")
	check(not FileAccess.file_exists(TEST_PATH + ".tmp"), "Successful replacement leaves no temporary save")
	loaded.read_save(levels)
	check(loaded.saved_history == puzzle.history, "Reading the same save twice does not duplicate undo history")
	# A rejected replacement must not retain a previous session's board or history.
	var invalid: Dictionary = {"version": 1, "level": 0, "board": []}
	_write_fixture(invalid)
	loaded.read_save(levels)
	check(loaded.saved_board.is_empty(), "An invalid board clears previously loaded board data")
	check(loaded.saved_history.is_empty(), "An invalid board clears previously loaded undo history")
	check(loaded.saved_moves == 0, "An invalid board clears previously loaded move count")
	DirAccess.remove_absolute(TEST_PATH)
	_finish()

func _write_fixture(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _finish() -> void:
	print("Save checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
