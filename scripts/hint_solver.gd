class_name BlobbleHintSolver
extends RefCounted
## Uses generated solution certificates, then a bounded search for player deviations.

const Puzzle = preload("res://scripts/puzzle.gd")
var known: Dictionary = {}
var _visited: Dictionary = {}
var _remaining: int = 0
## States the last solve() explored; a rough measure of how much a board fights back.
var searched: int = 0

func register_level(layout: Array, solution: Array) -> void:
	var state: Array = layout.duplicate(true)
	for move: Array in solution:
		known[Puzzle.state_key(state)] = Vector2i(int(move[0]), int(move[1]))
		Puzzle.apply_to(state, int(move[0]), int(move[1]))

func get_hint(state: Array) -> Vector2i:
	var key: String = Puzzle.state_key(state)
	if known.has(key):
		return known[key]
	var path: Array[Vector2i] = solve(state)
	if not path.is_empty():
		var walked: Array = state.duplicate(true)
		for move: Vector2i in path:
			known[Puzzle.state_key(walked)] = move
			Puzzle.apply_to(walked, move.x, move.y)
		return path[0]
	return Vector2i(-1, -1)

## A full route to completion within `budget` searched states, or empty if none was found.
func solve(state: Array, budget: int = 18000) -> Array[Vector2i]:
	_visited.clear()
	_remaining = budget
	var path: Array[Vector2i] = []
	var found: bool = _search(state.duplicate(true), 0, path, Vector2i(-1, -1))
	searched = budget - _remaining
	if not found:
		path.clear()
	return path

func _search(state: Array, depth: int, path: Array[Vector2i], previous: Vector2i) -> bool:
	if Puzzle.solved(state):
		return true
	if depth > 90 or _remaining <= 0:
		return false
	_remaining -= 1
	var key: String = Puzzle.state_key(state, true)
	if _visited.has(key) and int(_visited[key]) <= depth:
		return false
	_visited[key] = depth
	var candidates: Array = []
	for source: int in state.size():
		if state[source].is_empty() or Puzzle.is_complete(state[source]):
			continue
		var used_empty: bool = false
		for target: int in state.size():
			var amount: int = Puzzle.transfer_size(state, source, target)
			if amount == 0 or (previous.x == target and previous.y == source):
				continue
			if state[target].is_empty():
				if used_empty or amount == state[source].size():
					continue
				used_empty = true
			var score: int = amount * 2
			var matching: bool = not state[target].is_empty() and state[source].back() == state[target].back()
			if matching:
				score += 5
			elif not state[target].is_empty():
				# Temporary mixed stacks are legal, but try consolidation first.
				score -= 20
			if matching and amount + state[target].size() == Puzzle.CAPACITY:
				score += 8
			candidates.append([source, target, score])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[2] > b[2])
	for candidate: Array in candidates:
		var next: Array = state.duplicate(true)
		var move: Vector2i = Vector2i(candidate[0], candidate[1])
		Puzzle.apply_to(next, move.x, move.y)
		path.append(move)
		if _search(next, depth + 1, path, move):
			return true
		path.pop_back()
	return false
