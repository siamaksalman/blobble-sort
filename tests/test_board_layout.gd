extends SceneTree
## Layout generation must change geometry while keeping every pocket usable.

const Generator = preload("res://scripts/level_generator.gd")
const Board = preload("res://scripts/board.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(ResourceLoader.exists("res://scripts/board_layout.gd"), "Levels generate board geometry, not only color arrangements")
	if failures:
		_finish()
		return
	var layout_generator: RefCounted = load("res://scripts/board_layout.gd").new()
	var unique_geometry: Dictionary = {}
	var row_patterns: Dictionary = {}
	var unique_topologies: Dictionary = {}
	var edge_counts: Dictionary = {}
	var reference_columns: Array = [158.0, 369.0, 570.0, 782.0]
	var reference_bottoms: Array = [478.0, 947.0, 1418.0]
	for seed_value: int in [14921, 1, 87654]:
		for index: int in 40:
			var layout: Dictionary = layout_generator.generate(index, seed_value)
			check(layout == layout_generator.generate(index, seed_value), "A layout is reproducible from level and seed")
			check(layout["wells"].size() == 12, "Twelve pockets preserve existing puzzle rules")
			check(layout["rows"] == [4, 4, 4], "Every layout preserves the reference four-column three-row composition")
			for well: Dictionary in layout["wells"]:
				check(is_equal_approx(float(well["scale"]), 1.0), "Procedural layouts retain full-size round reference jellies")
			unique_geometry[JSON.stringify(layout["wells"])] = true
			row_patterns[str(layout["rows"])] = true
			for a: int in 12:
				var hit: Rect2 = layout_generator.hit_rect(layout, a)
				check(Rect2(20, 40, 901, 1580).encloses(hit), "Touch target stays within the board")
				check(hit.size.x >= 158, "Touch targets remain wide enough for mobile")
				for slot: int in 4:
					check(hit.has_point(layout_generator.center_at(layout, a, slot)), "Every slot stays inside its pocket's touch target")
				for b: int in range(a + 1, 12):
					check(not hit.intersects(layout_generator.hit_rect(layout, b)), "Pocket touch targets never overlap")
			var edge_keys: Array[String] = []
			for edge: Dictionary in layout["corridors"]:
				var a: int = mini(edge["from"], edge["to"])
				var b: int = maxi(edge["from"], edge["to"])
				check(b - a == 4 or (b - a == 1 and a / 4 == b / 4), "Maze passages connect neighboring pockets")
				edge_keys.append("%02d-%02d" % [a, b])
			edge_keys.sort()
			unique_topologies[str(edge_keys)] = true
			edge_counts[layout["corridors"].size()] = true
			var reached: Dictionary = {0: true}
			for pass_index: int in 12:
				for edge: Dictionary in layout["corridors"]:
					if reached.has(edge["from"]) or reached.has(edge["to"]):
						reached[edge["from"]] = true
						reached[edge["to"]] = true
			check(reached.size() == 12, "Generated maze corridors connect all pockets")
	print("Distinct maze topologies in 120 generated samples: ", unique_topologies.size())
	check(unique_topologies.size() >= 80, "Levels change actual maze connections, not just mirror the same maze")
	check(edge_counts.size() >= 3, "Maze structures vary loops and branches")
	check(unique_geometry.size() == 120, "Levels and seeds produce genuinely different pocket geometry")
	check(row_patterns.size() == 1, "Procedural variation does not redesign the reference proportions")
	var reference: Dictionary = layout_generator.generate(0)
	for i: int in 12:
		var expected: Vector2 = Vector2(reference_columns[i % 4], reference_bottoms[i / 4])
		check(layout_generator.center_at(reference, i, 0).is_equal_approx(expected), "First level exactly preserves the original pocket coordinates")
	var generator: RefCounted = Generator.new()
	var level: Dictionary = generator.generate(9)
	check(level.has("layout"), "Generated levels include their board layout")
	if not level.has("layout"):
		_finish()
		return
	var board: Control = Board.new()
	root.add_child(board)
	check(board.has_method("apply_layout"), "The renderer accepts generated geometry")
	if not board.has_method("apply_layout"):
		board.free()
		_finish()
		return
	board.apply_layout(level["layout"])
	check(board._backdrop.texture == Board.TEXTURE, "Every generated board renders the reference clay artwork")
	board.refresh(level["pockets"])
	for jelly: Control in board.jellies:
		check(jelly.material.get_shader_parameter("asleep") != 1.0, "Completed jellies keep the original black round eyes")
	board.position = Vector2(31, 17)
	board.scale = Vector2.ONE * 0.47
	for i: int in 12:
		for slot: int in 4:
			var center: Vector2 = layout_generator.center_at(level["layout"], i, slot)
			check(board.center_at(i, slot).is_equal_approx(center), "Renderer and generator agree on slot positions")
			check(board.hit_test(board.get_global_transform() * center) == i, "Scaled mouse/touch input finds the correct procedural pocket")
	for jelly: Control in board.jellies:
		jelly._process(0.016)
		var expected_scale: float = float(level["layout"]["wells"][jelly.pocket_index]["scale"])
		check(is_equal_approx(jelly.scale.x, expected_scale), "Jelly animation preserves pocket scale")
		var center: Vector2 = board.center_at(jelly.pocket_index, jelly.start_slot + (jelly.count - 1) * 0.5)
		check((jelly.get_transform() * (jelly.size * 0.5)).is_equal_approx(center), "Rendered jelly centers align with generated pockets, including their scaling pivots")
	var first_center: Vector2 = board.center_at(0, 1.5)
	var leftmost: int = 0
	for i: int in 12:
		if board.center_at(i, 1.5).x < board.center_at(leftmost, 1.5).x:
			leftmost = i
	var neighbor: int = board.directional_neighbor(leftmost, Vector2.RIGHT)
	check(neighbor != leftmost and board.center_at(neighbor, 1.5).x > board.center_at(leftmost, 1.5).x, "Keyboard navigation follows generated geometry")
	var other: Dictionary = generator.generate(10)
	board.apply_layout(other["layout"])
	board.refresh(other["pockets"])
	check(not board.center_at(0, 1.5).is_equal_approx(first_center), "Changing level changes visible pocket positions")
	board.free()
	var game: Control = load("res://scripts/game.gd").new()
	game.test_mode = true
	game.save.legacy_level = true
	root.add_child(game)
	check(not game.board.layout_data.is_empty(), "Existing legacy puzzles also receive procedural geometry")
	var legacy: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels.json"))
	check(game.puzzle.initial == legacy[0]["pockets"], "Changing legacy geometry preserves its puzzle and move history")
	game.free()
	_finish()

func _finish() -> void:
	print("Layout checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
