class_name BlobbleLevelGenerator
extends RefCounted
## Reverse legal pours from a solved board; every result carries a solution.
## A color boundary needs at least one forward move to remove. This is a lower
## bound, not a claim that the certificate is an optimal solution.

const Puzzle = preload("res://scripts/puzzle.gd")
const Layout = preload("res://scripts/board_layout.gd")
const VERSION: int = 1
const DEFAULT_SEED: int = 14921
const MAX_BOUNDARIES: int = 20
const SOLVED: Array = [[0, 0, 0, 0], [2, 2, 2, 2], [1, 1, 1, 1], [5, 5, 5, 5],
	[3, 3, 3, 3], [4, 4, 4, 4], [1, 1, 1, 1], [], [4, 4, 4, 4], [3, 3, 3, 3], [2, 2, 2, 2], []]

func difficulty(index: int) -> Dictionary:
	index = maxi(index, 0)
	var colors: int = mini(6, 2 + index / 8)
	var target: int = mini(MAX_BOUNDARIES, 1 + index / 2)
	var names: Array[String] = ["Gentle", "Easy", "Thoughtful", "Tricky", "Expert"]
	return {"colors": colors, "boundaries": target, "name": names[colors - 2]}

func generate(index: int, campaign_seed: int = DEFAULT_SEED) -> Dictionary:
	index = maxi(index, 0)
	var profile: Dictionary = difficulty(index)
	var level: Dictionary = _scramble(profile, campaign_seed + (index % 1000000000) * 917)
	if level.is_empty():
		# Each of the twenty canonical profiles is covered by the certificate tests.
		# This bounded fallback protects against an unusually unproductive random seed.
		level = _scramble(profile, DEFAULT_SEED + (int(profile["boundaries"]) - 1) * 2 * 917)
	assert(not level.is_empty(), "Canonical difficulty profile must have a certified scramble")
	level["difficulty"] = profile
	level["index"] = index
	level["generator_version"] = VERSION
	level["layout"] = Layout.new().generate(index, campaign_seed)
	return level

func _scramble(profile: Dictionary, seed_value: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for attempt: int in 64:
		var state: Array = SOLVED.duplicate(true)
		var reverse_moves: Array = []
		var seen: Dictionary = {Puzzle.state_key(state): true}
		var boundaries: int = 0
		for step: int in 120:
			var options: Array = []
			var growing: Array = []
			for source: int in state.size():
				var pocket: Array = state[source]
				if pocket.is_empty() or int(pocket.back()) >= int(profile["colors"]):
					continue
				var run: int = Puzzle.top_count(pocket)
				for target: int in state.size():
					var destination: Array = state[target]
					if source == target or destination.size() == Puzzle.CAPACITY:
						continue
					var same: bool = not destination.is_empty() and destination.back() == pocket.back()
					if same and pocket.size() < Puzzle.CAPACITY:
						continue
					for amount: int in range(1, mini(run, Puzzle.CAPACITY - destination.size()) + 1):
						if amount == run and run < pocket.size():
							continue
						if destination.is_empty() and amount == pocket.size():
							continue
						var move: Array = [source, target, amount]
						options.append(move)
						if not destination.is_empty() and not same:
							growing.append(move)
			if options.is_empty():
				break
			var pool: Array = growing if not growing.is_empty() and rng.randf() < 0.8 else options
			var move: Array = pool[rng.randi_range(0, pool.size() - 1)]
			var before: Array = state.duplicate(true)
			var source: int = move[0]
			var target: int = move[1]
			var added: int = 1 if not state[target].is_empty() and state[target].back() != state[source].back() else 0
			for i: int in int(move[2]):
				state[target].append(state[source].pop_back())
			var key: String = Puzzle.state_key(state)
			if seen.has(key):
				state = before
				continue
			seen[key] = true
			reverse_moves.append([target, source])
			boundaries += added
			if boundaries == int(profile["boundaries"]):
				var active_colors: Dictionary = {}
				for pocket: Array in state:
					if not Puzzle.is_complete(pocket):
						for color: int in pocket:
							active_colors[color] = true
				if active_colors.size() != int(profile["colors"]):
					break
				reverse_moves.reverse()
				return {"pockets": state, "solution": reverse_moves}
	return {}
