class_name BlobblePuzzle
extends RefCounted
## Pure puzzle rules. A pocket is bottom-to-top; equal top blobs move together.

const CAPACITY: int = 4
const POCKET_COUNT: int = 12
const COLOR_COUNT: int = 6

var pockets: Array = []
var moves: int = 0
var history: Array = []
var initial: Array = []

func setup(layout: Array) -> void:
	initial = layout.duplicate(true)
	pockets = layout.duplicate(true)
	moves = 0
	history.clear()

static func is_complete(pocket: Array) -> bool:
	if pocket.size() != CAPACITY:
		return false
	for color: int in pocket:
		if color != int(pocket[0]):
			return false
	return true

static func top_count(pocket: Array) -> int:
	if pocket.is_empty():
		return 0
	var count: int = 0
	for i: int in range(pocket.size() - 1, -1, -1):
		if int(pocket[i]) != int(pocket.back()):
			break
		count += 1
	return count

static func transfer_size(state: Array, source: int, target: int) -> int:
	if source < 0 or target < 0 or source >= state.size() or target >= state.size() or source == target:
		return 0
	var a: Array = state[source]
	var b: Array = state[target]
	if a.is_empty() or b.size() >= CAPACITY:
		return 0
	return mini(top_count(a), CAPACITY - b.size())

static func apply_to(state: Array, source: int, target: int) -> int:
	var count: int = transfer_size(state, source, target)
	for i: int in count:
		state[target].append(state[source].pop_back())
	return count

func pour(source: int, target: int) -> int:
	var count: int = transfer_size(pockets, source, target)
	if count == 0:
		return 0
	history.append(pockets.duplicate(true))
	apply_to(pockets, source, target)
	moves += 1
	return count

func undo() -> bool:
	if history.is_empty():
		return false
	pockets = history.pop_back()
	moves = maxi(0, moves - 1)
	return true

func restart() -> void:
	setup(initial)

func completed_count() -> int:
	var count: int = 0
	for pocket: Array in pockets:
		if is_complete(pocket):
			count += 1
	return count

static func solved(state: Array) -> bool:
	for pocket: Array in state:
		if not pocket.is_empty() and not is_complete(pocket):
			return false
	return true

static func state_key(state: Array, canonical: bool = false) -> String:
	var parts: PackedStringArray = []
	for pocket: Array in state:
		var part: String = ""
		for color: int in pocket:
			part += str(color)
		parts.append(part)
	if canonical:
		parts.sort()
	return "|".join(parts)

static func valid_layout(state: Variant) -> bool:
	if not state is Array or state.size() < 6 or state.size() > POCKET_COUNT:
		return false
	for pocket: Variant in state:
		if not pocket is Array or pocket.size() > CAPACITY:
			return false
		for color: Variant in pocket:
			if not (color is int or color is float) or color != int(color) or color < 0 or color >= COLOR_COUNT:
				return false
	return true

static func inventory(state: Array) -> Array[int]:
	var result: Array[int] = [0, 0, 0, 0, 0, 0]
	for pocket: Array in state:
		for color: int in pocket:
			result[color] += 1
	return result
