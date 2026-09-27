class_name BlobbleLevelGenerator
extends RefCounted
## Deals every color across the pockets, then certifies the deal with a solver search,
## so every level carries a verified solution. Introduce colors on small, roomy
## boards before adding duplicate groups and crowding.

const Puzzle = preload("res://scripts/puzzle.gd")
const Layout = preload("res://scripts/board_layout.gd")
const Solver = preload("res://scripts/hint_solver.gd")
const VERSION: int = 4
const DEFAULT_SEED: int = 14921
## First teach two obvious matches, then gradually separate equal neighbors.
const OPENING_PAIRS: Array[int] = [4, 2, 2, 2, 1, 1, 1]
## Color groups (four blobs each) on the first level, growing by one every three levels.
const OPENING_GROUPS: int = 2
const OPENING_MOVE_LIMIT: int = 5
const MAX_PER_POCKET: int = 2
const SEARCH_BUDGET: int = 4000
const CANDIDATES: int = 4
const SOLVED: Array = [[0, 0, 0, 0], [2, 2, 2, 2], [1, 1, 1, 1], [5, 5, 5, 5],
	[3, 3, 3, 3], [4, 4, 4, 4], [1, 1, 1, 1], [], [4, 4, 4, 4], [3, 3, 3, 3], [2, 2, 2, 2], []]
## The order groups join the board: one of each color first, then the doubles.
const GROUP_COLORS: Array[int] = [0, 2, 1, 5, 3, 4, 1, 4, 3, 2]

func difficulty(index: int) -> Dictionary:
	index = maxi(index, 0)
	var allowed: int = OPENING_PAIRS[index] if index < OPENING_PAIRS.size() else 0
	var groups: int = mini(GROUP_COLORS.size(), OPENING_GROUPS + index / 3)
	var target_score: int = 6 + mini(index, 12) * 6 + clampi(index - 12, 0, 12) * 10 + clampi(index - 24, 0, 30) * 2
	return {"colors": mini(groups, Puzzle.COLOR_COUNT), "groups": groups, "pairs": allowed, "target_score": target_score}

## A deterministic estimate, not an optimal move count or a human difficulty rating.
## Count all legal destinations, including different colors, and discount spare room.
func measure_difficulty(state: Array, solution: Array) -> Dictionary:
	var blobs: int = 0
	var runs: int = 0
	var possible_moves: int = 0
	var legal_moves: int = 0
	var cross_color_moves: int = 0
	for source: int in state.size():
		var pocket: Array = state[source]
		blobs += pocket.size()
		if pocket.is_empty():
			continue
		runs += 1
		for slot: int in range(1, pocket.size()):
			if pocket[slot] != pocket[slot - 1]:
				runs += 1
		possible_moves += state.size() - 1
		for target: int in state.size():
			if Puzzle.transfer_size(state, source, target) == 0:
				continue
			legal_moves += 1
			if not state[target].is_empty() and pocket.back() != state[target].back():
				cross_color_moves += 1
	var excess_runs: int = maxi(0, runs - blobs / Puzzle.CAPACITY)
	var occupancy: float = float(blobs) / maxi(1, state.size() * Puzzle.CAPACITY)
	var blocked_fraction: float = 1.0 - float(legal_moves) / maxi(1, possible_moves)
	var score: int = 0 if Puzzle.solved(state) else roundi((excess_runs + solution.size()) * (1.0 + occupancy + blocked_fraction))
	var names: Array[String] = ["Gentle", "Easy", "Thoughtful", "Tricky", "Expert"]
	var tier: int = 0 if score < 60 else 1 if score < 90 else 2 if score < 200 else 3 if score < 240 else 4
	return {"score": score, "name": names[tier], "solution_moves": solution.size(),
		"excess_runs": excess_runs, "legal_moves": legal_moves, "cross_color_moves": cross_color_moves}

func generate(index: int, campaign_seed: int = DEFAULT_SEED) -> Dictionary:
	index = maxi(index, 0)
	var profile: Dictionary = difficulty(index)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = campaign_seed + (index % 1000000000) * 917
	var level: Dictionary = {}
	var best_distance: int = 2147483647
	var certified: int = 0
	for attempt: int in 500:
		var candidate: Dictionary = _deal(profile, rng)
		if candidate.is_empty():
			continue
		certified += 1
		var measured: Dictionary = measure_difficulty(candidate["pockets"], candidate["solution"])
		var distance: int = absi(int(measured["score"]) - int(profile["target_score"]))
		if distance < best_distance:
			best_distance = distance
			level = candidate
			level["difficulty"] = profile.duplicate()
			level["difficulty"].merge(measured)
		if certified >= CANDIDATES:
			break
	assert(not level.is_empty(), "A certified deal is found within the attempt budget")
	level["index"] = index
	level["generator_version"] = VERSION
	level["layout"] = Layout.new().generate(index, campaign_seed)
	return level

## One spread-out deal with exactly the allowed equal neighbors, if the solver can finish it.
func _deal(profile: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var blobs: Array = []
	for group: int in int(profile["groups"]):
		for i: int in Puzzle.CAPACITY:
			blobs.append(GROUP_COLORS[group])
	var filled: Array[int] = []
	for index: int in SOLVED.size():
		if not SOLVED[index].is_empty():
			filled.append(index)
	# Small introductions use two pockets per group; later boards occupy ten pockets.
	filled.resize(mini(filled.size(), int(profile["groups"]) * 2))
	# Spread the blobs evenly over the active pockets, keeping at least two empty.
	var sizes: Array = []
	for i: int in filled.size():
		sizes.append(blobs.size() / filled.size() + (1 if i < blobs.size() % filled.size() else 0))
	var state: Array = []
	for attempt: int in 200:
		_shuffle(blobs, rng)
		_shuffle(sizes, rng)
		state = []
		for index: int in SOLVED.size():
			state.append([])
		var taken: int = 0
		for i: int in filled.size():
			state[filled[i]] = blobs.slice(taken, taken + int(sizes[i]))
			taken += int(sizes[i])
		if _spread(state) and _pairs(state) == int(profile["pairs"]):
			break
		state = []
	if state.is_empty():
		return {}
	var route: Array[Vector2i] = Solver.new().solve(state, SEARCH_BUDGET)
	if route.is_empty():
		return {}
	# Keep the two-color introductions short even when the bounded solver takes a detour.
	if int(profile["groups"]) == OPENING_GROUPS and route.size() > OPENING_MOVE_LIMIT:
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
