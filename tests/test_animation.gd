extends SceneTree
## Headless checks that pours travel, land, and merge with visible jelly motion.

const Board = preload("res://scripts/board.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	# A script error stops the coroutine; fail instead of hanging.
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("Animation checks timed out")
		quit(1))
	call_deferred("run")

func layout(first: Array, second: Array) -> Array:
	var state: Array = [first, second]
	for i: int in 10:
		state.append([])
	return state

func jellies_in(board: BlobbleBoard, pocket: int) -> Array:
	return board.jellies.filter(func(jelly: BlobbleJelly) -> bool: return jelly.pocket_index == pocket)

func deformation(jelly: BlobbleJelly) -> float:
	return absf(jelly.scale.x - jelly.scale.y)

func pinch(jelly: BlobbleJelly) -> float:
	return float(jelly.material.get_shader_parameter("pinch"))

## Starts a pour and follows the traveling jelly until it lands.
func follow_pour(board: BlobbleBoard, source: int, target: int, amount: int, after: Array) -> Dictionary:
	var start: int = Time.get_ticks_msec()
	var result: Dictionary = {"highest": INF, "stretch": 0.0, "recoil": 0.0, "seconds": 0.0}
	board.play_pour(source, target, amount, after)
	while is_instance_valid(board.flying):
		result.highest = minf(result.highest, board.flying.position.y)
		result.stretch = maxf(result.stretch, deformation(board.flying))
		for jelly: BlobbleJelly in jellies_in(board, source):
			result.recoil = maxf(result.recoil, deformation(jelly))
		await process_frame
		if Time.get_ticks_msec() - start > 2000:
			break
	result.seconds = (Time.get_ticks_msec() - start) / 1000.0
	return result

func run() -> void:
	var board: BlobbleBoard = Board.new()
	root.add_child(board)
	await process_frame

	board.refresh(layout([1, 2], [2]))
	var resting_top: float = jellies_in(board, 0)[1].position.y
	var flight: Dictionary = await follow_pour(board, 0, 1, 1, layout([1], [2, 2]))
	check(flight.seconds < 0.6, "A pour lands quickly enough to keep play snappy")
	check(flight.highest < resting_top - 60.0, "The traveling jelly arcs up out of its pocket")
	check(flight.stretch > 0.08, "The traveling jelly stretches and squashes in flight")
	var merged: Array = jellies_in(board, 1)
	check(merged.size() == 1 and merged[0].count == 2, "Equal colors land as one merged jelly")
	if merged.size() == 1:
		check(pinch(merged[0]) > 0.4, "A fresh merge shows a gooey seam where the jellies joined")
		check(deformation(merged[0]) > 0.04, "A fresh merge wobbles on impact")
	check(board.splash_count() > 0, "Merging splashes little droplets")
	check(flight.recoil > 0.02, "The jelly left behind recoils as the group lifts off")
	await create_timer(0.9).timeout
	merged = jellies_in(board, 1)
	if merged.size() == 1:
		check(pinch(merged[0]) < 0.02, "The merge seam relaxes into one smooth body")
		check(deformation(merged[0]) < 0.01, "The merged jelly settles back to its rest shape")
	check(board.splash_count() == 0, "Droplets fade away")

	board.refresh(layout([3], []))
	await follow_pour(board, 0, 1, 1, layout([], [3]))
	var landed: Array = jellies_in(board, 1)
	check(landed.size() == 1 and pinch(landed[0]) == 0.0, "Landing in an empty pocket has no merge seam")
	if landed.size() == 1:
		check(deformation(landed[0]) > 0.04, "Landing in an empty pocket squashes on impact")

	board.refresh(layout([4], []))
	var lifted: BlobbleJelly = jellies_in(board, 0)[0]
	var rest: float = lifted.position.y
	board.set_selection(0)
	await process_frame
	check(lifted.position.y > rest - 12.0, "Selection lift eases in instead of snapping")
	await create_timer(0.4).timeout
	check(lifted.position.y < rest - 8.0, "A selected jelly rises out of its pocket")
	board.set_selection(-1)
	await process_frame
	check(lifted.position.y < rest - 3.0, "Deselection eases back down")
	await create_timer(0.4).timeout
	check(absf(lifted.position.y - rest) < 1.0, "A deselected jelly returns to rest")

	print("Animation checks: %d passed, %d failed" % [checks - failures, failures])
	board.queue_free()
	await process_frame
	quit(1 if failures else 0)
