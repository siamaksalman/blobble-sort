extends SceneTree
## Generated progression must survive reloads and migrate the original campaign.

const Generator = preload("res://scripts/level_generator.gd")
const Puzzle = preload("res://scripts/puzzle.gd")
const Store = preload("res://scripts/save_store.gd")
const PATH: String = "res://tests/.tmp/progression.json"
var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/.tmp")
	var store: BlobbleSaveStore = Store.new()
	store.path = PATH
	check(store.get("campaign_seed") != null, "Persistence stores the procedural campaign seed")
	if failures:
		_finish()
		return
	store.set("campaign_seed", 54321)
	store.level = 104
	store.unlocked = 106
	var generator: RefCounted = Generator.new()
	var generated: Dictionary = generator.generate(104, 54321)
	check(store.get("board_layout") != null, "Persistence includes the current board geometry")
	if failures:
		_finish()
		return
	store.set("board_layout", generated["layout"])
	var puzzle: BlobblePuzzle = Puzzle.new()
	puzzle.setup(generated["pockets"])
	var move: Array = generated["solution"][0]
	puzzle.pour(move[0], move[1])
	store.write_save(puzzle)
	var restored: BlobbleSaveStore = Store.new()
	restored.path = PATH
	restored.call("read_save")
	check(restored.level == 104 and restored.unlocked == 106, "Progress beyond the old thirty-level cap survives reload")
	check(restored.get("campaign_seed") == 54321, "Reload preserves the campaign seed")
	var restored_layout: Dictionary = restored.get("board_layout")
	check(restored_layout.get("version") == 3 and restored_layout.get("wells", []).size() == 12, "Saved geometry survives reload")
	check(is_equal_approx(restored_layout["wells"][0]["center"][0], generated["layout"]["wells"][0]["center"][0]), "Reload preserves generated pocket coordinates")
	check(Puzzle.state_key(restored.saved_board) == Puzzle.state_key(puzzle.pockets), "Generated board survives reload")
	check(restored.saved_history.size() == 1 and Puzzle.state_key(restored.saved_history[0]) == Puzzle.state_key(puzzle.history[0]), "Generated undo history survives reload")
	check(generator.generate(restored.level, restored.get("campaign_seed"))["pockets"] == puzzle.initial, "Restart after reload reproduces the exact initial puzzle")
	var legacy_levels: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels.json"))
	var legacy: Dictionary = {"version": 1, "level": 7, "unlocked": 12, "board": legacy_levels[7]["pockets"], "moves": 0, "history": [], "sound": false, "symbols": true, "best": {"3": 22}}
	_write(legacy)
	restored.call("read_save")
	check(restored.level == 7 and restored.unlocked == 12, "Migration preserves the legacy level and unlocked progress")
	check(restored.saved_board == legacy["board"] and restored.get("legacy_level") == true, "Migration keeps the in-progress legacy puzzle playable")
	check(not restored.sound and restored.symbols and int(restored.best["3"]) == 22, "Migration preserves preferences and records")
	puzzle.setup(legacy["board"])
	restored.write_save(puzzle)
	var again: BlobbleSaveStore = Store.new()
	again.path = PATH
	again.call("read_save")
	check(again.get("legacy_level") == true and again.saved_board == legacy["board"], "Migrated legacy puzzle remains identifiable on subsequent reloads")
	_finish()

func _write(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _finish() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	print("Progression checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
