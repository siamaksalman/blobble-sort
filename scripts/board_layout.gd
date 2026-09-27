class_name BlobbleBoardLayout
extends RefCounted
## Reference-derived layouts. Variation moves the original clay artwork and its
## touch targets together, preserving the broad channels and full-size jellies.

const VERSION: int = 3
const SIZE: Vector2 = Vector2(941, 1672)
const STEP: float = 89.0
const COLUMNS: Array[float] = [158.0, 369.0, 570.0, 782.0]
const BOTTOMS: Array[float] = [478.0, 947.0, 1418.0]
const GATE_Y: Array[float] = [560.0, 1034.0]
const SOURCE_Y: Array[float] = [0.0, 100.0, 530.0, 590.0, 1000.0, 1080.0, 1500.0, 1672.0]
# Openings traced from the reference texture, including its broad cross passages.
const CONNECTIONS: Array = [[0, 1], [1, 2], [2, 3], [4, 5], [5, 6], [6, 7], [8, 9], [9, 10], [10, 11], [0, 4], [1, 5], [3, 7], [4, 8], [5, 9], [7, 11]]

func generate(index: int, campaign_seed: int = 14921) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = campaign_seed * 31 + maxi(index, 0) * 7919 + 42841
	var is_reference: bool = index == 0 and campaign_seed == 14921
	var mirrored: bool = posmod(index, 2) == 1
	var source_x: Array[float] = [0.0]
	for column: int in 4:
		source_x.append(SIZE.x - COLUMNS[3 - column] if mirrored else COLUMNS[column])
	source_x.append(SIZE.x)
	var target_x: Array[float] = source_x.duplicate()
	var target_y: Array[float] = SOURCE_Y.duplicate()
	if not is_reference:
		for column: int in range(1, 5):
			target_x[column] += snappedf(rng.randf_range(-14.0, 14.0), 0.1)
		for row: int in 3:
			var shift: float = snappedf(rng.randf_range(-10.0, 10.0), 0.1)
			target_y[1 + row * 2] += shift
			target_y[2 + row * 2] += shift
	var wells: Array = []
	for index_in_board: int in 12:
		var row: int = index_in_board / 4
		var column: int = index_in_board % 4
		var center: Vector2 = Vector2(target_x[4 - column if mirrored else column + 1], BOTTOMS[row] - STEP * 1.5 + target_y[1 + row * 2] - SOURCE_Y[1 + row * 2])
		wells.append({"center": [center.x, center.y], "scale": 1.0, "row": row})
	var maze: Dictionary = _generate_maze(rng, is_reference)
	return {"version": VERSION, "size": [941, 1672], "rows": [4, 4, 4], "wells": wells, "corridors": maze["corridors"],
		"reference": is_reference, "horizontal": maze["horizontal"], "vertical": maze["vertical"],
		"mirror": mirrored, "source_x": source_x, "target_x": target_x, "source_y": SOURCE_Y.duplicate(), "target_y": target_y}

func _generate_maze(rng: RandomNumberGenerator, is_reference: bool) -> Dictionary:
	var candidates: Array = []
	for row: int in 3:
		for col: int in 3:
			candidates.append([row * 4 + col, row * 4 + col + 1])
	for row: int in 2:
		for col: int in 4:
			candidates.append([row * 4 + col, (row + 1) * 4 + col])
	for i: int in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Array = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	var components: Array[int] = []
	for i: int in 12:
		components.append(i)
	var connections: Array = []
	var extras: Array = []
	for edge: Array in candidates:
		var a: int = components[edge[0]]
		var b: int = components[edge[1]]
		if a == b:
			extras.append(edge)
			continue
		connections.append(edge)
		for i: int in 12:
			if components[i] == b:
				components[i] = a
	for i: int in rng.randi_range(0, 4):
		connections.append(extras[i])
	if is_reference:
		connections = CONNECTIONS.duplicate(true)
	var horizontal: Array[int] = []
	var vertical: Array[int] = []
	horizontal.resize(9)
	horizontal.fill(0)
	vertical.resize(8)
	vertical.fill(0)
	var corridors: Array = []
	for edge: Array in connections:
		var a: int = mini(edge[0], edge[1])
		var b: int = maxi(edge[0], edge[1])
		corridors.append({"from": a, "to": b})
		if b - a == 1:
			horizontal[(a / 4) * 3 + a % 4] = rng.randi_range(1, 3)
		else:
			vertical[a] = 1
	return {"corridors": corridors, "horizontal": horizontal, "vertical": vertical}

## Same forward mapping that the art shader reverses. Also useful for screenshots.
static func map_reference(layout: Dictionary, point: Vector2) -> Vector2:
	var original: Vector2 = point
	if layout["mirror"]:
		original.x = SIZE.x - original.x
	return Vector2(_map_axis(original.x, layout["source_x"], layout["target_x"]), _map_axis(original.y, layout["source_y"], layout["target_y"]))

static func _map_axis(value: float, source: Array, target: Array) -> float:
	for i: int in source.size() - 1:
		if value >= source[i] and value <= source[i + 1]:
			return lerpf(target[i], target[i + 1], (value - source[i]) / (source[i + 1] - source[i]))
	return value

static func center_at(layout: Dictionary, index: int, slot: float) -> Vector2:
	var well: Dictionary = layout["wells"][index]
	return Vector2(well["center"][0], well["center"][1] + (1.5 - slot) * STEP * well["scale"])

static func well_rect(layout: Dictionary, index: int) -> Rect2:
	var well: Dictionary = layout["wells"][index]
	var dimensions: Vector2 = Vector2(142, 399) * float(well["scale"])
	return Rect2(Vector2(well["center"][0], well["center"][1]) - dimensions * 0.5, dimensions)

static func hit_rect(layout: Dictionary, index: int) -> Rect2:
	var rect: Rect2 = well_rect(layout, index)
	var dimensions: Vector2 = Vector2(maxf(158, rect.size.x), rect.size.y + 12)
	return Rect2(rect.get_center() - dimensions * 0.5, dimensions)
