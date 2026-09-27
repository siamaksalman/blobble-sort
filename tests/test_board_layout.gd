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
	for seed_value: int in [14921, 1, 87654]:
		for index: int in 40:
			var layout: Dictionary = layout_generator.generate(index, seed_value)
			check(layout == layout_generator.generate(index, seed_value), "A layout is reproducible from level and seed")
			check(layout["wells"].size() == 12, "Twelve pockets preserve existing puzzle rules")
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
			var reached: Dictionary = {0: true}
			for pass_index: int in 12:
				for edge: Dictionary in layout["corridors"]:
					if reached.has(edge["from"]) or reached.has(edge["to"]):
						reached[edge["from"]] = true
						reached[edge["to"]] = true
			check(reached.size() == 12, "Generated maze corridors connect all pockets")
	check(unique_geometry.size() == 120, "Levels and seeds produce genuinely different pocket geometry")
	check(row_patterns.size() >= 8, "Generation varies row composition, not just small offsets")
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
	board.refresh(level["pockets"])
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
		check((jelly.position + jelly.size * expected_scale * 0.5).is_equal_approx(center), "Jellies sit inside their generated pockets")
	var first_center: Vector2 = board.center_at(0, 1.5)
	var neighbor: int = board.directional_neighbor(0, Vector2.RIGHT)
	check(neighbor != 0 and board.center_at(neighbor, 1.5).x > first_center.x, "Keyboard navigation follows generated geometry")
	var other: Dictionary = generator.generate(10)
	board.apply_layout(other["layout"])
	board.refresh(other["pockets"])
	check(not board.center_at(0, 1.5).is_equal_approx(first_center), "Changing level changes visible pocket positions")
	board.free()
	_finish()

func _finish() -> void:
	print("Layout checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
