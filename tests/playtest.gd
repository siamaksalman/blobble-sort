extends SceneTree
## Uses real input dispatch and rendered screenshots without touching player saves.

const GAME = preload("res://scripts/game.gd")
var game: Control
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
	else:
		print("PASS: ", label)

func snapshot(name: String) -> void:
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://builds/" + name + ".png")

func click_pocket(index: int) -> void:
	var where: Vector2 = game.board.get_global_transform() * game.board.center_at(index, 1.5)
	where = root.get_final_transform() * where
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = where
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func run() -> void:
	root.size = Vector2i(540, 960)
	game = GAME.new()
	game.test_mode = true
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(game)
	await create_timer(1.0).timeout
	check(game.board.layout_data == game.current_level["layout"], "Game applies the procedural layout to the visible board")
	var first_geometry: String = JSON.stringify(game.board.layout_data)
	await snapshot("preview")
	var hint: Vector2i = game.solver.get_hint(game.puzzle.pockets)
	await click_pocket(hint.x)
	check(game._selected == hint.x, "Mouse input selects a pocket")
	await click_pocket(hint.y)
	await create_timer(0.65).timeout
	check(game.puzzle.moves == 1, "Mouse input completes an animated legal move")
	game._undo()
	check(game.puzzle.moves == 0 and game.puzzle.pockets == game.puzzle.initial, "UI undo restores the board")
	game._hint()
	check(game.board.hinted >= 0, "Hint highlights a destination")
	await snapshot("hint-preview")
	game._select(-1)
	game._show_help()
	await snapshot("help-preview")
	check(is_instance_valid(game._modal), "Help opens")
	game._close_modal()
	# Play a complete level through the same animated action used by touch input.
	while not game.puzzle.solved(game.puzzle.pockets):
		hint = game.solver.get_hint(game.puzzle.pockets)
		if hint.x < 0:
			check(false, "Solution hint available")
			break
		var amount: int = game.puzzle.transfer_size(game.puzzle.pockets, hint.x, hint.y)
		await game._animate_pour(hint.x, hint.y, amount)
	check(game.save.unlocked == 2, "Winning unlocks the next level")
	check(is_instance_valid(game._modal), "Winning displays the completion dialog")
	await snapshot("win-preview")
	await create_timer(9.2).timeout # Let victory particles finish before layout captures.
	game._load_level(1)
	check(game.save.level == 1 and game.puzzle.moves == 0, "Next level loads cleanly")
	check(JSON.stringify(game.board.layout_data) != first_geometry, "Next level uses a different board layout")
	await create_timer(0.5).timeout
	await snapshot("layout-level-02")
	# Keep a small visual gallery covering reference-preserving variations.
	for index: int in [2, 3, 8, 17]:
		game._load_level(index)
		await create_timer(0.4).timeout
		await snapshot("layout-level-%02d" % (index + 1))
	# The campaign continues beyond the old last level and offers paged selection.
	game.save.unlocked = 32
	game._load_level(30)
	check(game.save.level == 30 and not game.puzzle.solved(game.puzzle.pockets), "Level 31 is generated and playable")
	game._show_levels()
	var names: Array[String] = []
	for node: Node in game._modal_panel.get_children():
		if node is Button:
			names.append(node.text)
	check("31" in names, "Level picker opens on the page containing level 31")
	game._close_modal()
	root.size = Vector2i(1280, 800)
	await create_timer(0.3).timeout
	await snapshot("desktop-preview")
	check(game.board.position.x >= 0 and game.board.position.y >= 0, "Landscape board stays on screen")
	print("Visual playtest failures: ", failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
