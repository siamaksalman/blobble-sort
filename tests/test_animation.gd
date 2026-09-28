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

func idle_time(jelly: BlobbleJelly) -> float:
	var value: Variant = jelly.material.get_shader_parameter("clock")
	return 0.0 if value == null else float(value)

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
	# The little comic jiggle stays seated, including on a tall merged jelly.
	for amount: int in [1, 4]:
		var playful: BlobbleJelly = preload("res://scripts/jelly.gd").new()
		playful.configure(0, amount)
		playful.pocket_index = 0
		playful.origin = Vector2(50, 50)
		var widest: float = 1.0
		var narrowest: float = 1.0
		var seated: bool = true
		for frame: int in 41:
			playful.set_idle_phase(16.5 + frame * 0.05, 0.0)
			playful._process(0.0)
			widest = maxf(widest, playful.scale.x)
			narrowest = minf(narrowest, playful.scale.x)
			var foot: Vector2 = playful.get_transform() * playful.pivot_offset
			seated = seated and foot.is_equal_approx(playful.origin + playful.pivot_offset)
		check(widest > 1.003 and narrowest < 0.997, "A happy jelly does a tiny squash-and-stretch jiggle")
		check(widest < 1.04 and narrowest > 0.96 and seated, "The comic jiggle is small and stays seated")
		playful.set_idle_phase(20.2, 0.0)
		playful._process(0.0)
		check(playful.scale.is_equal_approx(Vector2.ONE), "The happy jiggle ends in a quiet rest")
		var moving_frames: int = 0
		for frame: int in 1600:
			playful.set_idle_phase(frame * 0.05, 0.0)
			playful._process(0.0)
			if absf(playful.scale.x - 1.0) > 0.001:
				moving_frames += 1
		check(moving_frames > 0 and moving_frames < 48, "Playful jiggles occupy less than three percent of idle time")
		playful.free()
	var board: BlobbleBoard = Board.new()
	root.add_child(board)
	await process_frame

	board.refresh(layout([1, 2], [2]))
	await create_timer(0.15).timeout
	var idle_clock: float = idle_time(board.jelly_at(0, 0))
	var personality: float = float(board.jelly_at(0, 0).material.get_shader_parameter("seed"))
	board.refresh(layout([1, 2], [2]))
	check(absf(idle_time(board.jelly_at(0, 0)) - idle_clock) < 0.05,
		"Refreshing a board preserves expression progress")
	check(is_equal_approx(float(board.jelly_at(0, 0).material.get_shader_parameter("seed")), personality),
		"Refreshing a board preserves an untouched jelly's facial personality")
	var resting_top: float = jellies_in(board, 0)[1].position.y
	var flight: Dictionary = await follow_pour(board, 0, 1, 1, layout([1], [2, 2]))
	check(idle_time(board.jelly_at(0, 0)) > idle_clock,
		"A pour does not restart the expressions of resting jellies")
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

	# Reference-derived geometry also supports pours between moved or mirrored pockets.
	var geometry: Dictionary = preload("res://scripts/board_layout.gd").new().generate(3)
	board.apply_layout(geometry)
	var before: Array = layout([2], [])
	before[11] = [2]
	var after: Array = layout([], [])
	after[11] = [2, 2]
	board.refresh(before)
	await follow_pour(board, 0, 11, 1, after)
	var result: BlobbleJelly = board.jelly_at(11, 1)
	check(result.count == 2, "A pour across generated wells still merges")
	await create_timer(0.9).timeout
	check(is_equal_approx(result.scale.x, geometry["wells"][11]["scale"]), "A traveling jelly adopts its destination pocket scale")
	var rendered_center: Vector2 = result.get_transform() * (result.size * 0.5)
	check(rendered_center.is_equal_approx(board.center_at(11, 0.5)), "Scaled merged jelly lands inside the destination pocket")

	print("Animation checks: %d passed, %d failed" % [checks - failures, failures])
	board.queue_free()
	await process_frame
	quit(1 if failures else 0)
