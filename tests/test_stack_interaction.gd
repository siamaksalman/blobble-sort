extends SceneTree
## Observable support reactions and contact, independent of the puzzle rules.
const Board = preload("res://scripts/board.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	create_timer(20).timeout.connect(func() -> void: quit(1))
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func state(a: Array, b: Array = []) -> Array:
	var result: Array = [a, b]
	for i: int in 10:
		result.append([])
	return result

func body_top(jelly: BlobbleJelly) -> float:
	var height: float = float(jelly.material.get_shader_parameter("body_height"))
	return (jelly.get_transform() * Vector2(jelly.size.x * 0.5, (jelly.size.y - height) * 0.5)).y

func body_bottom(jelly: BlobbleJelly) -> float:
	var height: float = float(jelly.material.get_shader_parameter("body_height"))
	return (jelly.get_transform() * Vector2(jelly.size.x * 0.5, (jelly.size.y + height) * 0.5)).y

func deformation(jelly: BlobbleJelly) -> float:
	return absf(jelly.squash.x - jelly.squash.y)

func run() -> void:
	var board: BlobbleBoard = Board.new()
	root.add_child(board)
	board.apply_layout(preload("res://scripts/board_layout.gd").new().generate(3))
	board.refresh(state([0, 1, 2, 3], [4]))
	var before_poke: Array = board.pockets.duplicate(true)
	# Dispatch the same board-space contact used by pointer input.
	check(board.has_method("poke_at"), "The board supports direct blob contact")
	if board.has_method("poke_at"):
		board.call("poke_at", board.get_global_transform() * board.center_at(0, 1))
		check(deformation(board.jelly_at(0, 1)) > 0.15, "The touched blob visibly squishes")
		var reactions: Array[float] = [0.0, 0.0, 0.0, 0.0]
		var end: int = Time.get_ticks_msec() + 300
		while Time.get_ticks_msec() < end:
			await process_frame
			for slot: int in 4:
				reactions[slot] = maxf(reactions[slot], deformation(board.jelly_at(0, slot)))
		check(reactions[0] > 0.02 and reactions[2] > 0.02, "Contact travels into different colors above and below")
		check(reactions[3] > 0.01 and reactions[3] < reactions[2], "The reaction fades as it travels farther through the stack: %s" % [reactions])
		check(deformation(board.jelly_at(1, 0)) < 0.001, "Contact does not disturb another pocket")
		check(board.pockets == before_poke, "Physical contact preserves colors and puzzle positions")
		await create_timer(0.8).timeout
		for jelly: BlobbleJelly in board.jellies:
			check(deformation(jelly) < 0.002, "Contact settles back to the resting shape")
		board.call("poke_at", board.get_global_transform() * board.center_at(0, 3.8))
		check(deformation(board.jelly_at(0, 3)) < 0.002, "Touching empty space above a stack does not poke a blob")
	board.refresh(state([0, 1, 2, 3], [4]))
	board.set_selection(0)
	check(board.jelly_at(0, 2).squash.y > 1.02, "Lifting the top jelly lets its immediate support stretch upward")
	check(deformation(board.jelly_at(0, 0)) < 0.001, "The reaction reaches deeper supports after a short delay")
	var bottom_reaction: float = 0.0
	var observe_until: int = Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < observe_until:
		await process_frame
		bottom_reaction = maxf(bottom_reaction, deformation(board.jelly_at(0, 0)))
	check(bottom_reaction > 0.002, "The lift reaction travels all the way down the stack")
	check(deformation(board.jelly_at(1, 0)) < 0.001, "Another pocket stays undisturbed")
	board.set_selection(-1)
	check(board.jelly_at(0, 2).squash.y < 0.98, "Putting the top jelly down compresses its support")
	await create_timer(0.8).timeout
	for jelly: BlobbleJelly in board.jellies:
		check(deformation(jelly) < 0.002, "A reaction settles back to the original design")

	# A compressed lower body carries the upper bodies with it, preserving overlap.
	board.refresh(state([0, 1, 2, 3]))
	var ground: float = body_bottom(board.jelly_at(0, 0))
	var original_upper_bottom: float = body_bottom(board.jelly_at(0, 1))
	board.jelly_at(0, 0).wobble(0.12, 0.55)
	await process_frame
	await process_frame
	check(body_bottom(board.jelly_at(0, 1)) > original_upper_bottom + 4, "Upper jellies move down with a squashed support")
	for slot: int in range(1, 4):
		var overlap: float = body_bottom(board.jelly_at(0, slot)) - body_top(board.jelly_at(0, slot - 1))
		check(absf(overlap - 15.0) < 0.1, "Neighboring jellies keep contact while their support deforms")
	check(absf(body_bottom(board.jelly_at(0, 0)) - ground) < 0.01, "The bottom jelly remains seated on the tray")
	await create_timer(0.8).timeout
	check(absf(body_bottom(board.jelly_at(0, 1)) - original_upper_bottom) < 0.1, "The stack returns to its exact resting positions")

	board.refresh(state([3], [0, 1, 3]))
	await board.play_pour(0, 1, 1, state([], [0, 1, 3, 3]))
	check(deformation(board.jelly_at(1, 1)) > 0.04, "A landing compresses the different-colored jelly below the merge")
	await create_timer(0.07).timeout
	check(deformation(board.jelly_at(1, 0)) > 0.004, "Landing weight ripples into the bottom jelly")
	check(board.jelly_at(1, 2).count == 2 and board.jelly_at(1, 1).count == 1, "Contact reactions do not merge different colors or change slot counts")
	await create_timer(0.8).timeout
	for slot: int in [1, 2]:
		check(absf(body_bottom(board.jelly_at(1, slot)) - body_top(board.jelly_at(1, slot - 1)) - 15) < 0.1, "A landed stack settles with correct contact")

	board.refresh(state([0, 1, 2, 3]))
	board.set_selection(0)
	await create_timer(0.8).timeout
	board.set_selection(0)
	check(deformation(board.jelly_at(0, 2)) < 0.002, "Repeated selection does not restart support reactions")
	board.set_selection(-1)
	board.refresh(state([4]))
	await create_timer(0.2).timeout
	check(deformation(board.jelly_at(0, 0)) < 0.001, "Refreshing the board cancels old delayed stack reactions")
	board.free()
	await process_frame
	print("Stack interaction checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
