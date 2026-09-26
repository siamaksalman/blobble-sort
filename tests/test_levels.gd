extends SceneTree
## Headless check: every generated level is valid and its solution really solves it.
## Run: godot --headless --path . -s res://tests/test_levels.gd -- [first] [last]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else 1
	var last := int(args[1]) if args.size() > 1 else 60
	var failures := 0
	var slowest := 0
	for level in range(first, last + 1):
		var t0 := Time.get_ticks_msec()
		var data := LevelGenerator.generate(level)
		var ms := Time.get_ticks_msec() - t0
		slowest = maxi(slowest, ms)
		var err := _verify(data)
		if err != "":
			failures += 1
		print("level %3d  colors %2d  bottles %2d  nodes %6d  moves %3d  %5d ms  %s" % [
			level, data.colors, data.state.size(), data.nodes, data.solution.size(), ms,
			"OK" if err == "" else "FAIL: " + err])
	print("\n%d failures, slowest generation %d ms" % [failures, slowest])
	quit(1 if failures > 0 else 0)


func _verify(data: Dictionary) -> String:
	var state: Array = data.state
	var cap: int = data.capacity
	var counts := {}
	for b: String in state:
		if b.length() > cap:
			return "overfull bottle"
		for i in b.length():
			counts[b[i]] = counts.get(b[i], 0) + 1
	for c in counts:
		if counts[c] != cap:
			return "color %s has %d units" % [c, counts[c]]
	if data.solution.is_empty():
		return "no solution"
	for m: Array in data.solution:
		var amt := WaterSolver.pour_amount(state, m[0], m[1], cap)
		if amt != m[2]:
			return "illegal move %s" % [m]
		state = WaterSolver.apply_move(state, m[0], m[1], amt)
	if not WaterSolver.is_solved(state, cap):
		return "solution does not solve"
	return ""
