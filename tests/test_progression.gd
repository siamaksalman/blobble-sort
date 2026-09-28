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
	var old_generated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	old_generated["generator_version"] = 3
	old_generated["best"] = {"3": 22}
	_write(old_generated)
	restored.read_save()
	check(restored.saved_board.is_empty() and restored.saved_history.is_empty() and restored.saved_moves == 0, "The old difficulty campaign starts a fresh board without stale undo history")
	check(restored.level == 104 and restored.unlocked == 106 and restored.campaign_seed == 54321 and int(restored.best["3"]) == 22, "Difficulty migration retains campaign progress and records")
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
	_check_small_early_board(generator)
	call_deferred("_check_progress_label")

## Early levels hold fewer blobs; saving and the progress count must follow the level, not a full board.
func _check_small_early_board(generator: RefCounted) -> void:
	var early: Dictionary = generator.generate(0, 54321)
	var small: BlobblePuzzle = Puzzle.new()
	small.setup(early["pockets"])
	var first_move: Array = early["solution"][0]
	small.pour(first_move[0], first_move[1])
	var store: BlobbleSaveStore = Store.new()
	store.path = PATH
	store.set("campaign_seed", 54321)
	store.level = 0
	store.legacy_level = false
	store.write_save(small)
	var reloaded: BlobbleSaveStore = Store.new()
	reloaded.path = PATH
	reloaded.call("read_save")
	check(Puzzle.state_key(reloaded.saved_board) == Puzzle.state_key(small.pockets), "A smaller early-level board survives reload")
	check(reloaded.saved_history.size() == 1, "A smaller early-level undo history survives reload")
	var malformed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	malformed["board"].append([])
	_write(malformed)
	reloaded.read_save()
	check(reloaded.saved_board.is_empty(), "Saved boards cannot add extra holes to the current level")
	malformed["board"] = small.pockets
	malformed["history"][0].append([])
	_write(malformed)
	reloaded.read_save()
	check(not reloaded.saved_board.is_empty() and reloaded.saved_history.is_empty(), "Undo history must match the current grid size")

func _check_progress_label() -> void:
	var game: Control = load("res://scripts/game.gd").new()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	var groups: int = 0
	for pocket: Array in game.puzzle.pockets:
		groups += pocket.size()
	groups /= Puzzle.CAPACITY
	check(game._progress_label.text == "0 / %d together" % groups, "Progress counts this level's color groups (%s)" % game._progress_label.text)
	game.queue_free()
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
