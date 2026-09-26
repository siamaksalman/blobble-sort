extends SceneTree
## Headless check of star rating and time formatting.
## Run: godot --headless --path . -s res://tests/test_scoring.gd

var failures := 0


func _init() -> void:
	# stars(moves, target, helpers_used)
	_eq(Scoring.stars(10, 10, false), 3, "on target")
	_eq(Scoring.stars(8, 10, false), 3, "under target")
	_eq(Scoring.stars(11, 10, false), 2, "just over target")
	_eq(Scoring.stars(15, 10, false), 2, "exactly 1.5x target")
	_eq(Scoring.stars(16, 10, false), 1, "over 1.5x target")
	_eq(Scoring.stars(10, 10, true), 2, "helpers cap at 2")
	_eq(Scoring.stars(40, 10, true), 1, "helpers don't raise a 1")
	_eq(Scoring.stars(0, 0, false), 3, "zero target")
	_eq(Scoring.stars(2, 0, false), 1, "zero target, extra moves")

	_eq(Scoring.format_time(0.0), "0:00", "zero time")
	_eq(Scoring.format_time(42.9), "0:42", "truncates")
	_eq(Scoring.format_time(125.0), "2:05", "minutes")
	_eq(Scoring.format_time(3725.0), "62:05", "over an hour stays m:ss")

	_eq(Scoring.is_better(3, 50.0, {}), true, "no previous best")
	_eq(Scoring.is_better(2, 50.0, {stars = 3, time = 60.0}), true, "faster time")
	_eq(Scoring.is_better(3, 70.0, {stars = 2, time = 60.0}), true, "more stars")
	_eq(Scoring.is_better(2, 70.0, {stars = 3, time = 60.0}), false, "worse on both")

	print("PASS" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)


func _eq(got: Variant, want: Variant, what: String) -> void:
	if got != want:
		failures += 1
		print("FAIL %s: got %s, want %s" % [what, got, want])
