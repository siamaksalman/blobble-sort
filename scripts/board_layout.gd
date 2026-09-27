class_name BlobbleBoardLayout
extends RefCounted
## Independent, deterministic geometry. Logical pocket IDs remain stable for saves.

const VERSION: int = 1
const SIZE: Vector2 = Vector2(941, 1672)
const STEP: float = 89.0
const MAX_CORRIDORS: int = 14

func generate(index: int, campaign_seed: int = 14921) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = campaign_seed * 31 + maxi(index, 0) * 7919 + 42841
	var row_count: int = 3 + posmod(index, 2)
	var rows: Array[int] = []
	rows.resize(row_count)
	rows.fill(2)
	for i: int in 12 - row_count * 2:
		var available: Array[int] = []
		for row: int in row_count:
			if rows[row] < (5 if row_count == 3 else 4):
				available.append(row)
		rows[available[rng.randi_range(0, available.size() - 1)]] += 1
	var wells: Array = []
	var row_ids: Array = []
	for row: int in row_count:
		var ids: Array[int] = []
		var spacing: float = 821.0 / rows[row]
		var jitter: float = minf(23, (spacing - 160.0) * 0.45)
		for col: int in rows[row]:
			var x: float = 60.0 + spacing * (col + 0.5) + rng.randf_range(-jitter, jitter)
			var y: float = 96.0 + 1464.0 / row_count * (row + 0.5) + rng.randf_range(-11, 11)
			var scale_value: float = rng.randf_range(0.96, 1.02) if row_count == 3 else rng.randf_range(0.72, 0.78)
			if rows[row] == 5:
				scale_value *= 0.92
			ids.append(wells.size())
			wells.append({"center": [snappedf(x, 0.1), snappedf(y, 0.1)], "scale": snappedf(scale_value, 0.001), "row": row})
		row_ids.append(ids)
	# Neighbor edges form a planar row network; a randomized spanning tree gives
	# each board different wall openings while connecting every well.
	var candidates: Array = []
	for row: int in row_count:
		var ids: Array = row_ids[row]
		for col: int in range(ids.size() - 1):
			_add_edge(candidates, ids[col], ids[col + 1])
		if row + 1 < row_count:
			for source: int in ids:
				_add_edge(candidates, source, _nearest(wells, source, row_ids[row + 1]))
			for target: int in row_ids[row + 1]:
				_add_edge(candidates, _nearest(wells, target, ids), target)
	for i: int in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temporary: Array = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = temporary
	var components: Array[int] = []
	for i: int in 12:
		components.append(i)
	var edges: Array = []
	var extra: Array = []
	for edge: Array in candidates:
		var a: int = components[edge[0]]
		var b: int = components[edge[1]]
		if a == b:
			extra.append(edge)
			continue
		edges.append(edge)
		for i: int in 12:
			if components[i] == b:
				components[i] = a
	for i: int in mini(rng.randi_range(0, 3), extra.size()):
		edges.append(extra[i])
	var corridors: Array = []
	for edge: Array in edges:
		var a: Dictionary = wells[edge[0]]
		var b: Dictionary = wells[edge[1]]
		var start: Vector2 = Vector2(a["center"][0], a["center"][1])
		var end: Vector2 = Vector2(b["center"][0], b["center"][1])
		if a["row"] == b["row"]:
			var opening: float = rng.randf_range(-105, 105)
			start.y += opening * a["scale"]
			end.y += opening * b["scale"]
		else:
			start.y += 1.5 * STEP * a["scale"]
			end.y -= 1.5 * STEP * b["scale"]
		corridors.append({"from": edge[0], "to": edge[1], "start": [start.x, start.y], "end": [end.x, end.y], "radius": rng.randf_range(23, 32)})
	return {"version": VERSION, "size": [941, 1672], "rows": rows, "wells": wells, "corridors": corridors,
		"corner": rng.randf_range(88, 116), "wave": rng.randf_range(0, TAU)}

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

func _nearest(wells: Array, source: int, targets: Array) -> int:
	var nearest: int = targets[0]
	var distance: float = INF
	for target: int in targets:
		var candidate: float = absf(wells[source]["center"][0] - wells[target]["center"][0])
		if candidate < distance:
			distance = candidate
			nearest = target
	return nearest

func _add_edge(edges: Array, a: int, b: int) -> void:
	var edge: Array = [mini(a, b), maxi(a, b)]
	if not edges.has(edge):
		edges.append(edge)
