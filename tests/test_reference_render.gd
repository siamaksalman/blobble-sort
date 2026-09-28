extends SceneTree
## Render the original composition as a visual fixture, separate from difficulty.
const Board = preload("res://scripts/board.gd")
const Layout = preload("res://scripts/board_layout.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if value:
		print("PASS: ", label)
	else:
		failures += 1
		push_error(label)

func run() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(941, 1672)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board: BlobbleBoard = Board.new()
	viewport.add_child(board)
	board.apply_layout(Layout.new().generate(0))
	board.refresh([[3, 2, 1, 0], [2, 2, 2, 2], [0, 4, 1, 3], [5, 5, 5, 5],
		[5, 3, 2, 1], [0, 4, 4, 4], [1, 0, 5, 3], [2, 4],
		[3, 0, 1, 4], [1, 3, 3, 3], [4, 1, 2, 5], [5, 0]])
	# Freeze animation for a reproducible art comparison.
	for jelly: BlobbleJelly in board.jellies:
		jelly.set_process(false)
		jelly.material.set_shader_parameter("clock", 0.0)
		jelly.material.set_shader_parameter("seed", 0.0)
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var rendered: Image = viewport.get_texture().get_image()
	rendered.save_png("res://builds/reference-design.png")
	var source: Image = Board.TEXTURE.get_image()
	var unchanged: bool = true
	for point: Vector2i in [Vector2i(470, 300), Vector2i(260, 560), Vector2i(470, 810), Vector2i(470, 1030), Vector2i(870, 1400)]:
		var a: Color = rendered.get_pixelv(point)
		var b: Color = source.get_pixelv(point)
		unchanged = unchanged and Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.025
	check(unchanged, "Original clay texture, lighting and broad wall shapes are preserved")
	var clean_corners: bool = true
	for point: Vector2i in [Vector2i(106, 162), Vector2i(208, 163), Vector2i(318, 902)]:
		var a: Color = rendered.get_pixelv(point)
		var b: Color = source.get_pixelv(point)
		clean_corners = clean_corners and Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.06
	check(clean_corners, "Sprite corners do not copy rectangular patches of the reference background")
	var left_edge: int = 230
	var right_edge: int = 85
	for x: int in range(85, 230):
		var color: Color = rendered.get_pixel(x, 211)
		if color.r - color.b > 0.35 and color.g < 0.86:
			left_edge = mini(left_edge, x)
			right_edge = maxi(right_edge, x)
	var width: int = right_edge - left_edge + 1
	check(width >= 102 and width <= 112, "Round jellies match the reference 104-pixel body width (actual %d)" % width)
	# A pair of open reference eyes covers substantially more area than closed slits.
	var black_pixels: int = 0
	for y: int in range(202, 238):
		for x: int in range(340, 390):
			var eye: Color = rendered.get_pixel(x, y)
			if eye.r < 0.15 and eye.g < 0.15 and eye.b < 0.15:
				black_pixels += 1
	check(black_pixels >= 120, "Merged jellies retain open black eyes (%d dark pixels)" % black_pixels)
	# Smaller grids must retain the photographed clay, including the cavity lighting.
	board.refresh([])
	for count: int in [6, 8, 10]:
		var compact: Dictionary = Layout.new().generate(0, 14921, count)
		board.apply_layout(compact)
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		var small_render: Image = viewport.get_texture().get_image()
		small_render.save_png("res://builds/reference-small-%02d.png" % count)
		var original_clay: bool = true
		for dy: float in [-170.0, -120.0, 0.0, 100.0, 180.0]:
			var at: Vector2 = board.center_at(0, 1.5) + Vector2(0, dy)
			var a: Color = small_render.get_pixelv(Vector2i(at.round()))
			var b: Color = source.get_pixelv(Vector2i(Vector2(158, 344.5 + dy).round()))
			original_clay = original_clay and Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.035
		check(original_clay, "%d-hole grids retain the original photographed pocket texture and lighting" % count)
	viewport.free()
	print("Reference visual failures: ", failures)
	quit(1 if failures else 0)
