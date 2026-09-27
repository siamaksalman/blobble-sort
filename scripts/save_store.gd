class_name BlobbleSaveStore
extends RefCounted

const Puzzle = preload("res://scripts/puzzle.gd")
const Generator = preload("res://scripts/level_generator.gd")
const PATH: String = "user://blobble.json"
var path: String = PATH
var unlocked: int = 1
var level: int = 0
var sound: bool = true
var symbols: bool = false
var best: Dictionary = {}
var saved_board: Array = []
var saved_history: Array = []
var saved_moves: int = 0
var campaign_seed: int = Generator.DEFAULT_SEED
var legacy_level: bool = false
var board_layout: Dictionary = {}

func read_save(legacy_levels: Array = []) -> void:
	saved_board.clear()
	saved_history.clear()
	saved_moves = 0
	board_layout.clear()
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or int(data.get("version", 0)) not in [1, 2]:
		return
	level = maxi(0, int(data.get("level", 0)))
	unlocked = maxi(level + 1, int(data.get("unlocked", 1)))
	campaign_seed = clampi(int(data.get("campaign_seed", Generator.DEFAULT_SEED)), 0, 2147483647)
	legacy_level = int(data["version"]) == 1 or bool(data.get("legacy_level", false))
	if legacy_level:
		if legacy_levels.is_empty():
			legacy_levels = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels.json"))
		level = mini(level, legacy_levels.size() - 1)
	sound = bool(data.get("sound", true))
	symbols = bool(data.get("symbols", false))
	if data.get("best") is Dictionary:
		best = data["best"]
	if data.get("layout") is Dictionary:
		board_layout = data["layout"]
	if not legacy_level and int(data.get("generator_version", 0)) != Generator.VERSION:
		return
	var board: Variant = data.get("board", [])
	# Early generated levels hold fewer blobs, so validate against this level's own deal.
	var expected: Array[int] = Puzzle.inventory(Generator.SOLVED) if legacy_level else Puzzle.inventory(Generator.new().generate(level, campaign_seed)["pockets"])
	if Puzzle.valid_layout(board) and Puzzle.inventory(board) == expected:
		saved_board = board
		saved_moves = maxi(0, int(data.get("moves", 0)))
		var raw_history: Variant = data.get("history", [])
		if raw_history is Array:
			for state: Variant in raw_history:
				if Puzzle.valid_layout(state) and Puzzle.inventory(state) == expected:
					saved_history.append(state)

func write_save(puzzle: BlobblePuzzle) -> void:
	var data: Dictionary = {"version": 2, "level": level, "unlocked": unlocked,
		"campaign_seed": campaign_seed, "generator_version": Generator.VERSION, "legacy_level": legacy_level,
		"layout": board_layout,
		"sound": sound, "symbols": symbols, "best": best,
		"board": puzzle.pockets, "moves": puzzle.moves, "history": puzzle.history}
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)
