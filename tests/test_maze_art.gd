extends SceneTree
## Rendered gate checks catch a graph changing while its artwork stays fixed.
const Board = preload("res://scripts/board.gd")
const Layout = preload("res://scripts/board_layout.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func compare_pixel(rendered: Image, source: Image, layout: Dictionary, at: Vector2, donor: Vector2, label: String) -> void:
	checks += 1
	var destination: Vector2 = Layout.map_reference(layout, at)
	var actual: Color = rendered.get_pixelv(Vector2i(destination.round()))
	var expected: Color = source.get_pixelv(Vector2i(donor.round()))
	if Vector3(actual.r - expected.r, actual.g - expected.g, actual.b - expected.b).length() > 0.065:
		failures += 1
		push_error(label)

func run() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(941, 1672)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board: BlobbleBoard = Board.new()
	viewport.add_child(board)
	var source: Image = Board.TEXTURE.get_image()
	var generator: RefCounted = Layout.new()
	var preview_puzzle: Dictionary = preload("res://scripts/level_generator.gd").new().generate(17)
	for level: int in [1, 2, 3, 4]:
		var layout: Dictionary = generator.generate(level)
		board.refresh([])
		board.apply_layout(layout)
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		var rendered: Image = viewport.get_texture().get_image()
		rendered.save_png("res://builds/maze-empty-%02d.png" % (level + 1))
		for row: int in 3:
			for col: int in 3:
				var mode: int = layout["horizontal"][row * 3 + col]
				var dy: float = [0.0, -20.0, 135.0, -80.0][mode]
				var at: Vector2 = Vector2((Layout.COLUMNS[col] + Layout.COLUMNS[col + 1]) * 0.5, [344.5, 817.5, 1306.0][row] + dy)
				var donor: Vector2 = Vector2(470, 280)
				if mode == 1:
					donor = Vector2(260, 344.5 + dy)
				elif mode == 2:
					donor = Vector2(470, 344.5 + dy)
				elif mode == 3:
					donor = Vector2(470, 1306.0 + dy)
				compare_pixel(rendered, source, layout, at, donor, "Horizontal gate renders its generated open/closed clay section")
		for row: int in 2:
			for col: int in 4:
				var at: Vector2 = Vector2(Layout.COLUMNS[col], Layout.GATE_Y[row])
				var donor: Vector2 = Vector2(158, 560) if layout["vertical"][row * 4 + col] else Vector2(570, 550)
				compare_pixel(rendered, source, layout, at, donor, "Vertical gate renders its generated open/closed clay section")
		board.refresh(preview_puzzle["pockets"])
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		viewport.get_texture().get_image().save_png("res://builds/maze-art-%02d.png" % (level + 1))
	viewport.free()
	print("Maze art checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
