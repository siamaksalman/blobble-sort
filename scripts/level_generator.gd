class_name BlobbleLevelGenerator
extends RefCounted
## Deals every color across the pockets, then certifies the deal with a solver search,
## so every level carries a verified solution. Early levels allow a few equal
## neighbors to ease players in; later levels spread every blob apart.

const Puzzle = preload("res://scripts/puzzle.gd")
const Layout = preload("res://scripts/board_layout.gd")
const Solver = preload("res://scripts/hint_solver.gd")
const VERSION: int = 2
const DEFAULT_SEED: int = 14921
## Easing on the first levels: equal neighbors allowed, dropping by one every two levels.
const OPENING_PAIRS: int = 4
const MAX_PER_POCKET: int = 2
const SEARCH_BUDGET: int = 4000
const SOLVED: Array = [[0, 0, 0, 0], [2, 2, 2, 2], [1, 1, 1, 1], [5, 5, 5, 5],
	[3, 3, 3, 3], [4, 4, 4, 4], [1, 1, 1, 1], [], [4, 4, 4, 4], [3, 3, 3, 3], [2, 2, 2, 2], []]

func difficulty(index: int) -> Dictionary:
	index = maxi(index, 0)
	var allowed: int = maxi(0, OPENING_PAIRS - index / 2)
	var names: Array[String] = ["Gentle", "Easy", "Thoughtful", "Tricky", "Expert"]
	var tier: int = 0 if allowed >= 3 else 1 if allowed >= 1 else 2 if index < 20 else 3 if index < 40 else 4
	return {"colors": 6, "pairs": allowed, "name": names[tier]}

func generate(index: int, campaign_seed: int = DEFAULT_SEED) -> Dictionary:
	index = maxi(index, 0)
	var profile: Dictionary = difficulty(index)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = campaign_seed + (index % 1000000000) * 917
	var level: Dictionary = {}
	for attempt: int in 500:
		level = _deal(profile, rng)
		if not level.is_empty():
			break
	assert(not level.is_empty(), "A certified deal is found within the attempt budget")
	level["difficulty"] = profile
	level["index"] = index
	level["generator_version"] = VERSION
	level["layout"] = Layout.new().generate(index, campaign_seed)
	return level

## One spread-out deal with exactly the allowed equal neighbors, if the solver can finish it.
func _deal(profile: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var blobs: Array = []
	var filled: Array[int] = []
	for index: int in SOLVED.size():
		blobs.append_array(SOLVED[index])
		if not SOLVED[index].is_empty():
			filled.append(index)
	var state: Array = []
	for attempt: int in 200:
		_shuffle(blobs, rng)
		state = []
		for index: int in SOLVED.size():
			state.append([])
		for i: int in filled.size():
			state[filled[i]] = blobs.slice(i * Puzzle.CAPACITY, (i + 1) * Puzzle.CAPACITY)
		if _spread(state) and _pairs(state) == int(profile["pairs"]):
			break
		state = []
	if state.is_empty():
		return {}
	var route: Array[Vector2i] = Solver.new().solve(state, SEARCH_BUDGET)
	if route.is_empty():
		return {}
	var solution: Array = []
	for move: Vector2i in route:
		solution.append([move.x, move.y])
	return {"pockets": state, "solution": solution}

func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	# Seeded Fisher-Yates, so a campaign seed always reproduces the same deal.
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var held: Variant = items[i]
		items[i] = items[j]
		items[j] = held

## No pocket holds more than two of one color.
func _spread(state: Array) -> bool:
	for pocket: Array in state:
		var counts: Dictionary = {}
		for color: int in pocket:
			counts[color] = int(counts.get(color, 0)) + 1
			if counts[color] > MAX_PER_POCKET:
				return false
	return true

func _pairs(state: Array) -> int:
	var result: int = 0
	for pocket: Array in state:
		for i: int in range(1, pocket.size()):
			if int(pocket[i]) == int(pocket[i - 1]):
				result += 1
	return result
