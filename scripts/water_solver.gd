class_name WaterSolver
extends RefCounted
## Pure puzzle logic + a depth-first solver.
##
## A state is an Array of Strings, one per bottle, listed bottom -> top.
## Each character is a color ("A" = color 0, "B" = color 1, ...).
## A move is [from, to, amount].


static func top_run(b: String) -> int:
	var n := b.length()
	if n == 0:
		return 0
	var c := b.unicode_at(n - 1)
	var k := 1
	while k < n and b.unicode_at(n - 1 - k) == c:
		k += 1
	return k


static func is_complete(b: String, capacity: int) -> bool:
	return b.length() == capacity and top_run(b) == capacity


static func is_solved(state: Array, capacity: int) -> bool:
	for b: String in state:
		if not b.is_empty() and not is_complete(b, capacity):
			return false
	return true


## How many units would flow from bottle `from` into bottle `to` (0 = illegal).
static func pour_amount(state: Array, from: int, to: int, capacity: int) -> int:
	if from == to:
		return 0
	var a: String = state[from]
	var b: String = state[to]
	if a.is_empty() or b.length() >= capacity:
		return 0
	if not b.is_empty() and b.unicode_at(b.length() - 1) != a.unicode_at(a.length() - 1):
		return 0
	return mini(top_run(a), capacity - b.length())


static func apply_move(state: Array, from: int, to: int, amount: int) -> Array:
	var ns := state.duplicate()
	var a: String = ns[from]
	ns[from] = a.substr(0, a.length() - amount)
	ns[to] = String(ns[to]) + a.substr(a.length() - amount)
	return ns


## Bottle order doesn't matter for solvability, so sort for the visited-set key.
static func key_of(state: Array) -> String:
	var s := PackedStringArray(state)
	s.sort()
	return "|".join(s)


## Legal, non-redundant moves, best-looking first.
static func legal_moves(state: Array, capacity: int) -> Array:
	var moves := []
	var n := state.size()
	for i in n:
		var a: String = state[i]
		if a.is_empty():
			continue
		var run := top_run(a)
		var uniform := run == a.length()
		if uniform and run == capacity:
			continue # finished bottle, never touch it
		var c := a.unicode_at(a.length() - 1)
		var tried_empty := false
		for j in n:
			if i == j:
				continue
			var b: String = state[j]
			var space := capacity - b.length()
			if space <= 0:
				continue
			if b.is_empty():
				# Moving a single-color bottle into an empty one changes nothing,
				# and all empty bottles are equivalent.
				if uniform or tried_empty:
					continue
				tried_empty = true
				moves.append([i, j, mini(run, space), 0])
			elif b.unicode_at(b.length() - 1) == c:
				var amt := mini(run, space)
				var pri := 1
				if amt == run:
					pri = 2
					if top_run(b) == b.length():
						pri = 4 if b.length() + amt == capacity else 3
				moves.append([i, j, amt, pri])
	moves.sort_custom(func(x: Array, y: Array) -> bool: return x[3] > y[3])
	return moves


## Returns {solved: bool, moves: Array[[from, to, amount]], nodes: int}.
## `solved == false` means unsolvable OR the node budget ran out.
static func solve(start: Array, capacity: int, max_nodes := 40000) -> Dictionary:
	if is_solved(start, capacity):
		return {solved = true, moves = [], nodes = 0}
	var visited := {key_of(start): true}
	var stack := [[start, legal_moves(start, capacity), 0]]
	var path := []
	var nodes := 0
	while not stack.is_empty():
		var frame: Array = stack[-1]
		var options: Array = frame[1]
		if frame[2] >= options.size():
			stack.pop_back()
			if not path.is_empty():
				path.pop_back()
			continue
		var m: Array = options[frame[2]]
		frame[2] += 1
		var ns := apply_move(frame[0], m[0], m[1], m[2])
		var k := key_of(ns)
		if visited.has(k):
			continue
		visited[k] = true
		nodes += 1
		if nodes > max_nodes:
			return {solved = false, moves = [], nodes = nodes}
		path.append([m[0], m[1], m[2]])
		if is_solved(ns, capacity):
			return {solved = true, moves = path, nodes = nodes}
		stack.append([ns, legal_moves(ns, capacity), 0])
	return {solved = false, moves = [], nodes = nodes}
